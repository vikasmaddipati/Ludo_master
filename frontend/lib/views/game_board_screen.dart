import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/game_room_model.dart';
import '../models/user_model.dart';
import '../models/chat_message.dart';
import '../services/socket_service.dart';
import '../services/livekit_service.dart';
import '../widgets/ludo_board.dart';
import '../widgets/dice_widget.dart';
import '../widgets/chat_dialog.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/voice_assistant_service.dart';
import '../services/global_voice_manager.dart';
import '../services/voice_command_registry.dart';
import '../services/accessibility_service.dart';
import 'settings_screen.dart';

class GameBoardScreen extends StatefulWidget {
  final GameRoomModel initialRoom;
  final UserModel myUser;
  final SocketService socket;

  const GameBoardScreen({
    super.key,
    required this.initialRoom,
    required this.myUser,
    required this.socket,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late GameRoomModel _room;
  final LiveKitService _liveKit = LiveKitService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<int> _validTokens = [];
  final List<ChatMessage> _messages = [];
  bool _isVoiceMuted = false;

  @override
  Widget build(BuildContext context) {
    final myPlayer = _room.players.firstWhere((p) => p.userId == widget.myUser.id);
    final myColor = myPlayer.color;
    
    // In local Pass & Play (mock mode), any human turn counts as "my turn" for interaction on this physical screen!
    final activeTurnPlayer = _room.players.firstWhere(
      (p) => p.color == _room.turn,
      orElse: () => myPlayer,
    );
    final isMyTurn = widget.socket.isMockMode 
        ? !activeTurnPlayer.isBot 
        : _room.turn == myColor;
    
    // Dynamically synchronize the room state for offline fallback support
    widget.socket.syncMockRoom(_room);

    return Scaffold(
      appBar: AppBar(
        title: Text('Match: ${_room.roomCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            AccessibilityService.instance.triggerHaptic(intensity: 'light');
            AccessibilityService.instance.speak("Leaving Ludo match");
            Navigator.pop(context);
          },
        ),
        actions: [
          // Voice Chat Button
          IconButton(
            icon: Icon(
              _isVoiceMuted ? Icons.mic_off : Icons.mic,
              color: _isVoiceMuted ? AppColors.red : AppColors.secondary,
            ),
            tooltip: _isVoiceMuted ? 'Unmute Mic' : 'Mute Mic',
            onPressed: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'light');
              AccessibilityService.instance.speak(_isVoiceMuted ? "Voice chat unmuted" : "Voice chat muted");
              _toggleVoiceMute();
            },
          ),
          
          // Game Chat overlay Button
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'Game Chat',
            onPressed: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'light');
              AccessibilityService.instance.speak("Opening chat drawer");
              _openChatOverlay();
            },
          ),

          // Accessible Settings Hub Button
          Semantics(
            label: "Settings Hub",
            hint: "Open categories for General, Voice, Audio, and Accessibility Settings.",
            button: true,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: 'Settings Hub',
              onPressed: () {
                AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                AccessibilityService.instance.speak("Settings Hub selected");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Turn announcer bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getColorValue(_room.turn),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isMyTurn ? 'YOUR TURN' : "${_room.turn.toUpperCase()}'S TURN",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
    
                // 15x15 Ludo Board Grid
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 400,
                      maxHeight: 400,
                    ),
                    child: LudoBoard(
                      room: _room,
                      myColor: widget.socket.isMockMode ? _room.turn : myColor,
                      validTokensToMove: _validTokens,
                      onTokenTap: _handleTokenMovement,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
    
                // Gameplay controller (Dice roll buttons)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Player profile details
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.socket.isMockMode ? activeTurnPlayer.name : widget.myUser.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Color: ${(widget.socket.isMockMode ? _room.turn : myColor).toUpperCase()}',
                            style: TextStyle(
                              color: _getColorValue(widget.socket.isMockMode ? _room.turn : myColor),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
    
                      // Roll controller
                      Row(
                        children: [
                          Semantics(
                            label: "Ludo Dice",
                            hint: isMyTurn 
                                ? (_room.hasRolled ? "Dice rolled to ${_room.diceValue}. Select a goti to move." : "Your turn. Double tap to roll the dice.")
                                : "Waiting for opponent's turn.",
                            button: isMyTurn && !_room.hasRolled,
                            child: DiceWidget(
                              value: _room.diceValue,
                              isMyTurn: isMyTurn,
                              hasRolled: _room.hasRolled,
                              onTap: () {
                                if (isMyTurn && !_room.hasRolled) {
                                  AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
                                  AccessibilityService.instance.speak("Rolling the Ludo dice");
                                  widget.socket.rollDice(_room.roomCode);
                                } else if (_room.hasRolled) {
                                  AccessibilityService.instance.speak("You already rolled. Please select a valid token to move.");
                                } else {
                                  AccessibilityService.instance.speak("It is not your turn yet.");
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isMyTurn
                                ? (_room.hasRolled ? 'Select Token' : 'Roll Dice!')
                                : 'Waiting...',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _setupGameplayListeners();
    _initializeLiveKitVoice();
    
    // Safely announce that the match started and the game screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityService.instance.announceScreen("Ludo Match");
      AccessibilityService.instance.announceGameEvent("Ludo Match Started");
    });
    
    // Wire global background voice assistant commands
    VoiceAssistantService.instance.addActionListener(_handleVoiceAction);
    
    // Register active game context for screen awareness
    GlobalVoiceManager.instance.setActiveContext("game");
    GlobalVoiceManager.instance.registerContextListener("game", _handleVoiceAction);

    // Register Registry handlers
    final registry = VoiceCommandRegistry.instance;
    registry.registerHandler("ROLL_DICE", (params) async => _handleVoiceAction("ROLL_DICE", params));
    registry.registerHandler("SELECT_TOKEN_INDEX", (params) async => _handleVoiceAction("SELECT_TOKEN_INDEX", params));
    registry.registerHandler("SELECT_TOKEN", (params) async => _handleVoiceAction("SELECT_TOKEN", params));
    registry.registerHandler("SEND_EMOJI", (params) async => _handleVoiceAction("SEND_EMOJI", params));
    registry.registerHandler("OPEN_CHAT", (params) async => _handleVoiceAction("OPEN_CHAT", params));
    registry.registerHandler("JOIN_VOICE_CHAT", (params) async => _handleVoiceAction("JOIN_VOICE_CHAT", params));
    registry.registerHandler("LEAVE_VOICE_CHAT", (params) async => _handleVoiceAction("LEAVE_VOICE_CHAT", params));
    registry.registerHandler("MUTE_MIC", (params) async => _handleVoiceAction("MUTE_MIC", params));
    registry.registerHandler("UNMUTE_MIC", (params) async => _handleVoiceAction("UNMUTE_MIC", params));
  }

  void _handleVoiceAction(String action, Map<String, dynamic> params) {
    if (!mounted) return;

    if (action == "ROLL_DICE") {
      final myPlayer = _room.players.firstWhere((p) => p.userId == widget.myUser.id);
      final myColor = myPlayer.color;
      final activeTurnPlayer = _room.players.firstWhere(
        (p) => p.color == _room.turn,
        orElse: () => myPlayer,
      );
      final isMyTurn = widget.socket.isMockMode 
          ? !activeTurnPlayer.isBot 
          : _room.turn == myColor;
      
      if (isMyTurn) {
        if (_room.hasRolled) {
          VoiceAssistantService.instance.speak("You have already rolled. Please select a valid token on the board to move!", context);
        } else {
          widget.socket.rollDice(_room.roomCode);
          VoiceAssistantService.instance.speak("Rolling the dice for you!", context);
        }
      } else {
        VoiceAssistantService.instance.speak("It is not your turn yet. Please wait for ${_room.turn} to finish.", context);
      }
    } else if (action == "SELECT_TOKEN" || action == "SELECT_TOKEN_INDEX") {
      int? tokenId;
      if (params['index'] != null) {
        tokenId = params['index'] as int;
      } else if (params['tokenId'] != null) {
        tokenId = params['tokenId'] as int;
      }
      
      // Fallback: If no specific token index, pick the first valid token to move
      if (tokenId == null && _validTokens.isNotEmpty) {
        tokenId = _validTokens.first;
      }

      if (tokenId != null) {
        if (_validTokens.contains(tokenId)) {
          _handleTokenMovement(tokenId);
          VoiceAssistantService.instance.speak("Moving token ${tokenId + 1}!", context);
        } else {
          if (_validTokens.isEmpty) {
            VoiceAssistantService.instance.speak("Please roll the dice first before selecting a token to move.", context);
          } else {
            String validNumbersStr = _validTokens.map((id) => (id + 1).toString()).join(" or ");
            VoiceAssistantService.instance.speak("Token ${tokenId + 1} cannot be moved. Please choose token $validNumbersStr.", context);
          }
        }
      } else {
        VoiceAssistantService.instance.speak("Please roll the dice first.", context);
      }
    } else if (action == "OPEN_CHAT") {
      _openChatOverlay();
    } else if (action == "SEND_EMOJI" || action == "CHAT_MESSAGE" || action == "SEND_GAME_CHAT") {
      final msg = params['emoji'] ?? params['message'] ?? "";
      final isEmoji = params['emoji'] != null || params['isEmoji'] == true;
      if (msg.isNotEmpty) {
        widget.socket.sendChatMessage(_room.roomCode, widget.myUser.name, msg, isEmoji);
        VoiceAssistantService.instance.speak("Sent chat message: $msg", context);
      }
    } else if (action == "JOIN_VOICE_CHAT") {
      if (!_liveKit.isConnected) {
        _liveKit.joinAudioRoom(_room.roomCode, widget.myUser.name);
        VoiceAssistantService.instance.speak("Joining LiveKit voice chat.", context);
      }
    } else if (action == "LEAVE_VOICE_CHAT") {
      if (_liveKit.isConnected) {
        _liveKit.leaveAudioRoom();
        VoiceAssistantService.instance.speak("Leaving voice chat room.", context);
      }
    } else if (action == "MUTE_MIC") {
      if (!_liveKit.isMuted) {
        _liveKit.toggleMute();
        VoiceAssistantService.instance.speak("Microphone muted successfully.", context);
      }
    } else if (action == "UNMUTE_MIC") {
      if (_liveKit.isMuted) {
        _liveKit.toggleMute();
        VoiceAssistantService.instance.speak("Microphone unmuted successfully.", context);
      }
    } else if (action == "LEAVE_ROOM") {
      Navigator.pop(context); // exit game
    }
  }

  void _setupGameplayListeners() {
    // Listen for room updates
    widget.socket.onRoomUpdated((updatedRoom) {
      if (mounted) {
        final previousTurn = _room.turn;
        setState(() {
          _room = updatedRoom;
          // If turn shifts, reset selectable options
          if (!_room.hasRolled) {
            _validTokens = [];
          }
        });

        // Speak aloud turn shift changes
        if (updatedRoom.turn != previousTurn) {
          final isMyTurn = widget.socket.isMockMode 
              ? updatedRoom.turn == 'red' 
              : updatedRoom.turn == _room.players.firstWhere((p) => p.userId == widget.myUser.id).color;
          if (isMyTurn) {
            AccessibilityService.instance.announceGameEvent("Your turn.");
            AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
          } else {
            AccessibilityService.instance.announceGameEvent("${updatedRoom.turn.toUpperCase()} turn.");
          }
        }
      }
    });

    // Handle dice rolled
    widget.socket.onDiceRolled((updatedRoom, validTokens) {
      if (mounted) {
        setState(() {
          _room = updatedRoom;
          _validTokens = validTokens;
        });
        _playDiceSound();
        
        // Speak rolled outcome
        AccessibilityService.instance.announceGameEvent("Dice rolled. Number ${updatedRoom.diceValue}.");
      }
    });

    // Handle token moves
    widget.socket.onTokenMoved((updatedRoom) {
      if (mounted) {
        setState(() {
          _room = updatedRoom;
          _validTokens = [];
        });
        
        AccessibilityService.instance.announceGameEvent("Token moved.");
      }
    });

    // Handle chat updates
    widget.socket.onChatMessageReceived((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
        if (msg.senderName != widget.myUser.name) {
          AccessibilityService.instance.announceAction("Chat received from ${msg.senderName}", detail: msg.message);
        }
      }
    });

    // Handle game over limits
    widget.socket.onGameOver((winnerId) {
      if (mounted) {
        _showWinnerAlert(winnerId);
        final isWinner = winnerId == widget.myUser.id;
        if (isWinner) {
          AccessibilityService.instance.announceGameEvent("Congratulations. You won the match.");
        } else {
          AccessibilityService.instance.announceGameEvent("Match finished.");
        }
      }
    });
  }

  void _initializeLiveKitVoice() async {
    // Automatically join room audio channel
    await _liveKit.joinAudioRoom(_room.roomCode, widget.myUser.name);
  }

  void _toggleVoiceMute() {
    _liveKit.toggleMute();
    setState(() {
      _isVoiceMuted = _liveKit.isMuted;
    });
  }

  void _handleTokenMovement(int tokenId) {
    widget.socket.moveToken(_room.roomCode, tokenId);
  }

  void _openChatOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatDialog(
        messages: _messages,
        onSendMessage: (msgText, isEmoji) {
          widget.socket.sendChatMessage(_room.roomCode, widget.myUser.name, msgText, isEmoji);
        },
      ),
    );
  }

  void _showWinnerAlert(String winnerId) {
    final winnerName = _room.players.firstWhere((p) => p.userId == winnerId).name;
    final isMe = winnerId == widget.myUser.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            isMe ? '👑 VICTOR! 👑' : 'GAME OVER',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.secondary),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMe
                  ? 'Awesome job! You won the match and earned +200 coins!'
                  : '$winnerName won the match! Better luck next time.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Back to Home', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(context); // close alert
                Navigator.pop(context); // exit game
              },
            ),
          )
        ],
      ),
    );
  }

  void _playDiceSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/dice_roll.mp3'));
    } catch (e) {
      print('Error playing dice sound: $e');
    }
  }

  Color _getColorValue(String colorKey) {
    if (colorKey == 'red') return AppColors.red;
    if (colorKey == 'green') return AppColors.green;
    if (colorKey == 'yellow') return AppColors.yellow;
    return AppColors.blue;
  }

  @override
  void dispose() {
    VoiceAssistantService.instance.removeActionListener(_handleVoiceAction);
    GlobalVoiceManager.instance.unregisterContextListener("game", _handleVoiceAction);
    
    // Unregister registry handlers
    final registry = VoiceCommandRegistry.instance;
    registry.unregisterHandler("ROLL_DICE");
    registry.unregisterHandler("SELECT_TOKEN_INDEX");
    registry.unregisterHandler("SELECT_TOKEN");
    registry.unregisterHandler("SEND_EMOJI");
    registry.unregisterHandler("OPEN_CHAT");
    registry.unregisterHandler("JOIN_VOICE_CHAT");
    registry.unregisterHandler("LEAVE_VOICE_CHAT");
    registry.unregisterHandler("MUTE_MIC");
    registry.unregisterHandler("UNMUTE_MIC");

    // Gracefully clean up listeners and connection
    _liveKit.leaveAudioRoom();
    _audioPlayer.dispose();
    widget.socket.disconnect();
    super.dispose();
  }
}
