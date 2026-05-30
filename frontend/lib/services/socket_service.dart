import 'dart:math';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/game_room_model.dart';
import '../models/chat_message.dart';

class SocketService {
  late IO.Socket socket;
  static const String serverUrl = 'https://ludo-t3um.onrender.com';

  bool isConnected = false;
  bool isMockMode = false;

  // Saved callbacks for mock simulation
  Function(GameRoomModel)? _onRoomUpdated;
  Function(GameRoomModel)? _onGameStarted;
  Function(GameRoomModel, List<int>)? _onDiceRolled;
  Function(GameRoomModel)? _onTokenMoved;
  Function(String)? _onGameOver;
  Function(ChatMessage)? _onChatMessageReceived;
  Function(String)? _onErrorReceived;

  GameRoomModel? mockRoom;

  void connect(String userId, Function(String) onError) {
    if (isMockMode) {
      isConnected = true;
      return;
    }

    socket = IO.io(serverUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    socket.connect();

    socket.onConnect((_) {
      isConnected = true;
      print('Socket.io connected successfully.');
    });

    socket.onDisconnect((_) {
      isConnected = false;
      print('Socket.io disconnected.');
    });

    socket.onConnectError((err) {
      print('Socket connection error: $err');
      onError('Unable to connect to backend server. Make sure the Node app is running.');
    });
  }

  // Action emitters
  void joinRoom(String roomCode, String userId, String name) {
    if (isMockMode) {
      // Build a local sandbox room
      mockRoom = GameRoomModel(
        id: 'room_$roomCode',
        roomCode: roomCode,
        creator: userId,
        status: 'waiting',
        turn: 'red',
        diceValue: 1,
        hasRolled: false,
        players: [
          PlayerModel(userId: userId, name: name, color: 'red', isReady: true, isConnected: true, isBot: false)
        ],
        tokens: []
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_onRoomUpdated != null) _onRoomUpdated!(mockRoom!);
      });
      return;
    }

    socket.emit('join_room', {
      'roomCode': roomCode,
      'userId': userId,
      'name': name
    });
  }

  void addBot(String roomCode) {
    if (isMockMode) {
      if (mockRoom == null || mockRoom!.players.length >= 4) return;
      final colors = ['red', 'green', 'yellow', 'blue'];
      final usedColors = mockRoom!.players.map((p) => p.color).toList();
      final nextColor = colors.firstWhere((c) => !usedColors.contains(c));
      
      mockRoom!.players.add(PlayerModel(
        userId: 'bot_$nextColor',
        name: 'Bot ${nextColor.toUpperCase()}',
        color: nextColor,
        isReady: true,
        isConnected: true,
        isBot: true
      ));
      
      if (_onRoomUpdated != null) _onRoomUpdated!(mockRoom!);
      return;
    }

    socket.emit('add_bot', {
      'roomCode': roomCode
    });
  }

  void toggleReady(String roomCode, String userId) {
    if (isMockMode) {
      final p = mockRoom?.players.firstWhere((pl) => pl.userId == userId);
      if (p != null) {
        p.isReady = !p.isReady;
        if (_onRoomUpdated != null) _onRoomUpdated!(mockRoom!);
      }
      return;
    }

    socket.emit('player_ready', {
      'roomCode': roomCode,
      'userId': userId
    });
  }

  void startGame(String roomCode) {
    if (isMockMode) {
      if (mockRoom == null) return;
      mockRoom!.status = 'playing';
      mockRoom!.turn = 'red';
      mockRoom!.hasRolled = false;

      // Initialize tokens
      final List<LudoTokenModel> tks = [];
      for (var player in mockRoom!.players) {
        for (int i = 0; i < 4; i++) {
          tks.add(LudoTokenModel(color: player.color, tokenId: i, position: -1));
        }
      }
      mockRoom!.tokens = tks;

      if (_onGameStarted != null) _onGameStarted!(mockRoom!);
      return;
    }

    socket.emit('start_game', {
      'roomCode': roomCode
    });
  }

  void rollDice(String roomCode) {
    if (isMockMode) {
      if (mockRoom == null || mockRoom!.status != 'playing' || mockRoom!.hasRolled) return;
      final dice = Random().nextInt(6) + 1;
      mockRoom!.diceValue = dice;
      mockRoom!.hasRolled = true;

      final valid = _getValidMoves(mockRoom!, mockRoom!.turn, dice);
      if (_onDiceRolled != null) _onDiceRolled!(mockRoom!, valid);

      if (valid.isEmpty) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          _shiftTurnLocal();
        });
      }
      return;
    }

    socket.emit('roll_dice', {
      'roomCode': roomCode
    });
  }

  void moveToken(String roomCode, int tokenId) {
    if (isMockMode) {
      if (mockRoom == null || mockRoom!.status != 'playing' || !mockRoom!.hasRolled) return;
      final turnColor = mockRoom!.turn;
      final dice = mockRoom!.diceValue;

      final tk = mockRoom!.tokens.firstWhere((t) => t.color == turnColor && t.tokenId == tokenId);
      
      if (tk.position == -1) {
        tk.position = 0;
      } else {
        tk.position += dice;
      }

      if (tk.position == 57) {
        tk.position = 99; // Finished
      }

      // Check capture
      bool captured = false;
      if (tk.position < 51 && tk.position >= 0) {
        final globalIndex = _getGlobalIndex(turnColor, tk.position);
        final safeSpots = [0, 8, 13, 21, 26, 34, 39, 47];
        if (!safeSpots.contains(globalIndex)) {
          for (var opp in mockRoom!.tokens) {
            if (opp.color != turnColor && opp.position >= 0 && opp.position < 51) {
              final oppGlobal = _getGlobalIndex(opp.color, opp.position);
              if (globalIndex == oppGlobal) {
                opp.position = -1;
                captured = true;
              }
            }
          }
        }
      }

      // Check winner
      final allHome = mockRoom!.tokens.where((t) => t.color == turnColor).every((t) => t.position == 99);
      if (allHome) {
        mockRoom!.status = 'finished';
        mockRoom!.winnerId = mockRoom!.players.firstWhere((p) => p.color == turnColor).userId;
      }

      if (_onTokenMoved != null) _onTokenMoved!(mockRoom!);

      if (mockRoom!.status == 'finished') {
        if (_onGameOver != null) _onGameOver!(mockRoom!.winnerId!);
        return;
      }

      if ((dice == 6 || captured) && !allHome) {
        mockRoom!.hasRolled = false;
        if (_onRoomUpdated != null) _onRoomUpdated!(mockRoom!);
        _checkAndTriggerBot();
      } else {
        _shiftTurnLocal();
      }
      return;
    }

    socket.emit('move_token', {
      'roomCode': roomCode,
      'tokenId': tokenId
    });
  }

  void sendChatMessage(String roomCode, String senderName, String message, bool isEmoji) {
    if (isMockMode) {
      final msg = ChatMessage(
        senderName: senderName,
        message: message,
        isEmoji: isEmoji,
        timestamp: DateTime.now()
      );
      if (_onChatMessageReceived != null) _onChatMessageReceived!(msg);
      return;
    }

    socket.emit('send_chat_message', {
      'roomCode': roomCode,
      'senderName': senderName,
      'message': message,
      'isEmoji': isEmoji
    });
  }

  // --- MOCK SIMULATOR HELPERS ---

  List<int> _getValidMoves(GameRoomModel room, String color, int dice) {
    final tokens = room.tokens.where((t) => t.color == color).toList();
    final valid = <int>[];
    for (var t in tokens) {
      if (t.position == 99) continue;
      if (t.position == -1) {
        if (dice == 6) valid.add(t.tokenId);
      } else {
        if (t.position + dice <= 57) {
          valid.add(t.tokenId);
        }
      }
    }
    return valid;
  }

  int _getGlobalIndex(String color, int localPos) {
    final startIndex = {'red': 0, 'green': 13, 'yellow': 26, 'blue': 39};
    final start = startIndex[color] ?? 0;
    return (start + localPos) % 52;
  }

  void _shiftTurnLocal() {
    if (mockRoom == null) return;
    final order = ['red', 'green', 'yellow', 'blue'];
    final activeColors = mockRoom!.players.map((p) => p.color).toList();
    int currIdx = order.indexOf(mockRoom!.turn);
    
    for (int i = 1; i <= 4; i++) {
      final nextColor = order[(currIdx + i) % 4];
      if (activeColors.contains(nextColor)) {
        mockRoom!.turn = nextColor;
        break;
      }
    }

    mockRoom!.hasRolled = false;
    if (_onRoomUpdated != null) _onRoomUpdated!(mockRoom!);
    _checkAndTriggerBot();
  }

  void _checkAndTriggerBot() {
    if (mockRoom == null || mockRoom!.status != 'playing') return;
    final activePlayer = mockRoom!.players.firstWhere((p) => p.color == mockRoom!.turn);
    if (activePlayer.isBot) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        // Roll dice for bot
        if (mockRoom == null || mockRoom!.turn != activePlayer.color) return;
        final dice = Random().nextInt(6) + 1;
        mockRoom!.diceValue = dice;
        mockRoom!.hasRolled = true;

        final valid = _getValidMoves(mockRoom!, mockRoom!.turn, dice);
        if (_onDiceRolled != null) _onDiceRolled!(mockRoom!, valid);

        if (valid.isEmpty) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            _shiftTurnLocal();
          });
        } else {
          // Select first token and move it
          Future.delayed(const Duration(milliseconds: 1500), () {
            final selId = valid[Random().nextInt(valid.length)];
            moveToken(mockRoom!.roomCode, selId);
          });
        }
      });
    }
  }

  // Register real-time listeners
  void onRoomUpdated(Function(GameRoomModel) onUpdate) {
    _onRoomUpdated = onUpdate;
    if (!isMockMode) {
      socket.on('room_updated', (data) {
        onUpdate(GameRoomModel.fromJson(data));
      });
    }
  }

  void onGameStarted(Function(GameRoomModel) onStart) {
    _onGameStarted = onStart;
    if (!isMockMode) {
      socket.on('game_started', (data) {
        onStart(GameRoomModel.fromJson(data));
      });
    }
  }

  void onDiceRolled(Function(GameRoomModel, List<int>) onRoll) {
    _onDiceRolled = onRoll;
    if (!isMockMode) {
      socket.on('dice_rolled', (data) {
        final room = GameRoomModel.fromJson(data['room']);
        final validTokens = List<int>.from(data['validTokensToMove'] ?? []);
        onRoll(room, validTokens);
      });
    }
  }

  void onTokenMoved(Function(GameRoomModel) onMove) {
    _onTokenMoved = onMove;
    if (!isMockMode) {
      socket.on('token_moved', (data) {
        onMove(GameRoomModel.fromJson(data));
      });
    }
  }

  void onGameOver(Function(String) onWin) {
    _onGameOver = onWin;
    if (!isMockMode) {
      socket.on('game_over', (data) {
        onWin(data['winnerId'] ?? '');
      });
    }
  }

  void onChatMessageReceived(Function(ChatMessage) onMsg) {
    _onChatMessageReceived = onMsg;
    if (!isMockMode) {
      socket.on('chat_message_received', (data) {
        onMsg(ChatMessage.fromJson(data));
      });
    }
  }

  void onErrorReceived(Function(String) onErr) {
    _onErrorReceived = onErr;
    if (!isMockMode) {
      socket.on('error_message', (data) {
        onErr(data['message'] ?? 'Error occurred');
      });
    }
  }

  void disconnect() {
    if (!isMockMode) {
      socket.disconnect();
    }
    isConnected = false;
  }
}
