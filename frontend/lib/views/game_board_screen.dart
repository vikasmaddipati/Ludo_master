import 'package:flutter/material.dart';
import 'dart:async';
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
import '../services/accessibility_service.dart';
import '../services/voice_feedback_service.dart';
import 'settings_screen.dart';
import 'dart:math';

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

class _GameBoardScreenState extends State<GameBoardScreen> with TickerProviderStateMixin {
  late GameRoomModel _room;
  final LiveKitService _liveKit = LiveKitService.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  late final ValueNotifier<List<ChatMessage>> _chatNotifier;
  
  List<int> _validTokens = [];
  final List<ChatMessage> _messages = [];
  bool _isVoiceMuted = false;
  bool _isPTTActive = false;

  final List<FloatingEmoji> _activeEmojis = [];
  bool _showDebugPanel = false;
  bool _isWinnerDialogShown = false;

  String? _presetNotifyText;
  String? _presetNotifySender;
  AnimationController? _presetSlideController;
  Timer? _presetDismissTimer;

  String? _liveMoveNotificationText;
  Timer? _liveMoveNotificationTimer;
  List<LudoTokenModel> _previousTokens = [];

  void _triggerFloatingEmoji(String emoji, String senderName) {
    if (!mounted) return;
    final key = UniqueKey();
    setState(() {
      _activeEmojis.add(FloatingEmoji(
        emoji: emoji,
        senderName: senderName,
        key: key,
      ));
    });
  }

  Alignment _getCornerAlignment(String colorKey) {
    if (colorKey == 'red') return Alignment.bottomLeft;
    if (colorKey == 'green') return Alignment.topLeft;
    if (colorKey == 'yellow') return Alignment.topRight;
    return Alignment.bottomRight;
  }

  void _triggerPresetNotification(String text, String sender) {
    if (!mounted) return;
    _presetDismissTimer?.cancel();
    
    setState(() {
      _presetNotifyText = text;
      _presetNotifySender = sender;
    });

    _presetSlideController?.forward(from: 0.0);

    _presetDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _presetSlideController?.reverse().then((_) {
          if (mounted) {
            setState(() {
              _presetNotifyText = null;
              _presetNotifySender = null;
            });
          }
        });
      }
    });
  }

  Widget _buildCornerProfileBadge(PlayerModel p) {
    double? top, left, right, bottom;
    if (p.color == 'green') {
      top = 8; left = 8;
    } else if (p.color == 'yellow') {
      top = 8; right = 8;
    } else if (p.color == 'red') {
      bottom = 8; left = 8;
    } else if (p.color == 'blue') {
      bottom = 8; right = 8;
    }

    final avatarUrl = _getPlayerAvatarUrl(p);
    final themeColor = _getColorValue(p.color);

    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: ValueListenableBuilder<List<String>>(
        valueListenable: _liveKit.activeSpeakersNotifier,
        builder: (context, activeSpeakers, _) {
          return ValueListenableBuilder<Map<String, bool>>(
            valueListenable: _liveKit.participantMuteStatesNotifier,
            builder: (context, muteStates, _) {
              final isSpeaking = activeSpeakers.contains(p.userId);
              final isMuted = muteStates[p.userId] ?? true;
              final isTurn = _room.turn == p.color;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // Avatar circular frame with glowing rings
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (isSpeaking)
                              BoxShadow(
                                color: AppColors.green.withValues(alpha: 0.7),
                                blurRadius: 10,
                                spreadRadius: 3,
                              )
                            else if (isTurn)
                              BoxShadow(
                                color: themeColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                          border: Border.all(
                            color: isSpeaking
                                ? AppColors.green
                                : (isTurn ? themeColor : Colors.white24),
                            width: 2.0,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(avatarUrl),
                          backgroundColor: AppColors.surfaceLight,
                        ),
                      ),
                      
                      // Small microphone state overlay indicator
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isMuted 
                              ? AppColors.red 
                              : (isSpeaking ? AppColors.green : AppColors.secondary),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: Icon(
                          isMuted 
                              ? Icons.mic_off 
                              : (isSpeaking ? Icons.volume_up : Icons.mic),
                          size: 8,
                          color: isMuted || isSpeaking ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Small compact nameplate
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: SizedBox(
                      width: 50,
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLiveMoveNotificationOverlay() {
    if (_liveMoveNotificationText == null) return const SizedBox.shrink();
    final parts = _liveMoveNotificationText!.split('\n');
    final title = parts.first;
    final subtitle = parts.length > 1 ? parts[1] : '';

    return Positioned(
      top: 100,
      left: 32,
      right: 32,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D1B30), Color(0xFF2B2844)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.secondary.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars, color: AppColors.secondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myPlayer = _room.players.firstWhere((p) => p.userId == widget.myUser.id);
    final myColor = myPlayer.color;
    
    // In local Local Arena (mock mode), any human turn counts as "my turn" for interaction on this physical screen!
    final activeTurnPlayer = _room.players.firstWhere(
      (p) => p.color == _room.turn,
      orElse: () => myPlayer,
    );
    final isGameOver = _room.status == 'finished';
    final isMyTurn = !isGameOver && (widget.socket.isMockMode 
        ? !activeTurnPlayer.isBot 
        : _room.turn == myColor);
    
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
          IconButton(
            icon: Icon(_showDebugPanel ? Icons.developer_mode : Icons.developer_mode_outlined, color: Colors.amber),
            tooltip: 'Toggle Dev Panel',
            onPressed: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'light');
              setState(() {
                _showDebugPanel = !_showDebugPanel;
              });
            },
          ),
          // Voice Chat Button with Connection States
          ValueListenableBuilder<String>(
            valueListenable: _liveKit.connectionStatusNotifier,
            builder: (context, status, child) {
              Color indicatorColor = AppColors.textSecondary;
              IconData micIcon = Icons.mic_off;
              if (status == 'Connected') {
                indicatorColor = _isVoiceMuted ? AppColors.red : AppColors.secondary;
                micIcon = _isVoiceMuted ? Icons.mic_off : Icons.mic;
              } else if (status == 'Connecting...') {
                indicatorColor = Colors.amber;
                micIcon = Icons.loop;
              } else if (status == 'Failed' || status == 'Token Error') {
                indicatorColor = AppColors.red;
                micIcon = Icons.error_outline;
              }
              return Tooltip(
                message: 'Voice: $status',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status == 'Connecting...')
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.amber),
                      ),
                    IconButton(
                      icon: Icon(micIcon, color: indicatorColor),
                      onPressed: () {
                        AccessibilityService.instance.triggerHaptic(intensity: 'light');
                        if (status == 'Connected') {
                          AccessibilityService.instance.speak(_isVoiceMuted ? "Voice chat unmuted" : "Voice chat muted");
                          _toggleVoiceMute();
                        } else {
                          AccessibilityService.instance.speak("Voice chat reconnecting");
                          _initializeLiveKitVoice();
                        }
                      },
                    ),
                  ],
                ),
              );
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
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Active Speakers Glowing Badge Bar
                    ValueListenableBuilder<List<String>>(
                      valueListenable: _liveKit.activeSpeakersNotifier,
                      builder: (context, speakers, child) {
                        if (speakers.isEmpty) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.volume_up, color: AppColors.secondary, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                'Speaking: ',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              ...speakers.map((s) {
                                final p = _room.players.firstWhere(
                                  (player) => player.userId == s,
                                  orElse: () => PlayerModel(userId: s, name: s == widget.myUser.id ? widget.myUser.name : 'Player', color: 'red', isReady: true, isConnected: true, isBot: false),
                                );
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getColorValue(p.color).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getColorValue(p.color).withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    p.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _getColorValue(_room.turn).withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: _getColorValue(_room.turn).withOpacity(0.5),
                      width: 2.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing active avatar border ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulseVal = _pulseController.value;
                          return Container(
                            padding: EdgeInsets.all(2 + 2 * pulseVal),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _getColorValue(_room.turn).withOpacity(0.3 + 0.7 * (1.0 - pulseVal)),
                                width: 2.0,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundImage: NetworkImage(_getPlayerAvatarUrl(activeTurnPlayer)),
                              backgroundColor: AppColors.surfaceLight,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                activeTurnPlayer.name,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14),
                              ),
                              if (activeTurnPlayer.isBot) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'BOT',
                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getColorValue(_room.turn),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isMyTurn ? 'YOUR TURN' : "WAITING FOR ${activeTurnPlayer.name.toUpperCase()}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: isMyTurn ? AppColors.secondary : AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LudoBoard(
                          room: _room,
                          myColor: widget.socket.isMockMode ? _room.turn : myColor,
                          validTokensToMove: _validTokens,
                          onTokenTap: _handleTokenMovement,
                        ),
                        
                        // Corner Profile badges (speaking/mic statuses)
                        ..._room.players.map((p) => _buildCornerProfileBadge(p)),

                        // Sliding preset toast overlay alert
                        if (_presetNotifyText != null)
                          Positioned(
                            top: 8,
                            left: 12,
                            right: 12,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -1.5),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _presetSlideController!,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.secondary.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondary.withValues(alpha: 0.15),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chat_bubble_outline,
                                        color: AppColors.secondary,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _presetNotifySender!,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            _presetNotifyText!,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        // Developer Debug Panel Overlay
                        if (_showDebugPanel)
                          Positioned(
                            top: 60,
                            left: 12,
                            right: 12,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.developer_board, color: Colors.amber, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              "DEVELOPER DEBUG PANEL",
                                              style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                          onPressed: () {
                                            setState(() {
                                              _showDebugPanel = false;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const Divider(color: Colors.white24, height: 10),
                                    Text("Room Code: ${_room.roomCode}", style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
                                    Text("Socket Connected: ${widget.socket.isConnected}", style: TextStyle(color: widget.socket.isConnected ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    Text("Current Turn: ${_room.turn.toUpperCase()}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    Text("Current Player Name: ${activeTurnPlayer.name}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    Text("Current Player Color: ${activeTurnPlayer.color.toUpperCase()}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    Text("Dice Value: ${_room.diceValue}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    Text("Dice hasRolled: ${_room.hasRolled}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                    Text("Available Moves (Token IDs): $_validTokens", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Corner emoji animations layer
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: _activeEmojis.map((fe) {
                                final p = _room.players.firstWhere(
                                  (player) => player.name == fe.senderName,
                                  orElse: () => _room.players.first,
                                );
                                final alignment = _getCornerAlignment(p.color);
                                return Align(
                                  alignment: alignment,
                                  child: FloatingEmojiWidget(
                                    key: fe.key,
                                    emoji: fe.emoji,
                                    senderName: fe.senderName,
                                    alignment: alignment,
                                    onComplete: () {
                                      if (mounted) {
                                        setState(() {
                                          _activeEmojis.removeWhere((item) => item.key == fe.key);
                                        });
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
    
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Color: ${(widget.socket.isMockMode ? _room.turn : myColor).toUpperCase()}',
                            style: TextStyle(
                              color: _getColorValue(widget.socket.isMockMode ? _room.turn : myColor),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      // Push-To-Talk voice mode micro-channel controls
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Listener(
                            onPointerDown: (event) async {
                              AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                              await _liveKit.setMicrophoneActive(true);
                              if (mounted) {
                                setState(() {
                                  _isPTTActive = true;
                                });
                              }
                            },
                            onPointerUp: (event) async {
                              await _liveKit.setMicrophoneActive(false);
                              if (mounted) {
                                setState(() {
                                  _isPTTActive = false;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isPTTActive ? AppColors.green : AppColors.surfaceLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isPTTActive ? Colors.white : AppColors.secondary.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  if (_isPTTActive)
                                    BoxShadow(
                                      color: AppColors.green.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: Icon(
                                _isPTTActive ? Icons.mic : Icons.mic_none,
                                color: _isPTTActive ? Colors.black : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isPTTActive ? 'TALKING...' : 'HOLD TALK',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: _isPTTActive ? AppColors.green : AppColors.textSecondary,
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
                                if (_room.status == 'finished') return;
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
          if (_liveMoveNotificationText != null)
            _buildLiveMoveNotificationOverlay(),
        ],
      ),
    );
  }

  String _numberToWord(int number) {
    if (number < 0) return number.toString();
    const units = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"];
    const tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"];
    if (number < 20) {
      return units[number];
    }
    if (number < 100) {
      int tenPart = number ~/ 10;
      int unitPart = number % 10;
      if (unitPart == 0) {
        return tens[tenPart];
      } else {
        return "${tens[tenPart]} ${units[unitPart]}";
      }
    }
    return number.toString();
  }

  void _detectAndAnnounceTokenMovement(GameRoomModel updatedRoom) {
    // Find which token moved and construct details
    LudoTokenModel? movedToken;
    LudoTokenModel? oldTokenState;
    for (var updatedToken in updatedRoom.tokens) {
      final oldToken = _previousTokens.firstWhere(
        (t) => t.color == updatedToken.color && t.tokenId == updatedToken.tokenId,
        orElse: () => LudoTokenModel(color: updatedToken.color, tokenId: updatedToken.tokenId, position: -1),
      );
      if (oldToken.position != updatedToken.position) {
        movedToken = updatedToken;
        oldTokenState = oldToken;
        break;
      }
    }

    if (movedToken != null && oldTokenState != null) {
      final String colorName = movedToken.color.toUpperCase();
      final String colorLabel = "${movedToken.color[0].toUpperCase()}${movedToken.color.substring(1)} token";
      final int oldPos = oldTokenState.position;
      final int newPos = movedToken.position;
      int steps = newPos - oldPos;
      if (oldPos == -1) steps = 1; // board entry from yard

      String visualMsg = "";
      String voiceMsg = "";

      // Check capture
      bool captureOccurred = false;
      String capturedColor = "";
      for (var updatedToken in updatedRoom.tokens) {
        final oldTok = _previousTokens.firstWhere(
          (t) => t.color == updatedToken.color && t.tokenId == updatedToken.tokenId,
          orElse: () => updatedToken,
        );
        if (oldTok.color != movedToken.color && oldTok.position >= 0 && updatedToken.position == -1) {
          captureOccurred = true;
          capturedColor = "${updatedToken.color[0].toUpperCase()}${updatedToken.color.substring(1)} token";
          break;
        }
      }

      if (captureOccurred) {
        final startIndex = {'red': 0, 'green': 13, 'yellow': 26, 'blue': 39};
        final start = startIndex[movedToken.color] ?? 0;
        final globalIndex = (start + newPos) % 52;
        visualMsg = "$colorLabel captured $capturedColor at tile $globalIndex.";
        voiceMsg = "$colorLabel captured $capturedColor at tile $globalIndex.";
      } else if (oldPos == -1 && newPos == 0) {
        visualMsg = "$colorLabel entered the board.";
        voiceMsg = "$colorLabel entered the board.";
      } else if (newPos == 99) {
        visualMsg = "$colorLabel reached home.";
        voiceMsg = "$colorLabel reached home.";
      } else {
        visualMsg = "$colorLabel moved from tile $oldPos to tile $newPos.";
        voiceMsg = "$colorLabel moved from tile $oldPos to tile $newPos.";
      }

      // Logging requirement:
      print("[TOKEN ANNOUNCEMENT]");
      print("Color: $colorName");
      print("Old Tile: $oldPos");
      print("New Tile: $newPos");
      print("Steps: $steps");
      print("Speech: $voiceMsg");

      final fromStr = oldPos == -1 ? "Home" : "$oldPos";
      final toStr = newPos == -1 ? "Home" : newPos == 99 ? "Home" : "$newPos";
      final String positionDesc = "$colorName: $fromStr → $toStr";

      setState(() {
        _liveMoveNotificationText = "$visualMsg\n$positionDesc";
      });

      print("[TTS] Color: ${movedToken.color.toUpperCase()}");
      print("[TTS] From Tile: $oldPos");
      print("[TTS] To Tile: $newPos");
      print("[TTS] Speaking movement announcement");
      print("[TTS DEBUG]\nMovement Popup:\n$visualMsg");
      print("[TTS DEBUG]\nSpeaking:\n$voiceMsg");

      // Trigger Voice TTS Announcement using the existing AccessibilityService speak after move animation finishes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          AccessibilityService.instance.speak(
            voiceMsg,
            force: true,
            turnColor: movedToken!.color,
            type: 'token_moved',
            onStart: () {
              print("[TTS] Speech started");
            },
            onComplete: () {
              print("[TTS] Speech completed");
              print("[TTS DEBUG]\nSpeech Completed Successfully");
            },
            onError: (err) {
              print("[TTS ERROR]\nReason: $err");
            },
          );
        }
      });

      // Auto hide after 2.5 seconds
      _liveMoveNotificationTimer?.cancel();
      _liveMoveNotificationTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _liveMoveNotificationText = null;
          });
        }
      });
    }

    // ALWAYS sync the previous tokens after check
    _previousTokens = updatedRoom.tokens.map((t) => LudoTokenModel(color: t.color, tokenId: t.tokenId, position: t.position)).toList();
  }

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _previousTokens = widget.initialRoom.tokens.map((t) => LudoTokenModel(color: t.color, tokenId: t.tokenId, position: t.position)).toList();
    _chatNotifier = ValueNotifier<List<ChatMessage>>([]);
    
    // Initialize turn avatar pulse animation loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _presetSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _setupGameplayListeners();
    _initializeLiveKitVoice();
    
    // Safely announce that the match started and the game screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityService.instance.announceScreen("Ludo Match");
      AccessibilityService.instance.announceGameEvent("Ludo Match Started");
    });
  }


  void _setupGameplayListeners() {
    // Listen for room updates
    widget.socket.onRoomUpdated((updatedRoom) {
      if (mounted) {
        VoiceFeedbackService.instance.updateCurrentGameTurn(updatedRoom.turn);
        _detectAndAnnounceTokenMovement(updatedRoom);
        final previousTurn = _room.turn;
        print("[DICE] Room updated callback. Prev turn: $previousTurn, New turn: ${updatedRoom.turn}, hasRolled: ${updatedRoom.hasRolled}");
        setState(() {
          _room = updatedRoom;
          // If turn shifts, reset selectable options
          if (!_room.hasRolled) {
            _validTokens = [];
          }
        });

        // Speak aloud turn shift changes
        if (updatedRoom.turn != previousTurn) {
          print("[DICE] Turn state updated. Current player turn: ${updatedRoom.turn}");
          final String colorName = updatedRoom.turn[0].toUpperCase() + updatedRoom.turn.substring(1);
          final isMyTurn = widget.socket.isMockMode 
              ? !updatedRoom.players.firstWhere((p) => p.color == updatedRoom.turn, orElse: () => updatedRoom.players.first).isBot
              : updatedRoom.turn == _room.players.firstWhere((p) => p.userId == widget.myUser.id).color;
          if (isMyTurn) {
            AccessibilityService.instance.announceGameEvent("It is now $colorName player's turn. Your turn.", turnColor: updatedRoom.turn, type: 'turn_changed');
            AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
          } else {
            AccessibilityService.instance.announceGameEvent("It is now $colorName player's turn.", turnColor: updatedRoom.turn, type: 'turn_changed');
          }
        } else if (_room.hasRolled && !updatedRoom.hasRolled && updatedRoom.status == 'playing') {
          final String colorName = updatedRoom.turn[0].toUpperCase() + updatedRoom.turn.substring(1);
          AccessibilityService.instance.announceGameEvent("$colorName player received an extra turn.", turnColor: updatedRoom.turn, type: 'turn_changed');
        }
      }
    });

    // Handle dice rolled
    widget.socket.onDiceRolled((updatedRoom, validTokens) {
      if (mounted) {
        VoiceFeedbackService.instance.updateCurrentGameTurn(updatedRoom.turn);
        print("[DICE] Dice rolled callback. Rolled value: ${updatedRoom.diceValue}, Valid moves for ${updatedRoom.turn}: $validTokens");
        print("[DICE RESULT] ${updatedRoom.diceValue}");
        _detectAndAnnounceTokenMovement(updatedRoom);
        setState(() {
          _room = updatedRoom;
          _validTokens = validTokens;
        });
        _playDiceSound();
        
        // Speak rolled outcome
        AccessibilityService.instance.announceGameEvent("Dice rolled. Number ${updatedRoom.diceValue}.", turnColor: updatedRoom.turn, type: 'dice_rolled');

        // --- FEATURE 1: AUTO MOVE WHEN NO TOKEN IS ON THE BOARD ---
        final myPlayer = updatedRoom.players.firstWhere(
          (p) => p.userId == widget.myUser.id,
          orElse: () => updatedRoom.players.first,
        );
        final isMyTurn = widget.socket.isMockMode 
            ? !updatedRoom.players.firstWhere((p) => p.color == updatedRoom.turn, orElse: () => updatedRoom.players.first).isBot
            : updatedRoom.turn == myPlayer.color;

        if (isMyTurn && validTokens.isNotEmpty) {
          final myTokens = updatedRoom.tokens.where((t) => t.color == updatedRoom.turn).toList();
          final hasNoTokensOnBoard = myTokens.every((t) => t.position == -1 || t.position == 99);
          
          bool shouldAutoMove = false;
          final autoTokenId = validTokens.first;

          if (hasNoTokensOnBoard) {
            shouldAutoMove = true;
            print("[AUTO_MOVE] No tokens on board. Auto-moving token $autoTokenId out of home yard.");
          } else if (validTokens.length == 1) {
            shouldAutoMove = true;
            print("[AUTO_MOVE] Only one legal move. Auto-moving token $autoTokenId.");
          }

          if (shouldAutoMove) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && _room.turn == updatedRoom.turn && _room.hasRolled && _validTokens.contains(autoTokenId)) {
                _handleTokenMovement(autoTokenId);
              }
            });
          }
        }

        // If no moves are possible, show a visual sliding toast notification
        if (validTokens.isEmpty) {
          print("[DICE] No valid moves available for player: ${updatedRoom.turn}. Turn will auto-shift.");
          final myPlayer = updatedRoom.players.firstWhere(
            (p) => p.userId == widget.myUser.id,
            orElse: () => updatedRoom.players.first,
          );
          final isMyTurn = widget.socket.isMockMode 
              ? !updatedRoom.players.firstWhere((p) => p.color == updatedRoom.turn, orElse: () => updatedRoom.players.first).isBot
              : updatedRoom.turn == myPlayer.color;
          final playerName = isMyTurn ? "You" : updatedRoom.players.firstWhere((p) => p.color == updatedRoom.turn).name;
          _triggerPresetNotification("Rolled ${updatedRoom.diceValue} - No valid moves! Turn shifts.", playerName);
        } else {
          print("[DICE] Selectable tokens: $validTokens");
        }
      }
    });

    // Handle token moves
    widget.socket.onTokenMoved((updatedRoom) {
      if (mounted) {
        VoiceFeedbackService.instance.updateCurrentGameTurn(updatedRoom.turn);
        print("[DICE] Token moved callback. Room: ${updatedRoom.roomCode}, Current turn: ${updatedRoom.turn}, hasRolled: ${updatedRoom.hasRolled}");
        _detectAndAnnounceTokenMovement(updatedRoom);
        setState(() {
          _room = updatedRoom;
          _validTokens = [];
        });
        AccessibilityService.instance.announceGameEvent("Token moved.", turnColor: updatedRoom.turn, type: 'token_moved');
      }
    });

    // Handle chat updates
    widget.socket.onChatMessageReceived((msg) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            _messages[index] = msg.copyWith(status: 'delivered');
          } else {
            _messages.add(msg);
          }
        });
        _chatNotifier.value = List.from(_messages);
        
        // Trigger floating emoji reaction
        if (msg.isEmoji) {
          _triggerFloatingEmoji(msg.message, msg.senderName);
        } else {
          // Trigger preset sliding toast if it's from the opponent
          if (msg.senderName != widget.myUser.name) {
            _triggerPresetNotification(msg.message, msg.senderName);
          }
        }

        if (msg.senderName != widget.myUser.name) {
          AccessibilityService.instance.announceAction("Chat received from ${msg.senderName}", detail: msg.message);
        }
      }
    });

    // Handle game over limits
    widget.socket.onGameOver((winnerId) {
      if (mounted) {
        final winnerPlayer = _room.players.firstWhere(
          (p) => p.userId == winnerId,
          orElse: () => PlayerModel(userId: winnerId, name: 'Winner', color: 'red', isReady: true, isConnected: true, isBot: false),
        );
        final winnerName = winnerPlayer.name;
        _showWinnerAlert(winnerId);
        AccessibilityService.instance.speak("Congratulations! $winnerName is the winner.", force: true);
      }
    });

    // Handle error message
    widget.socket.onErrorReceived((msg) {
      if (mounted) {
        print("[SOCKET ERROR] Received error from server: $msg");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.red,
          ),
        );
      }
    });
  }

  void _initializeLiveKitVoice() async {
    // Automatically join room audio channel using unique userId and display name
    await _liveKit.joinAudioRoom(_room.roomCode, widget.myUser.id, widget.myUser.name);
  }

  void _toggleVoiceMute() {
    _liveKit.toggleMute();
    setState(() {
      _isVoiceMuted = _liveKit.isMuted;
    });
  }

  void _handleTokenMovement(int tokenId) {
    if (_room.status == 'finished') return;
    widget.socket.moveToken(_room.roomCode, tokenId);
  }

  void _openChatOverlay() {
    widget.socket.markMessagesAsRead(_room.roomCode, widget.myUser.name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ValueListenableBuilder<List<ChatMessage>>(
        valueListenable: _chatNotifier,
        builder: (context, currentMessages, child) {
          return ChatDialog(
            messages: currentMessages,
            myName: widget.myUser.name,
            onSendMessage: (msgText, isEmoji, msgId) {
              final localMsg = ChatMessage(
                id: msgId,
                senderName: widget.myUser.name,
                message: msgText,
                isEmoji: isEmoji,
                timestamp: DateTime.now(),
                status: 'sending',
              );
              
              if (mounted) {
                setState(() {
                  _messages.add(localMsg);
                });
                _chatNotifier.value = List.from(_messages);
              }
              
              if (isEmoji) {
                _triggerFloatingEmoji(msgText, widget.myUser.name);
              }

              widget.socket.sendChatMessage(
                _room.roomCode,
                widget.myUser.name,
                msgText,
                isEmoji,
                msgId,
                onDeliveryStatus: (success) {
                  if (mounted) {
                    setState(() {
                      final idx = _messages.indexWhere((m) => m.id == msgId);
                      if (idx != -1) {
                        _messages[idx] = _messages[idx].copyWith(status: success ? 'delivered' : 'sending');
                      }
                    });
                    _chatNotifier.value = List.from(_messages);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showWinnerAlert(String winnerId) {
    if (_isWinnerDialogShown) return;
    setState(() {
      _isWinnerDialogShown = true;
    });

    final winnerPlayer = _room.players.firstWhere(
      (p) => p.userId == winnerId,
      orElse: () => PlayerModel(
        userId: winnerId,
        name: 'Player',
        color: 'red',
        isReady: true,
        isConnected: true,
        isBot: false,
      ),
    );
    final winnerName = winnerPlayer.name;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.4),
                      width: 2.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(28.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Victory Trophy Icon with glows
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    Icon(Icons.emoji_events, size: 90, color: Colors.amber),
                                    Positioned(
                                      top: 0,
                                      child: Icon(Icons.star, size: 24, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Visual Announcement: 🏆 Winner / [WinnerPlayerName] Wins!
                              const Text(
                                '🏆 Winner',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 32,
                                  color: Colors.amber,
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$winnerName Wins!',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              
                              // Winner details card
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundImage: NetworkImage(_getPlayerAvatarUrl(winnerPlayer)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      winnerName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              
                              // Action Buttons row
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.secondary,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 5,
                                        ),
                                        onPressed: () {
                                          AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
                                          Navigator.pop(context); // close dialog
                                          Navigator.pop(context); // exit game board screen
                                        },
                                        child: const Text(
                                          'Play Again',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 1.0,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.white60, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        onPressed: () {
                                          AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                                          Navigator.pop(context); // close dialog
                                          Navigator.pop(context); // exit game board screen
                                        },
                                        child: const Text(
                                          'Back To Home',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 1.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
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
            ),
          ),
        );
      },
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

  String _getPlayerAvatarUrl(PlayerModel player) {
    if (player.isBot) {
      return 'https://api.dicebear.com/7.x/bottts/png?seed=${player.name}';
    }
    if (player.userId == widget.myUser.id) {
      return widget.myUser.avatarUrl;
    }
    return 'https://api.dicebear.com/7.x/adventurer/png?seed=${player.name}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chatNotifier.dispose();
    _presetSlideController?.dispose();
    _presetDismissTimer?.cancel();
    _liveKit.leaveAudioRoom();
    _audioPlayer.dispose();
    if (widget.socket.isMockMode) {
      widget.socket.isMockMode = false;
    }
    widget.socket.disconnect();
    super.dispose();
  }
}

// Model class representing a floating emoji reaction instance
class FloatingEmoji {
  final String emoji;
  final String senderName;
  final Key key;

  FloatingEmoji({
    required this.emoji,
    required this.senderName,
    required this.key,
  });
}

// Widget representing a beautifully styled animated floating emoji reaction bubble
class FloatingEmojiWidget extends StatefulWidget {
  final String emoji;
  final String senderName;
  final Alignment alignment;
  final VoidCallback onComplete;

  const FloatingEmojiWidget({
    required this.emoji,
    required this.senderName,
    required this.alignment,
    required this.onComplete,
    super.key,
  });

  @override
  State<FloatingEmojiWidget> createState() => _FloatingEmojiWidgetState();
}

class _FloatingEmojiWidgetState extends State<FloatingEmojiWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late double _randomX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Subtle random sway drift tailored for corner base floats
    _randomX = Random().nextDouble() * 40 - 20; 

    _yAnimation = Tween<double>(begin: 0.0, end: -150.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15), 
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 55), 
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30), 
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.4), weight: 20), 
      TweenSequenceItem(tween: Tween<double>(begin: 1.4, end: 1.0), weight: 15), 
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 65), 
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_randomX, _yAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                    ),
                    child: Text(
                      widget.senderName,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 48, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
