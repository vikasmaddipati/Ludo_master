const GameRoom = require('../models/GameRoom');
const User = require('../models/User');
const RewardHistory = require('../models/RewardHistory');

// Ludo Path Math Constants & Path Calculations
// Standard Ludo has 52 cells on the main track, and a home-stretch path of 6 cells.
// Standard safe spots on standard board are at main track index 0 (starting point), 8, 13, 21, 26, 34, 39, 47.
const SAFE_INDEXES = [0, 8, 13, 21, 26, 34, 39, 47];

// Colors and their starting indexes on the main 52-cell track
const START_INDEX = {
  red: 0,
  green: 13,
  yellow: 26,
  blue: 39
};

const COLOR_ORDER = ['red', 'green', 'yellow', 'blue'];

const initSocket = (io) => {
  io.on('connection', (socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // Join Game Room
    socket.on('join_room', async ({ roomCode, userId, name }) => {
      try {
        let room = await GameRoom.findOne({ roomCode });
        if (!room) {
          socket.emit('error_message', { message: 'Room not found.' });
          return;
        }

        socket.join(roomCode);
        socket.userId = userId;
        socket.roomCode = roomCode;

        // Check if player is already in room
        const playerIndex = room.players.findIndex(p => p.userId === userId);

        if (playerIndex !== -1) {
          room.players[playerIndex].isConnected = true;
        } else if (room.status === 'waiting' && room.players.length < 4) {
          // Assign color
          const colorsUsed = room.players.map(p => p.color);
          const availableColor = COLOR_ORDER.find(c => !colorsUsed.includes(c));
          
          room.players.push({
            userId,
            name,
            color: availableColor,
            isReady: room.creator === userId, // Host is ready by default
            isConnected: true
          });
        } else if (room.status !== 'waiting') {
          // Reconnecting to active game
          const activePlayer = room.players.find(p => p.userId === userId);
          if (activePlayer) {
            activePlayer.isConnected = true;
            console.log(`User ${name} reconnected to active room ${roomCode}`);
          } else {
            socket.emit('error_message', { message: 'Game has already started, cannot join.' });
            return;
          }
        }

        await room.save();
        io.to(roomCode).emit('room_updated', room);
      } catch (err) {
        console.error('Join room error:', err);
      }
    });

    // Add Bot Player Option
    socket.on('add_bot', async ({ roomCode }) => {
      try {
        let room = await GameRoom.findOne({ roomCode });
        if (!room || room.status !== 'waiting' || room.players.length >= 4) return;

        const colorsUsed = room.players.map(p => p.color);
        const availableColor = COLOR_ORDER.find(c => !colorsUsed.includes(c));
        const botId = `bot_${Math.floor(1000 + Math.random() * 9000)}`;

        room.players.push({
          userId: botId,
          name: `Bot ${availableColor.toUpperCase()}`,
          color: availableColor,
          isBot: true,
          isReady: true,
          isConnected: true
        });

        await room.save();
        io.to(roomCode).emit('room_updated', room);
      } catch (err) {
        console.error('Add bot error:', err);
      }
    });

    // Toggle Ready Status
    socket.on('player_ready', async ({ roomCode, userId }) => {
      try {
        let room = await GameRoom.findOne({ roomCode });
        if (!room) return;

        const player = room.players.find(p => p.userId === userId);
        if (player) {
          player.isReady = !player.isReady;
          await room.save();
          io.to(roomCode).emit('room_updated', room);
        }
      } catch (err) {
        console.error(err);
      }
    });

    // Start Multiplayer Ludo Match
    socket.on('start_game', async ({ roomCode }) => {
      try {
        let room = await GameRoom.findOne({ roomCode });
        if (!room) return;

        // Ensure host is starting
        room.status = 'playing';
        room.turn = room.players[0].color;
        room.hasRolled = false;

        // Initialize 4 tokens for each active player
        const tokens = [];
        room.players.forEach(p => {
          for (let i = 0; i < 4; i++) {
            tokens.push({
              color: p.color,
              tokenId: i,
              position: -1 // -1 is Home Base
            });
          }
        });

        room.tokens = tokens;
        await room.save();

        io.to(roomCode).emit('game_started', room);
        
        // If first player is a Bot, trigger bot roll
        if (checkIfBotTurn(room)) {
          triggerBotAction(io, roomCode);
        }
      } catch (err) {
        console.error(err);
      }
    });

    // Roll Dice
    socket.on('roll_dice', async ({ roomCode }) => {
      try {
        let room = await GameRoom.findOne({ roomCode });
        if (!room || room.status !== 'playing' || room.hasRolled) return;

        const diceValue = Math.floor(Math.random() * 6) + 1;
        room.diceValue = diceValue;
        room.hasRolled = true;

        // Calculate potential valid moves
        const validTokensToMove = getValidMoves(room, room.turn, diceValue);

        await room.save();
        io.to(roomCode).emit('dice_rolled', { room, validTokensToMove });

        // If no moves are possible, shift turn immediately
        if (validTokensToMove.length === 0) {
          setTimeout(async () => {
            await shiftTurn(io, roomCode);
          }, 1500);
        }
      } catch (err) {
        console.error(err);
      }
    });

    // Move Token
    socket.on('move_token', async ({ roomCode, tokenId }) => {
      try {
        let room = await GameRoom.findOne({ roomCode });
        if (!room || room.status !== 'playing' || !room.hasRolled) return;

        const currentTurnColor = room.turn;
        const diceValue = room.diceValue;

        const token = room.tokens.find(t => t.color === currentTurnColor && t.tokenId === tokenId);
        if (!token) return;

        // Verify if it's a valid move
        const validMoves = getValidMoves(room, currentTurnColor, diceValue);
        if (!validMoves.includes(tokenId)) {
          socket.emit('error_message', { message: 'Invalid token choice.' });
          return;
        }

        // Apply movement
        if (token.position === -1) {
          // Open token with a 6
          token.position = 0;
        } else {
          token.position += diceValue;
        }

        // Check for Goal completion
        if (token.position === 57) {
          token.position = 99; // Reached goal!
        }

        // Check if landing captures an opponent token
        let captured = false;
        if (token.position < 51) {
          const landedGlobalIndex = getGlobalIndex(currentTurnColor, token.position);
          
          if (!SAFE_INDEXES.includes(landedGlobalIndex)) {
            // Check other colors
            for (let opponentToken of room.tokens) {
              if (opponentToken.color !== currentTurnColor && opponentToken.position >= 0 && opponentToken.position < 51) {
                const opponentGlobalIndex = getGlobalIndex(opponentToken.color, opponentToken.position);
                if (landedGlobalIndex === opponentGlobalIndex) {
                  // Capture! Send opponent token back to base
                  opponentToken.position = -1;
                  captured = true;
                }
              }
            }
          }
        }

        // Check if current player has won (all 4 tokens at 99)
        const allTokensHome = room.tokens
          .filter(t => t.color === currentTurnColor)
          .every(t => t.position === 99);

        if (allTokensHome) {
          room.status = 'finished';
          room.winnerId = room.players.find(p => p.color === currentTurnColor).userId;

          // Update database details, add rewards
          const winningUser = await User.findById(room.winnerId);
          if (winningUser) {
            winningUser.wins += 1;
            winningUser.coins += 200; // Reward coins
            await winningUser.save();

            const winHistory = new RewardHistory({
              userId: room.winnerId,
              rewardType: 'match_win',
              amount: 200
            });
            await winHistory.save();
          }

          // Mark losses for other human players
          for (let p of room.players) {
            if (p.userId !== room.winnerId && !p.isBot) {
              const loser = await User.findById(p.userId);
              if (loser) {
                loser.losses += 1;
                await loser.save();
              }
            }
          }
        }

        await room.save();
        io.to(roomCode).emit('token_moved', room);

        if (room.status === 'finished') {
          io.to(roomCode).emit('game_over', { winnerId: room.winnerId });
          return;
        }

        // Shift turn. If user gets a 6 or captures opponent, they get another turn
        if ((diceValue === 6 || captured) && !allTokensHome) {
          room.hasRolled = false;
          await room.save();
          io.to(roomCode).emit('room_updated', room);
          
          if (checkIfBotTurn(room)) {
            triggerBotAction(io, roomCode);
          }
        } else {
          await shiftTurn(io, roomCode);
        }
      } catch (err) {
        console.error(err);
      }
    });

    // Real-Time Chat & Emojis inside room
    socket.on('send_chat_message', ({ roomCode, senderName, message, isEmoji }) => {
      io.to(roomCode).emit('chat_message_received', {
        senderName,
        message,
        isEmoji: isEmoji || false,
        timestamp: new Date()
      });
    });

    // Handle Network Disconnections
    socket.on('disconnect', async () => {
      if (socket.roomCode && socket.userId) {
        console.log(`Socket disconnected gracefully: ${socket.userId}`);
        try {
          const room = await GameRoom.findOne({ roomCode: socket.roomCode });
          if (room) {
            const player = room.players.find(p => p.userId === socket.userId);
            if (player) {
              player.isConnected = false;
              await room.save();
              io.to(socket.roomCode).emit('room_updated', room);

              // Auto turn shift if active player gets disconnected
              if (room.status === 'playing' && room.players.find(p => p.color === room.turn)?.userId === socket.userId) {
                setTimeout(async () => {
                  const checkRoom = await GameRoom.findOne({ roomCode: socket.roomCode });
                  if (checkRoom && checkRoom.turn === room.turn && checkRoom.status === 'playing') {
                    console.log(`Auto shifting turn in ${socket.roomCode} due to disconnect.`);
                    await shiftTurn(io, socket.roomCode);
                  }
                }, 10000);
              }
            }
          }
        } catch (err) {
          console.error(err);
        }
      }
    });
  });
};

// --- GAME LOGIC HELPERS ---

const checkIfBotTurn = (room) => {
  const activePlayer = room.players.find(p => p.color === room.turn);
  return activePlayer && activePlayer.isBot;
};

// Automate AI Bot moves in turn
const triggerBotAction = (io, roomCode) => {
  setTimeout(async () => {
    try {
      let room = await GameRoom.findOne({ roomCode });
      if (!room || room.status !== 'playing' || !checkIfBotTurn(room)) return;

      // Roll
      const diceValue = Math.floor(Math.random() * 6) + 1;
      room.diceValue = diceValue;
      room.hasRolled = true;

      const validTokens = getValidMoves(room, room.turn, diceValue);
      await room.save();
      io.to(roomCode).emit('dice_rolled', { room, validTokensToMove: validTokens });

      if (validTokens.length === 0) {
        setTimeout(async () => {
          await shiftTurn(io, roomCode);
        }, 1500);
        return;
      }

      // Bot selects a random or best token
      const tokenId = validTokens[Math.floor(Math.random() * validTokens.length)];

      setTimeout(async () => {
        // Trigger bot token movement logic
        let updatedRoom = await GameRoom.findOne({ roomCode });
        const token = updatedRoom.tokens.find(t => t.color === updatedRoom.turn && t.tokenId === tokenId);

        if (token.position === -1) {
          token.position = 0;
        } else {
          token.position += diceValue;
        }

        if (token.position === 57) token.position = 99;

        // Check Capture
        let captured = false;
        if (token.position < 51) {
          const landedIndex = getGlobalIndex(updatedRoom.turn, token.position);
          if (!SAFE_INDEXES.includes(landedIndex)) {
            for (let opponent of updatedRoom.tokens) {
              if (opponent.color !== updatedRoom.turn && opponent.position >= 0 && opponent.position < 51) {
                const oppIndex = getGlobalIndex(opponent.color, opponent.position);
                if (landedIndex === oppIndex) {
                  opponent.position = -1;
                  captured = true;
                }
              }
            }
          }
        }

        // Win check
        const won = updatedRoom.tokens.filter(t => t.color === updatedRoom.turn).every(t => t.position === 99);
        if (won) {
          updatedRoom.status = 'finished';
          updatedRoom.winnerId = updatedRoom.players.find(p => p.color === updatedRoom.turn).userId;
        }

        await updatedRoom.save();
        io.to(roomCode).emit('token_moved', updatedRoom);

        if (updatedRoom.status === 'finished') {
          io.to(roomCode).emit('game_over', { winnerId: updatedRoom.winnerId });
          return;
        }

        if ((diceValue === 6 || captured) && !won) {
          updatedRoom.hasRolled = false;
          await updatedRoom.save();
          io.to(roomCode).emit('room_updated', updatedRoom);
          triggerBotAction(io, roomCode);
        } else {
          await shiftTurn(io, roomCode);
        }
      }, 1500);

    } catch (err) {
      console.error('Bot action error:', err);
    }
  }, 2000);
};

const getValidMoves = (room, color, diceValue) => {
  const playerTokens = room.tokens.filter(t => t.color === color);
  const valid = [];

  playerTokens.forEach(t => {
    // Reached target
    if (t.position === 99) return;

    // Inside home base, needs a 6 to open
    if (t.position === -1) {
      if (diceValue === 6) valid.push(t.tokenId);
    } else {
      // Must not overshoot the home stretch goal (57 path cells)
      if (t.position + diceValue <= 57) {
        valid.push(t.tokenId);
      }
    }
  });

  return valid;
};

const shiftTurn = async (io, roomCode) => {
  try {
    let room = await GameRoom.findOne({ roomCode });
    if (!room || room.status !== 'playing') return;

    const colorsInGame = room.players.map(p => p.color);
    let currentIdx = COLOR_ORDER.indexOf(room.turn);
    let nextColor = null;

    // Loop through colors to find the next active player color
    for (let i = 1; i <= 4; i++) {
      const nextIdx = (currentIdx + i) % 4;
      const col = COLOR_ORDER[nextIdx];
      if (colorsInGame.includes(col)) {
        nextColor = col;
        break;
      }
    }

    room.turn = nextColor;
    room.hasRolled = false;
    await room.save();

    io.to(roomCode).emit('room_updated', room);

    // If bot turn, trigger
    if (checkIfBotTurn(room)) {
      triggerBotAction(io, roomCode);
    }
  } catch (err) {
    console.error('Shift turn error:', err);
  }
};

// Maps local track position (0-50) into unified global main board track position (0-51)
const getGlobalIndex = (color, localPosition) => {
  if (localPosition < 0 || localPosition >= 51) return -1;
  const start = START_INDEX[color];
  return (start + localPosition) % 52;
};

module.exports = {
  initSocket
};
