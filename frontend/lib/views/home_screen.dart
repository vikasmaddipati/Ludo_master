import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'lobby_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';
import '../services/socket_service.dart';
import '../services/audio_service.dart';
import '../services/accessibility_service.dart';
import 'settings_screen.dart';
import '../widgets/accessible_interactive.dart';
import 'rewards_screen.dart';
import '../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  int _currentIndex = 0;
  bool _isClaimingReward = false;
  final TextEditingController _roomCodeController = TextEditingController();
  late AnimationController _bgAnimationController;

  // UI Flow Switch: 0 = main actions, 1 = bot difficulty, 2 = local player selection, 3 = online menu
  int _playSubMenu = 0;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
    _initSocketInvitationListener();
    AudioService.instance.initializeBackgroundMusic();
    _updateActiveScreenContext(_currentIndex);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _updateActiveScreenContext(int index) {
    String screenName = "Home";
    if (index == 1) {
      screenName = "Rewards Hub";
    }
    if (index == 2) {
      screenName = "Friends List";
    }
    if (index == 3) {
      screenName = "Leaderboard";
    }
    if (index == 4) {
      screenName = "Profile Details";
    }
    AccessibilityService.instance.announceScreen(screenName);
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

  // Bypasses lobby setup to launch local pass-and-play or bot games immediately (1-tap quick play)
  void _startLocalMatch(UserModel user, int playerCount, int botCount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final socketService = SocketService.instance;
    socketService.isMockMode = true;

    // Generate random 6 digit code for mock environment
    final rng = Random();
    final roomCode = List.generate(6, (_) => rng.nextInt(10).toString()).join();

    socketService.connect(user.id, (err) {});
    socketService.joinRoom(roomCode, user.id, user.name, playerCount);

    for (int i = 0; i < botCount; i++) {
      socketService.addBot(roomCode);
    }

    socketService.startGame(roomCode);
    Navigator.pop(context); // Pop loading

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyScreen(
          roomCode: roomCode,
          hostUser: user,
          playerCount: playerCount,
          botCount: botCount,
        ),
      ),
    );
  }

  void _handleCreateRoom(UserModel user, int playerCount, [int botCount = 0]) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    final room = await ApiService.createRoom(user.id, user.name);
    Navigator.pop(context); // Pop loading

    if (room != null) {
      if (mounted) {
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
      }
    } else {
      _showSnackbar('Failed to create room. Is your Node server online?');
    }
  }

  void _showJoinRoomDialog() {
    AccessibilityService.instance.speak("Join Room dialog opened. Please enter six-digit room code.", force: true);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.vpn_key, color: AppColors.secondary),
            SizedBox(width: 10),
            Text(
              'Join Online Room',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Semantics(
          label: "Enter six-digit room code text field",
          child: TextField(
            controller: _roomCodeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            maxLength: 6,
            onChanged: (text) {
              if (text.isNotEmpty) {
                final lastChar = text.substring(text.length - 1);
                AccessibilityService.instance.speak(lastChar, force: true);
              }
            },
            decoration: InputDecoration(
              hintText: 'Enter 6-digit room code',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.normal),
              counterStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceLight.withOpacity(0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            onPressed: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'light');
              AccessibilityService.instance.speak("Cancel selected", force: true);
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              final code = _roomCodeController.text.trim();
              AccessibilityService.instance.triggerHaptic(intensity: 'medium');
              AccessibilityService.instance.speak("Join selected", force: true);
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
      _showSnackbar(res['message'] ?? 'Daily reward claimed!');
    }
  }

  void _showSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> tabs = [
      _buildPlayTab(user),
      RewardsScreen(currentUser: user),
      FriendsScreen(currentUser: user),
      LeaderboardScreen(userId: user.id),
      ProfileScreen(user: user),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(user.avatarUrl),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                // Settings Gear
                Semantics(
                  label: "Settings Hub",
                  hint: "Open accessibility and audio configurations.",
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white, size: 20),
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
      body: tabs[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
                _playSubMenu = 0; // Reset home screen submenu
              });
              _updateActiveScreenContext(index);
            },
            backgroundColor: Colors.transparent,
            selectedItemColor: AppColors.secondary,
            unselectedItemColor: AppColors.textSecondary,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            unselectedLabelStyle: const TextStyle(fontSize: 9),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Play'),
              BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
              BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Leaderboard'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  // Upgraded streamlined gaming visual dashboard with animated backdrop
  Widget _buildPlayTab(UserModel user) {
    Widget content;
    if (_playSubMenu == 1) {
      content = _buildBotSubMenu(user);
    } else if (_playSubMenu == 2) {
      content = _buildLocalSubMenu(user);
    } else if (_playSubMenu == 3) {
      content = _buildOnlineSubMenu(user);
    } else {
      content = _buildMainPlayContent(user);
    }

    return Stack(
      children: [
        _buildAnimatedBackground(),
        Positioned.fill(child: content),
      ],
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        final angle = _bgAnimationController.value * 2 * pi;
        return Stack(
          children: [
            // Blob 1 (Red/Pinkish)
            Positioned(
              top: -50 + 40 * sin(angle),
              left: -50 + 30 * cos(angle),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.red.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Blob 2 (Teal/Green)
            Positioned(
              bottom: 100 + 50 * cos(angle + pi / 2),
              right: -80 + 40 * sin(angle + pi / 2),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.green.withValues(alpha: 0.12),
                ),
              ),
            ),
            // Blob 3 (Yellow/Orange)
            Positioned(
              top: 250 + 60 * sin(angle + pi),
              right: -30 + 30 * cos(angle + pi),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.12),
                ),
              ),
            ),
            // Blob 4 (Purple/Blue)
            Positioned(
              bottom: -50 + 30 * sin(angle - pi / 4),
              left: -40 + 40 * cos(angle - pi / 4),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
            ),
            // Blur Filter
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
                child: Container(color: Colors.transparent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWelcomeHeader(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with online indicator ring
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.secondary, AppColors.primary],
                  ),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(user.avatarUrl),
                ),
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // User welcome area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Rank Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Gold ${user.wins > 10 ? "III" : "I"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70, size: 20),
            onPressed: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'medium');
              AccessibilityService.instance.speak("Settings Hub selected");
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.22),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuickActionButton(
              icon: Icons.add_box,
              label: 'Create Room',
              color: AppColors.primary,
              onTap: () {
                AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                _showOnlinePlayerCountDialog(user);
              },
            ),
            _buildQuickActionButton(
              icon: Icons.vpn_key,
              label: 'Join Room',
              color: AppColors.secondary,
              onTap: () {
                AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                _showJoinRoomDialog();
              },
            ),
            _buildQuickActionButton(
              icon: Icons.people_outline,
              label: 'Friends',
              color: AppColors.blue,
              onTap: () {
                AccessibilityService.instance.triggerHaptic(intensity: 'light');
                setState(() {
                  _currentIndex = 2;
                });
                _updateActiveScreenContext(2);
              },
            ),
            _buildQuickActionButton(
              icon: Icons.person_outline,
              label: 'Profile',
              color: AppColors.red,
              onTap: () {
                AccessibilityService.instance.triggerHaptic(intensity: 'light');
                setState(() {
                  _currentIndex = 4;
                });
                _updateActiveScreenContext(4);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainPlayContent(UserModel user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWelcomeHeader(user),
          const SizedBox(height: 20),
          _buildQuickActionsRow(user),
          const SizedBox(height: 24),
          const Text(
            'SELECT GAME MODE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildPrimaryGridCard(
            title: "BOT ARENA",
            subtitle: "Practice offline vs smart AI bots",
            icon: Icons.smart_toy,
            gradient: const LinearGradient(
              colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            glowColor: const Color(0xFF8E2DE2),
            badgeText: "OFFLINE",
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'medium');
              AccessibilityService.instance.speak("Bot Arena selected. Choose difficulty Easy, Medium, Hard, or Expert.");
              setState(() => _playSubMenu = 1);
            },
          ),
          const SizedBox(height: 14),
          _buildPrimaryGridCard(
            title: "LOCAL ARENA",
            subtitle: "Play offline with local friends",
            icon: Icons.people,
            gradient: const LinearGradient(
              colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            glowColor: const Color(0xFF00C9FF),
            badgeText: "LOCAL",
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'medium');
              AccessibilityService.instance.speak("Local Arena selected. Choose player counts.");
              setState(() => _playSubMenu = 2);
            },
          ),
          const SizedBox(height: 14),
          _buildPrimaryGridCard(
            title: "ONLINE ARENA",
            subtitle: "Battle against players with live voice",
            icon: Icons.public,
            gradient: const LinearGradient(
              colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            glowColor: const Color(0xFFF857A6),
            badgeText: "VOICE CHAT",
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'medium');
              AccessibilityService.instance.speak("Online Arena selected. Host or Join online room.");
              setState(() => _playSubMenu = 3);
            },
          ),
          const SizedBox(height: 14),
          _buildPrimaryGridCard(
            title: "FRIENDS",
            subtitle: "Connect and play with your buddies",
            icon: Icons.handshake,
            gradient: const LinearGradient(
              colors: [Color(0xFFF39C12), Color(0xFFD35400)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            glowColor: const Color(0xFFF39C12),
            badgeText: "SOCIAL",
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'medium');
              AccessibilityService.instance.speak("Friends page selected.");
              setState(() {
                _currentIndex = 2;
              });
              _updateActiveScreenContext(2);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPrimaryGridCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required Color glowColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return AccessibleInkWell(
      label: title,
      hint: subtitle,
      onTap: onTap,
      child: Container(
        height: 105,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: glowColor.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.22),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradient.colors[0].withOpacity(0.9),
                      gradient.colors[1].withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                right: -15,
                bottom: -15,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SUB-MENUS FLOW ---

  // Bot Difficulty Menu
  Widget _buildBotSubMenu(UserModel user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _playSubMenu = 0),
              ),
              const SizedBox(width: 8),
              const Text('BOT DIFFICULTY', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSubChoiceCard(
            title: "🟢 EASY BOT",
            subtitle: "Play standard 1v1 match vs 1 Bot",
            gradient: const LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF1E8449)]),
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Starting Easy Bot Match.");
              _startLocalMatch(user, 1, 1);
            },
          ),
          const SizedBox(height: 12),
          _buildSubChoiceCard(
            title: "🟡 MEDIUM BOTS",
            subtitle: "3-Player match vs 2 smart Bots",
            gradient: const LinearGradient(colors: [Color(0xFFF1C40F), Color(0xFFD4AC0D)]),
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Starting Medium Bots Match.");
              _startLocalMatch(user, 1, 2);
            },
          ),
          const SizedBox(height: 12),
          _buildSubChoiceCard(
            title: "🔴 HARD BOTS",
            subtitle: "4-Player match vs 3 advanced Bots",
            gradient: const LinearGradient(colors: [Color(0xFFFF3366), Color(0xFFC0392B)]),
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Starting Hard Bots Match.");
              _startLocalMatch(user, 1, 3);
            },
          ),
          const SizedBox(height: 12),
          _buildSubChoiceCard(
            title: "🔥 EXPERT BOTS",
            subtitle: "Ultimate board challenge vs 3 Grandmaster Bots",
            gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Starting Expert Bots Match.");
              _startLocalMatch(user, 1, 3);
            },
          ),
        ],
      ),
    );
  }

  // Local Local Arena Menu
  Widget _buildLocalSubMenu(UserModel user) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _playSubMenu = 0),
              ),
              const SizedBox(width: 8),
              const Text('LOCAL ARENA', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSubChoiceCard(
            title: "👤 vs 👤 (2 PLAYERS)",
            subtitle: "Traditional 1v1 local Ludo board",
            gradient: const LinearGradient(colors: [Color(0xFF00c6ff), Color(0xFF0072ff)]),
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Starting two player local match.");
              _startLocalMatch(user, 2, 0);
            },
          ),
          const SizedBox(height: 12),
          _buildSubChoiceCard(
            title: "👤 vs 👤 vs 👤 (3 PLAYERS)",
            subtitle: "Dynamic 3-player local Ludo board",
            gradient: const LinearGradient(colors: [Color(0xFF00F5D4), Color(0xFF00a896)]),
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Starting three player local match.");
              _startLocalMatch(user, 3, 0);
            },
          ),
          const SizedBox(height: 12),
          _buildSubChoiceCard(
            title: "👤 vs 👤 vs 👤 vs 👤 (4 PLAYERS)",
            subtitle: "Full 4-player Ludo local multiplayer",
            gradient: const LinearGradient(colors: [Color(0xFF7F3DFF), Color(0xFFB01DFF)]),
            onTap: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Starting four player local match.");
              _startLocalMatch(user, 4, 0);
            },
          ),
        ],
      ),
    );
  }

  // Online Arena Menu
  Widget _buildOnlineSubMenu(UserModel user) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _playSubMenu = 0),
              ),
              const SizedBox(width: 8),
              const Text('ONLINE ARENA', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          _buildSubChoiceCard(
            title: "🌍 HOST ONLINE ROOM",
            subtitle: "Create a room to play online vs friends",
            gradient: const LinearGradient(colors: [Color(0xFFFF3366), Color(0xFFFF5252)]),
            onTap: () {
              _showOnlinePlayerCountDialog(user);
            },
          ),
          const SizedBox(height: 12),
          _buildSubChoiceCard(
            title: "🎟️ JOIN WITH CODE",
            subtitle: "Enter a 6-digit lobby code to join a match",
            gradient: const LinearGradient(colors: [Color(0xFF2B2844), Color(0xFF1D1B30)]),
            onTap: () {
              _showJoinRoomDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubChoiceCard({
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return AccessibleInkWell(
      label: title,
      hint: subtitle,
      onTap: onTap,
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradient.colors[0].withOpacity(0.85),
                      gradient.colors[1].withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOnlinePlayerCountDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Host Multiplayer Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogOption(context, '2 Players', () {
              Navigator.pop(context);
              _handleCreateRoom(user, 2);
            }),
            const SizedBox(height: 10),
            _buildDialogOption(context, '3 Players', () {
              Navigator.pop(context);
              _handleCreateRoom(user, 3);
            }),
            const SizedBox(height: 10),
            _buildDialogOption(context, '4 Players', () {
              Navigator.pop(context);
              _handleCreateRoom(user, 4);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption(BuildContext dialogContext, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
