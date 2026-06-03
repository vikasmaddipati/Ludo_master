import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/game_room_model.dart';
import '../models/user_model.dart';
import '../models/friend_model.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import 'game_board_screen.dart';
import '../services/accessibility_service.dart';
import 'settings_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final UserModel hostUser;
  final int playerCount;
  final int botCount;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.hostUser,
    this.playerCount = 4,
    this.botCount = 0,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final SocketService _socket = SocketService.instance;
  GameRoomModel? _room;
  String _statusMessage = 'Connecting to room...';

  @override
  Widget build(BuildContext context) {
    final user = widget.hostUser;
    final isHost = _room != null && _room!.creator == user.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room Lobby: ${widget.roomCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            AccessibilityService.instance.triggerHaptic(intensity: 'light');
            AccessibilityService.instance.speak("Leaving room lobby");
            _socket.disconnect();
            Navigator.pop(context);
          },
        ),
        actions: [
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
      body: _room == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.secondary),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    // High Premium Offline Sandbox Mode Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 6,
                        shadowColor: AppColors.primary.withOpacity(0.4),
                      ),
                      icon: Icon(widget.playerCount > 1 ? Icons.people : Icons.offline_bolt, color: Colors.white),
                      label: Text(
                        widget.playerCount > 1 ? 'PLAY LOCAL PASS & PLAY' : 'PLAY OFFLINE VS BOTS',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                      ),
                      onPressed: () {
                        setState(() {
                          _socket.isMockMode = true;
                          _statusMessage = widget.playerCount > 1 
                              ? 'Launching offline Pass & Play arena...' 
                              : 'Launching offline sandbox...';
                        });
                        _connectSocket();
                      },
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Room Code share Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'SHARE CODE WITH FRIENDS',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _room!.roomCode,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  const Text(
                    'PLAYERS (2-4)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  // Player list queue
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.playerCount,
                      itemBuilder: (context, index) {
                        if (index < _room!.players.length) {
                          final player = _room!.players[index];
                          Color badgeColor = Colors.grey;
                          if (player.color == 'red') badgeColor = AppColors.red;
                          if (player.color == 'green') badgeColor = AppColors.green;
                          if (player.color == 'yellow') badgeColor = AppColors.yellow;
                          if (player.color == 'blue') badgeColor = AppColors.blue;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: badgeColor,
                                  radius: 14,
                                  child: Text(
                                    player.color[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  player.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                if (player.isBot)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('BOT', style: TextStyle(fontSize: 8, color: AppColors.textSecondary)),
                                  ),
                                const Spacer(),
                                Icon(
                                  player.isReady ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: player.isReady ? AppColors.secondary : AppColors.textSecondary,
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Empty slot
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.surfaceLight, width: 1, style: BorderStyle.solid),
                            ),
                            child: const Center(
                              child: Text(
                                'Waiting for player...',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  // Actions row
                  Row(
                    children: [
                      if (isHost && _room!.players.length < 4)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Semantics(
                              label: "Add Bot",
                              hint: "Double tap to add a computer bot player to the game lobby.",
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: AppColors.secondary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.android, color: AppColors.secondary),
                                label: const Text('ADD BOT', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                                  AccessibilityService.instance.speak("Computer bot player added");
                                  _socket.addBot(_room!.roomCode);
                                },
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Semantics(
                            label: _room!.players.any((p) => p.userId == user.id && p.isReady) ? "Unready" : "Ready",
                            hint: "Double tap to toggle your readiness state.",
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: _room!.players.any((p) => p.userId == user.id && p.isReady)
                                    ? AppColors.surfaceLight
                                    : AppColors.secondary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                _room!.players.any((p) => p.userId == user.id && p.isReady) ? 'UNREADY' : 'READY',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              onPressed: () {
                                AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                                final isReady = _room!.players.any((p) => p.userId == user.id && p.isReady);
                                AccessibilityService.instance.speak(isReady ? "Ready state canceled" : "Ready selected");
                                _socket.toggleReady(_room!.roomCode, user.id);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Host Start Match
                  if (isHost) ...[
                    Semantics(
                      label: "Start Match",
                      hint: "Double tap to start the Ludo multiplayer match now.",
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: _room!.players.length >= 2
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _room!.players.length >= 2
                            ? () {
                                AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
                                AccessibilityService.instance.speak("Starting Ludo Match");
                                _socket.startGame(_room!.roomCode);
                              }
                            : null,
                        child: const Text(
                          'START MULTIPLAYER MATCH',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      label: "Invite Friends",
                      hint: "Double tap to open the slide drawer and invite your friends to this room.",
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.share, color: AppColors.secondary),
                        label: const Text('INVITE FRIENDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () {
                          AccessibilityService.instance.triggerHaptic(intensity: 'light');
                          AccessibilityService.instance.speak("Opening invite friends drawer");
                          _showInviteFriendsDrawer(context);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    _connectSocket();
    
    // Announce screen transition upon landing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityService.instance.announceScreen("Room Lobby");
    });
  }


  void _connectSocket() {
    _socket.connect(widget.hostUser.id, (err) {
      setState(() => _statusMessage = err);
    });

    // Automatically emit room join parameters
    _socket.joinRoom(widget.roomCode, widget.hostUser.id, widget.hostUser.name, widget.playerCount);

    if (widget.playerCount == 1) {
      for (int i = 0; i < widget.botCount; i++) {
        Future.delayed(Duration(milliseconds: 1000 + i * 500), () {
          _socket.addBot(widget.roomCode);
        });
      }
    }

    _socket.onRoomUpdated((updatedRoom) {
      if (mounted) {
        setState(() {
          _room = updatedRoom;
        });
      }
    });

    _socket.onGameStarted((startedRoom) {
      if (mounted) {
        setState(() {
          _room = startedRoom;
        });
        // Stop current socket listener registrations
        _socket.off('room_updated');
        _socket.off('game_started');
        _socket.off('error_message');

        // Route directly to Active Ludo Gameplay Screen!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameBoardScreen(
              initialRoom: startedRoom,
              myUser: widget.hostUser,
              socket: _socket,
            ),
          ),
        );
      }
    });

    _socket.onErrorReceived((msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  void _showInviteFriendsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<List<FriendModel>>(
          future: ApiService.getFriendsList(widget.hostUser.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }
            final friends = snapshot.data ?? [];
            if (friends.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                height: 200,
                child: const Center(
                  child: Text('No friends found. Add some friends first!', style: TextStyle(color: AppColors.textSecondary)),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Invite Friends to Lobby',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final f = friends[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(f.friend.avatarUrl),
                          ),
                          title: Text(f.friend.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Wins: ${f.friend.wins}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: AppColors.background,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              _socket.inviteFriend(
                                roomCode: widget.roomCode,
                                fromUserId: widget.hostUser.id,
                                fromUserName: widget.hostUser.name,
                                toUserId: f.friend.id,
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Invitation sent to ${f.friend.name}!'), backgroundColor: AppColors.green),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    // If room hasn't started and we exit, clean up connection
    if (_room == null || _room!.status == 'waiting') {
      if (_socket.isMockMode) {
        _socket.isMockMode = false;
      }
      _socket.disconnect();
    }
    super.dispose();
  }
}
