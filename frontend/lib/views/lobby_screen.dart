import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/game_room_model.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import 'game_board_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final UserModel hostUser;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.hostUser,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final SocketService _socket = SocketService();
  GameRoomModel? _room;
  String _statusMessage = 'Connecting to room...';

  @override
  Widget build(BuildContext context) {
    final user = widget.hostUser;
    final isHost = _room != null && _room!.creator == user.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('Room Lobby: ${widget.roomCode}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        elevation: 0,
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
                      icon: const Icon(Icons.offline_bolt, color: Colors.white),
                      label: const Text(
                        'PLAY OFFLINE VS BOTS',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                      ),
                      onPressed: () {
                        setState(() {
                          _socket.isMockMode = true;
                          _statusMessage = 'Launching offline sandbox...';
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
                      itemCount: 4,
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
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: AppColors.secondary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.android, color: AppColors.secondary),
                              label: const Text('ADD BOT', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                              onPressed: () => _socket.addBot(_room!.roomCode),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
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
                            onPressed: () => _socket.toggleReady(_room!.roomCode, user.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Host Start Match
                  if (isHost)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: _room!.players.length >= 2
                            ? AppColors.primary
                            : AppColors.surfaceLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _room!.players.length >= 2
                          ? () => _socket.startGame(_room!.roomCode)
                          : null,
                      child: const Text(
                        'START MULTIPLAYER MATCH',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    _socket.connect(widget.hostUser.id, (err) {
      setState(() => _statusMessage = err);
    });

    // Automatically emit room join parameters
    _socket.joinRoom(widget.roomCode, widget.hostUser.id, widget.hostUser.name);

    _socket.onRoomUpdated((updatedRoom) {
      if (mounted) {
        setState(() {
          _room = updatedRoom;
        });
      }
    });

    _socket.onGameStarted((startedRoom) {
      if (mounted) {
        // Stop current socket listener registrations
        _socket.socket.off('room_updated');
        _socket.socket.off('game_started');

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  @override
  void dispose() {
    // If room hasn't started and we exit, clean up connection
    if (_room == null || _room!.status == 'waiting') {
      _socket.disconnect();
    }
    super.dispose();
  }
}
