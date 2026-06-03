const { io } = require('socket.io-client');

const socket = io('http://localhost:3000', {
  transports: ['websocket']
});

socket.on('connect', () => {
  console.log('Socket connected to backend!');
  socket.emit('register_user', 'user_test_123');

  // Let's create a room code via REST API first
  const http = require('http');
  const data = JSON.stringify({ userId: 'user_test_123', name: 'Vikas Test' });

  const req = http.request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/game/create',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': data.length
    }
  }, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
      const resp = JSON.parse(body);
      console.log('Room created:', resp);
      const roomCode = resp.roomCode;

      // Join room
      socket.emit('join_room', { roomCode, userId: 'user_test_123', name: 'Vikas Test' });

      socket.on('room_updated', (room) => {
        console.log('Room updated:', room.status, 'players:', room.players.length);
        if (room.status === 'waiting' && room.players.length === 1) {
          // Add Bot
          console.log('Adding bot...');
          socket.emit('add_bot', { roomCode });
        } else if (room.status === 'waiting' && room.players.length === 2) {
          // Start Game
          console.log('Starting game...');
          socket.emit('start_game', { roomCode });
        }
      });

      socket.on('game_started', (room) => {
        console.log('Game started! Status:', room.status, 'turn:', room.turn);
        // Roll Dice
        console.log('Rolling dice...');
        socket.emit('roll_dice', { roomCode });
      });

      socket.on('dice_rolled', ({ room, validTokensToMove }) => {
        console.log('Dice rolled! Value:', room.diceValue, 'Valid tokens:', validTokensToMove);
      });

      socket.on('room_updated', (room) => {
        console.log('Room updated: Status =', room.status, 'Turn =', room.turn, 'hasRolled =', room.hasRolled);
        if (room.status === 'playing' && room.turn !== 'red') {
          console.log('Success! Turn successfully progressed to:', room.turn);
          socket.disconnect();
          process.exit(0);
        }
      });

      socket.on('error_message', (err) => {
        console.error('Socket error received:', err);
      });
    });
  });

  req.on('error', e => console.error('HTTP Request error:', e));
  req.write(data);
  req.end();
});

socket.on('connect_error', (err) => {
  console.error('Socket connect error:', err);
});
