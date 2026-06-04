import 'dart:math';
import 'livekit_service.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_room_model.dart';
import '../models/chat_message.dart';
import 'api_service.dart';

class SocketService {
  late IO.Socket socket;
  static String serverUrl = 'http://192.168.1.13:3000';
  static final SocketService instance = SocketService();

  bool isConnected = false;
  bool isMockMode = false;
  bool _isSocketInitialized = false;

  // Saved callbacks for mock simulation and socket streams
  Function(GameRoomModel)? _onRoomUpdated;
  Function(GameRoomModel)? _onGameStarted;
  Function(GameRoomModel, List<int>)? _onDiceRolled;
  Function(GameRoomModel)? _onTokenMoved;
  Function(String)? _onGameOver;
  Function(ChatMessage)? _onChatMessageReceived;
  Function(String)? _onErrorReceived;

  GameRoomModel? mockRoom;

  // Connection recovery & parameters caching
  String? _currentRoomCode;
  String? _currentUserId;
  String? _currentUserName;
  Function(String)? _connectionErrorCallback;

  // Exponential backoff configuration
  int _reconnectAttempts = 0;
  final List<int> _backoffDelays = [1, 2, 5, 10, 30];
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  // Offline Events Queue
  final List<Map<String, dynamic>> _offlineQueue = [];

  // Developer Diagnostics counters
  int messagesSent = 0;
  int messagesReceived = 0;
  int emojisSent = 0;
  int emojisReceived = 0;
  int reconnectsCount = 0;
  double latencyMs = 0.0;
  Timer? _latencyTimer;

  Future<void> initServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString('server_url') ?? 'http://192.168.1.13:3000';
    print('[SOCKET DEBUG] Loaded Server URL override: $serverUrl');
  }

  void connect(String userId, Function(String) onError) async {
    _connectionErrorCallback = onError;
    _currentUserId = userId;

    if (isMockMode) {
      isConnected = true;
      return;
    }

    // Synchronously initialize socket to prevent late initialization race conditions on startup
    print('[SOCKET DEBUG] Initializing connection synchronously to: $serverUrl');
    socket = IO.io(serverUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );
    _isSocketInitialized = true;

    _setupListeners(userId);
    socket.connect();

    // Asynchronously load SharedPreferences override, and update if mismatched
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url') ?? 'http://192.168.1.13:3000';
      if (savedUrl != serverUrl) {
        print('[SOCKET DEBUG] SharedPreferences URL override mismatch. Dynamically updating to: $savedUrl');
        await updateServerUrl(savedUrl);
      }
    } catch (e) {
      print('[SOCKET DEBUG] SharedPreferences async load error: $e');
    }
  }

  void _setupListeners(String userId) {
    socket.onConnect((_) {
      print('[SOCKET DEBUG] Connected successfully to $serverUrl');
      isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0;
      
      if (isMockMode) {
        print('[SOCKET DEBUG] Connected in Mock Mode. Skipping background register and rejoin emits.');
        return;
      }
      
      socket.emit('register_user', userId);

      // Auto rejoin active room upon connection recovery
      if (_currentRoomCode != null && _currentUserId != null && _currentUserName != null) {
        print('[SOCKET DEBUG] Re-joining active room: $_currentRoomCode after recovery');
        reconnectsCount++;
        socket.emit('join_room', {
          'roomCode': _currentRoomCode,
          'userId': _currentUserId,
          'name': _currentUserName
        });
      }

      // Flush and send offline queue
      _flushOfflineQueue();

      // Start ping-pong latency check
      _startLatencyCheck();
    });

    socket.onDisconnect((_) {
      print('[SOCKET DEBUG] Disconnected from server. Starting retry backoff...');
      isConnected = false;
      _stopLatencyCheck();
      _triggerBackoffReconnect();
    });

    socket.onConnectError((err) {
      print('[SOCKET DEBUG] Connect error: $err');
      isConnected = false;
      // Avoid aggressively clearing room code here. A 'Room not found' error
      // might simply be a temporary glitch or a local offline sandbox room.
      // We want to preserve _currentRoomCode so we can reconnect when back online.
      if (_connectionErrorCallback != null) {
        _connectionErrorCallback!('Unable to connect to $serverUrl.');
      }
      _triggerBackoffReconnect();
    });

    // Re-register active game event streams to survive socket recreation/reconnects
    if (_onRoomUpdated != null) {
      socket.off('room_updated');
      socket.on('room_updated', (data) {
        final room = GameRoomModel.fromJson(data);
        print("[STATE_UPDATED] Received room state update. Turn is now: ${room.turn}");
        print("[TURN_RECEIVED] Server broadcast turn for ${room.turn}");
        _onRoomUpdated!(room);
      });
    }
    if (_onGameStarted != null) {
      socket.off('game_started');
      socket.on('game_started', (data) => _onGameStarted!(GameRoomModel.fromJson(data)));
    }
    if (_onDiceRolled != null) {
      socket.off('dice_rolled');
      socket.on('dice_rolled', (data) {
        final room = GameRoomModel.fromJson(data['room']);
        final validTokens = List<int>.from(data['validTokensToMove'] ?? []);
        print("[DICE_RESULT_RECEIVED] Received dice_rolled from server");
        print("[DICE] Received dice_rolled from server. Room: ${room.roomCode}, value: ${room.diceValue}, validTokens: $validTokens");
        print("[DICE RESULT] ${room.diceValue}");
        _onDiceRolled!(room, validTokens);
      });
    }
    if (_onTokenMoved != null) {
      socket.off('token_moved');
      socket.on('token_moved', (data) => _onTokenMoved!(GameRoomModel.fromJson(data)));
    }
    if (_onGameOver != null) {
      socket.off('game_over');
      socket.on('game_over', (data) => _onGameOver!(data['winnerId'] ?? ''));
    }
    if (_onChatMessageReceived != null) {
      socket.off('chat_message_received');
      socket.on('chat_message_received', (data) {
        final msg = ChatMessage.fromJson(data);
        if (msg.isEmoji) {
          emojisReceived++;
        } else {
          messagesReceived++;
        }
        _onChatMessageReceived!(msg);
      });
    }
    if (_onErrorReceived != null) {
      socket.off('error_message');
      socket.on('error_message', (data) => _onErrorReceived!(data['message'] ?? 'Error occurred'));
    }
  }

  void _triggerBackoffReconnect() {
    if (_isReconnecting || isMockMode) return;
    _isReconnecting = true;

    final delay = _backoffDelays[min(_reconnectAttempts, _backoffDelays.length - 1)];
    print('[SOCKET DEBUG] Reconnect attempt #${_reconnectAttempts + 1} scheduled in $delay seconds...');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _reconnectAttempts++;
      _isReconnecting = false;
      
      // Auto cycle URL fallback targets between primary IP and USB Localhost to guarantee connection
      if (_reconnectAttempts > 1) {
        if (!serverUrl.contains('127.0.0.1') && !serverUrl.contains('localhost')) {
          print('[SOCKET DEBUG] Connection failing. Cycling target temporarily to USB debugging address (http://127.0.0.1:3000)...');
          serverUrl = 'http://127.0.0.1:3000';
          ApiService.updateBaseUrl('http://127.0.0.1:3000');
        } else {
          print('[SOCKET DEBUG] Connection failing. Cycling target back to primary IP...');
          SharedPreferences.getInstance().then((prefs) {
            final saved = prefs.getString('server_url') ?? 'http://192.168.1.13:3000';
            serverUrl = saved;
            ApiService.updateBaseUrl(saved);
          });
        }
      }
      
      print('[SOCKET DEBUG] Retrying connection override to: $serverUrl...');
      if (_isSocketInitialized) {
        socket.disconnect();
        socket = IO.io(serverUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build()
        );
        _setupListeners(_currentUserId ?? '');
        socket.connect();
      }
    });
  }

  Future<void> updateServerUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', newUrl);
    serverUrl = newUrl;
    ApiService.updateBaseUrl(newUrl);

    print('[SOCKET DEBUG] Server override dynamically updated: $newUrl. Reconnecting...');
    
    _reconnectTimer?.cancel();
    _isReconnecting = false;
    _reconnectAttempts = 0;
    
    if (_isSocketInitialized) {
      socket.disconnect();
    }
    
    if (_currentUserId != null) {
      connect(_currentUserId!, _connectionErrorCallback ?? (_) {});
    }
  }

  void _flushOfflineQueue() {
    if (_offlineQueue.isEmpty) return;
    print('[SOCKET DEBUG] Flushing ${_offlineQueue.length} offline events...');
    for (var item in _offlineQueue) {
      final event = item['event'] as String;
      final data = item['data'];
      socket.emit(event, data);
      print('[SOCKET DEBUG] Offline event delivered: $event');
    }
    _offlineQueue.clear();
  }

  void _startLatencyCheck() {
    _latencyTimer?.cancel();
    _latencyTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (isConnected) {
        final start = DateTime.now().millisecondsSinceEpoch;
        socket.emitWithAck('ping_stat', {}, ack: (_) {
          latencyMs = (DateTime.now().millisecondsSinceEpoch - start).toDouble();
        });
      }
    });
  }

  void _stopLatencyCheck() {
    _latencyTimer?.cancel();
    _latencyTimer = null;
  }

  // Action emitters
  void syncMockRoom(GameRoomModel room) {
    if (isMockMode) {
      mockRoom = room;
    }
  }

  void off(String event) {
    if (_isSocketInitialized && !isMockMode) {
      socket.off(event);
    }
  }

  void joinRoom(String roomCode, String userId, String name, [int playerCount = 4]) {
    _currentRoomCode = roomCode;
    _currentUserId = userId;
    _currentUserName = name;

    // Detect if this is a fallback offline room
    if (roomCode.startsWith('sandbox_')) {
      print('[SOCKET DEBUG] Detected sandbox room. Forcing Mock Mode.');
      isMockMode = true;
    }

    if (isMockMode) {
      final colors = ['red', 'green', 'yellow', 'blue'];
      final List<PlayerModel> players = [
        PlayerModel(userId: userId, name: name, color: 'red', isReady: true, isConnected: true, isBot: false)
      ];

      for (int i = 1; i < playerCount; i++) {
        players.add(PlayerModel(
          userId: 'local_${colors[i]}',
          name: 'Player ${colors[i].toUpperCase()}',
          color: colors[i],
          isReady: true,
          isConnected: true,
          isBot: false,
        ));
      }

      mockRoom = GameRoomModel(
        id: 'room_$roomCode',
        roomCode: roomCode,
        creator: userId,
        status: 'waiting',
        turn: 'red',
        diceValue: 1,
        hasRolled: false,
        players: players,
        tokens: [],
        messages: [],
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
      // Immediately attempt to join LiveKit voice room after successful game room join
      LiveKitService.instance.joinAudioRoom(roomCode, userId, name).then((joined) {
        if (!joined) {
          print('[VOICE ERROR] Failed to join LiveKit room for $roomCode');
        }
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
    print("[DICE] rollDice called. roomCode: $roomCode, isMockMode: $isMockMode, isConnected: $isConnected");
    if (isMockMode || !isConnected) {
      if (!isConnected && !isMockMode) {
        print('[SOCKET DEBUG] Offline. Queued dice roll.');
        _offlineQueue.add({
          'event': 'roll_dice',
          'data': {'roomCode': roomCode}
        });
        _triggerBackoffReconnect();
        return;
      }

      isMockMode = true;
      if (mockRoom == null || mockRoom!.status != 'playing' || mockRoom!.hasRolled) {
        print("[DICE] Mock roll ignored. mockRoom: ${mockRoom != null}, status: ${mockRoom?.status}, hasRolled: ${mockRoom?.hasRolled}");
        return;
      }
      final dice = Random().nextInt(6) + 1;
      print("[DICE RESULT] $dice");
      mockRoom!.diceValue = dice;
      mockRoom!.hasRolled = true;

      print("[DICE] Saving mock dice result: $dice");
      print("[DICE] Current player color: ${mockRoom!.turn}");
      
      final valid = _getValidMoves(mockRoom!, mockRoom!.turn, dice);
      print("[DICE] Available moves (tokenIds): $valid");
      
      if (_onDiceRolled != null) {
        print("[DICE] Invoking onDiceRolled callback with mockRoom");
        _onDiceRolled!(mockRoom!, valid);
      }

      if (valid.isEmpty) {
        print("[DICE] No valid moves. Turn shifts local in 1.5s.");
        Future.delayed(const Duration(milliseconds: 1500), () {
          _shiftTurnLocal();
          print("[DICE] Turn state updated");
        });
      }
      return;
    }

    print("[DICE] Emitting roll_dice socket event to server.");
    print("[ROLL_EVENT_SENT] Emitting roll_dice socket event to server.");
    socket.emit('roll_dice', {
      'roomCode': roomCode
    });
  }

  void moveToken(String roomCode, int tokenId) {
    if (isMockMode || !isConnected) {
      if (!isConnected && !isMockMode) {
        print('[SOCKET DEBUG] Offline. Queued token move.');
        _offlineQueue.add({
          'event': 'move_token',
          'data': {
            'roomCode': roomCode,
            'tokenId': tokenId
          }
        });
        _triggerBackoffReconnect();
        return;
      }

      isMockMode = true;
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
      final tokensHomeCount = mockRoom!.tokens.where((t) => t.color == turnColor && t.position == 99).length;
      final totalTokens = mockRoom!.tokens.where((t) => t.color == turnColor).length;
      final colorNameCap = turnColor[0].toUpperCase() + turnColor.substring(1);
      print('[WIN CHECK]');
      print('$colorNameCap Tokens Home: $tokensHomeCount/$totalTokens\n');

      final allHome = mockRoom!.tokens.where((t) => t.color == turnColor).every((t) => t.position == 99);
      if (allHome) {
        final winnerPlayer = mockRoom!.players.firstWhere((p) => p.color == turnColor);
        print('[WINNER DETECTED]');
        print('Winner: ${winnerPlayer.name}\n');
        mockRoom!.status = 'finished';
        mockRoom!.winnerId = winnerPlayer.userId;
      }

      if (_onTokenMoved != null) _onTokenMoved!(mockRoom!);

      if (mockRoom!.status == 'finished') {
        print('[GAME ENDED]');
        print('Match completed successfully\n');
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

  void sendChatMessage(
    String roomCode,
    String senderName,
    String message,
    bool isEmoji,
    String msgId, {
    Function(bool)? onDeliveryStatus,
  }) {
    if (isEmoji) {
      emojisSent++;
    } else {
      messagesSent++;
    }

    if (isMockMode) {
      final msg = ChatMessage(
        id: msgId,
        senderName: senderName,
        message: message,
        isEmoji: isEmoji,
        timestamp: DateTime.now(),
        status: 'delivered',
      );
      if (_onChatMessageReceived != null) _onChatMessageReceived!(msg);
      if (onDeliveryStatus != null) onDeliveryStatus(true);
      return;
    }

    if (!isConnected) {
      print('[SOCKET DEBUG] Offline. Message queued: "$message"');
      _offlineQueue.add({
        'event': 'send_chat_message',
        'data': {
          'roomCode': roomCode,
          'senderName': senderName,
          'message': message,
          'isEmoji': isEmoji,
          'id': msgId
        }
      });
      if (onDeliveryStatus != null) onDeliveryStatus(false);
      _triggerBackoffReconnect();
      return;
    }

    int retryCount = 0;
    const maxRetries = 3;

    void attemptSend() {
      if (!isConnected) {
        if (retryCount < maxRetries) {
          retryCount++;
          Future.delayed(const Duration(seconds: 1), attemptSend);
        } else {
          if (onDeliveryStatus != null) onDeliveryStatus(false);
        }
        return;
      }

      socket.emitWithAck('send_chat_message', {
        'roomCode': roomCode,
        'senderName': senderName,
        'message': message,
        'isEmoji': isEmoji,
        'id': msgId
      }, ack: (data) {
        if (data != null && data['status'] == 'ok') {
          if (onDeliveryStatus != null) onDeliveryStatus(true);
        } else {
          if (retryCount < maxRetries) {
            retryCount++;
            Future.delayed(const Duration(seconds: 1), attemptSend);
          } else {
            if (onDeliveryStatus != null) onDeliveryStatus(false);
          }
        }
      });
    }

    attemptSend();
  }

  void markMessagesAsRead(String roomCode, String userName) {
    if (isMockMode || !isConnected) return;
    socket.emit('mark_messages_read', {
      'roomCode': roomCode,
      'userName': userName
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
    if (!isMockMode && _isSocketInitialized) {
      socket.off('room_updated');
      socket.on('room_updated', (data) {
        onUpdate(GameRoomModel.fromJson(data));
      });
    }
  }

  void onGameStarted(Function(GameRoomModel) onStart) {
    _onGameStarted = onStart;
    if (!isMockMode && _isSocketInitialized) {
      socket.off('game_started');
      socket.on('game_started', (data) {
        onStart(GameRoomModel.fromJson(data));
      });
    }
  }

  void onDiceRolled(Function(GameRoomModel, List<int>) onRoll) {
    _onDiceRolled = onRoll;
    if (!isMockMode && _isSocketInitialized) {
      socket.off('dice_rolled');
      socket.on('dice_rolled', (data) {
        final room = GameRoomModel.fromJson(data['room']);
        final validTokens = List<int>.from(data['validTokensToMove'] ?? []);
        onRoll(room, validTokens);
      });
    }
  }

  void onTokenMoved(Function(GameRoomModel) onMove) {
    _onTokenMoved = onMove;
    if (!isMockMode && _isSocketInitialized) {
      socket.off('token_moved');
      socket.on('token_moved', (data) {
        onMove(GameRoomModel.fromJson(data));
      });
    }
  }

  void onGameOver(Function(String) onWin) {
    _onGameOver = onWin;
    if (!isMockMode && _isSocketInitialized) {
      socket.off('game_over');
      socket.on('game_over', (data) {
        onWin(data['winnerId'] ?? '');
      });
    }
  }

  void onChatMessageReceived(Function(ChatMessage) onMsg) {
    _onChatMessageReceived = onMsg;
    if (!isMockMode && _isSocketInitialized) {
      socket.off('chat_message_received');
      socket.on('chat_message_received', (data) {
        final msg = ChatMessage.fromJson(data);
        if (msg.isEmoji) {
          emojisReceived++;
        } else {
          messagesReceived++;
        }
        onMsg(msg);
      });
    }
  }

  void onErrorReceived(Function(String) onErr) {
    _onErrorReceived = onErr;
    if (!isMockMode && _isSocketInitialized) {
      socket.off('error_message');
      socket.on('error_message', (data) {
        onErr(data['message'] ?? 'Error occurred');
      });
    }
  }

  void inviteFriend({
    required String roomCode,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
  }) {
    if (isMockMode) {
      print('Mock socket: Send room invitation to $toUserId');
      return;
    }
    socket.emit('invite_friend', {
      'roomCode': roomCode,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
    });
  }

  void onReceiveGameInvite(Function(String roomCode, String fromUserId, String fromUserName) onInvite) {
    if (!isMockMode) {
      socket.on('receive_game_invite', (data) {
        onInvite(
          data['roomCode'] ?? '',
          data['fromUserId'] ?? '',
          data['fromUserName'] ?? '',
        );
      });
    }
  }

  void disconnect() {
    _stopLatencyCheck();
    _reconnectTimer?.cancel();
    _isReconnecting = false;
    
    if (_isSocketInitialized && !isMockMode) {
      socket.disconnect();
    }
    isConnected = false;
  }
}
