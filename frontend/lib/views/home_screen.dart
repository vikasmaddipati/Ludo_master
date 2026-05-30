import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'lobby_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  int _currentIndex = 0;
  bool _isClaimingReward = false;
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Tab lists
    final List<Widget> tabs = [
      _buildLobbyTab(user),
      LeaderboardScreen(userId: user.id),
      ProfileScreen(user: user),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(user.avatarUrl),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: ${user.id.substring(0, min(8, user.id.length))}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Coins indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${user.coins}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13),
                ),
              ],
            ),
          ),
          
          // Claim Daily button
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: AppColors.secondary),
            tooltip: 'Daily Reward',
            onPressed: _claimDailyReward,
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Play'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildLobbyTab(user) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ludo Arena',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a private room to play with friends or jump in directly!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 48),

          // Host / Create Room Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Text('CREATE PRIVATE ROOM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => _handleCreateRoom(user),
          ),
          const SizedBox(height: 16),

          // Join Room Button
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: AppColors.secondary, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('JOIN WITH ROOM CODE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
            onPressed: _showJoinRoomDialog,
          ),
        ],
      ),
    );
  }

  void _handleCreateRoom(user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final room = await ApiService.createRoom(user.id, user.name);
    Navigator.pop(context); // Pop loading

    if (room != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(roomCode: room.roomCode, hostUser: user),
        ),
      );
    } else {
      _showSnackbar('Failed to create room. Is your Node server online?');
    }
  }

  void _showJoinRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join Room', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _roomCodeController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: 'Enter 6-digit room code',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
            onPressed: () {
              final code = _roomCodeController.text.trim();
              if (code.length == 6) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LobbyScreen(roomCode: code, hostUser: _auth.currentUser!),
                  ),
                );
              }
            },
          )
        ],
      ),
    );
  }

  void _claimDailyReward() async {
    if (_isClaimingReward) return;
    final user = _auth.currentUser;
    if (user == null) return;
    
    setState(() => _isClaimingReward = true);

    final res = await ApiService.claimDailyReward(user.id, user.coins);
    setState(() => _isClaimingReward = false);

    if (res != null) {
      if (res['success'] == true && res['coins'] != null) {
        setState(() {
          user.coins = res['coins'] is int ? res['coins'] : int.parse(res['coins'].toString());
        });
      }
      _showSnackbar(res['message'] ?? 'Claim result.');
    }
  }

  void _showSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }
}
