import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'lobby_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';
import '../services/socket_service.dart';

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
  void initState() {
    super.initState();
    _initSocketInvitationListener();
  }

  void _initSocketInvitationListener() {
    final user = _auth.currentUser;
    if (user != null) {
      SocketService.instance.connect(user.id, (err) {
        print("Socket connection error in HomeScreen: $err");
      });
      SocketService.instance.onReceiveGameInvite((roomCode, fromUserId, fromUserName) {
        if (mounted) {
          _showGameInviteDialog(roomCode, fromUserName);
        }
      });
    }
  }

  void _showGameInviteDialog(String roomCode, String fromUserName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.gamepad, color: AppColors.secondary),
            SizedBox(width: 8),
            Text('Game Invitation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '$fromUserName has invited you to play Ludo!\nRoom Code: $roomCode',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Decline', style: TextStyle(color: AppColors.red)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Join Play', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LobbyScreen(roomCode: roomCode, hostUser: _auth.currentUser!),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Tab lists
    final List<Widget> tabs = [
      _buildLobbyTab(user),
      FriendsScreen(currentUser: user),
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
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildLobbyTab(user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gorgeous Glassmorphic Hero Banner Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C1E4E), Color(0xFF160F2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on, color: AppColors.secondary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'ARENA ACTIVE',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.casino, color: Colors.white54, size: 28),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ludo Arena Master',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Roll the dice, capture opponent tokens, and claim your place in the global hall of fame!',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  // Tiny Statistics Bar inside Banner
                  Row(
                    children: [
                      _buildMiniStat(Icons.emoji_events, 'Wins', '${user.wins}'),
                      const SizedBox(width: 24),
                      _buildMiniStat(Icons.monetization_on, 'Coins', '${user.coins}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // CREATE PRIVATE LOBBY CARD (Vibrant Purple to Pink Gradient Button)
            InkWell(
              onTap: () => _showPlayerCountDialog(user),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sports_esports, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CREATE GAME ROOM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Host a private match vs friends or bots',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // JOIN ROOM CARD (Elegant Neon Cyan Outlined Button)
            InkWell(
              onTap: _showJoinRoomDialog,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.8), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF13363B),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.group_add, color: AppColors.secondary, size: 28),
                    ),
                    SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'JOIN WITH ROOM CODE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Enter a 6-digit lobby code to join a match',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: AppColors.secondary, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondary, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  void _showPlayerCountDialog(user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Select Players Count',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlayerOptionCard(context, user, 1, '1 Player (vs Bots)', Icons.person, 'Play solo against customizable smart AI bots.'),
            const SizedBox(height: 12),
            _buildPlayerOptionCard(context, user, 2, '2 Players', Icons.people_outline, 'Play a standard 1v1 match with a friend or bot.'),
            const SizedBox(height: 12),
            _buildPlayerOptionCard(context, user, 3, '3 Players', Icons.people, 'Play a dynamic 3-way board match.'),
            const SizedBox(height: 12),
            _buildPlayerOptionCard(context, user, 4, '4 Players', Icons.groups, 'Full 4-player ultimate Ludo arena.'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerOptionCard(BuildContext dialogContext, user, int count, String title, IconData icon, String subtitle) {
    return InkWell(
      onTap: () {
        Navigator.pop(dialogContext);
        if (count == 1) {
          _showBotCountDialog(user);
        } else {
          _handleCreateRoom(user, count, 0);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.secondary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBotCountDialog(user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'How many Bots?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBotOptionCard(context, user, 1, '1 Bot', 'Play standard 1v1 match against 1 AI Bot.'),
            const SizedBox(height: 12),
            _buildBotOptionCard(context, user, 2, '2 Bots', 'Play 3-player match with 2 AI Bots.'),
            const SizedBox(height: 12),
            _buildBotOptionCard(context, user, 3, '3 Bots', 'Play ultimate 4-player match with 3 AI Bots.'),
          ],
        ),
      ),
    );
  }

  Widget _buildBotOptionCard(BuildContext dialogContext, user, int botCount, String title, String subtitle) {
    return InkWell(
      onTap: () {
        Navigator.pop(dialogContext);
        _handleCreateRoom(user, 1, botCount);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceLight, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.android, color: AppColors.secondary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreateRoom(user, int playerCount, [int botCount = 0]) async {
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
          builder: (context) => LobbyScreen(
            roomCode: room.roomCode,
            hostUser: user,
            playerCount: playerCount,
            botCount: botCount,
          ),
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
