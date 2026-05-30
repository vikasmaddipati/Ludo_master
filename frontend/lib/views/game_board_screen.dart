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
  
  List<int> _validTokens = [];
  final List<ChatMessage> _messages = [];
  bool _isVoiceMuted = false;

  @override
  Widget build(BuildContext context) {
    final myPlayer = _room.players.firstWhere((p) => p.userId == widget.myUser.id);
    final myColor = myPlayer.color;
    final isMyTurn = _room.turn == myColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room Code: ${_room.roomCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        actions: [
          // Voice Chat Button
          IconButton(
            icon: Icon(
              _isVoiceMuted ? Icons.mic_off : Icons.mic,
              color: _isVoiceMuted ? AppColors.red : AppColors.secondary,
            ),
            tooltip: _isVoiceMuted ? 'Unmute Mic' : 'Mute Mic',
            onPressed: _toggleVoiceMute,
          ),
          
          // Game Chat overlay Button
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.white),
            tooltip: 'Game Chat',
            onPressed: _openChatOverlay,
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
                      myColor: myColor,
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
                            widget.myUser.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Color: ${myColor.toUpperCase()}',
                            style: TextStyle(color: _getColorValue(myColor), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
    
                      // Roll controller
                      Row(
                        children: [
                          DiceWidget(
                            value: _room.diceValue,
                            isMyTurn: isMyTurn,
                            hasRolled: _room.hasRolled,
                            onTap: () {
                              widget.socket.rollDice(_room.roomCode);
                            },
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
  }

  void _setupGameplayListeners() {
    // Listen for room updates
    widget.socket.onRoomUpdated((updatedRoom) {
      if (mounted) {
        setState(() {
          _room = updatedRoom;
          // If turn shifts, reset selectable options
          if (!_room.hasRolled) {
            _validTokens = [];
          }
        });
      }
    });

    // Handle dice rolled
    widget.socket.onDiceRolled((updatedRoom, validTokens) {
      if (mounted) {
        setState(() {
          _room = updatedRoom;
          _validTokens = validTokens;
        });
      }
    });

    // Handle token moves
    widget.socket.onTokenMoved((updatedRoom) {
      if (mounted) {
        setState(() {
          _room = updatedRoom;
          _validTokens = [];
        });
      }
    });

    // Handle chat updates
    widget.socket.onChatMessageReceived((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
      }
    });

    // Handle game over limits
    widget.socket.onGameOver((winnerId) {
      if (mounted) {
        _showWinnerAlert(winnerId);
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

  Color _getColorValue(String colorKey) {
    if (colorKey == 'red') return AppColors.red;
    if (colorKey == 'green') return AppColors.green;
    if (colorKey == 'yellow') return AppColors.yellow;
    return AppColors.blue;
  }

  @override
  void dispose() {
    // Gracefully clean up listeners and connection
    _liveKit.leaveAudioRoom();
    widget.socket.disconnect();
    super.dispose();
  }
}
