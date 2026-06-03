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
        title: const Text('Join Online Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Semantics(
          label: "Enter six-digit room code text field",
          child: TextField(
            controller: _roomCodeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            maxLength: 6,
            onChanged: (text) {
              if (text.isNotEmpty) {
                final lastChar = text.substring(text.length - 1);
                AccessibilityService.instance.speak(lastChar, force: true);
              }
            },
            decoration: const InputDecoration(
              hintText: 'Enter 6-digit room code',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () {
              AccessibilityService.instance.triggerHaptic(intensity: 'light');
              AccessibilityService.instance.speak("Cancel selected", force: true);
              Navigator.pop(context);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
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
      appBar: AppBar(
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border(
            top: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
          ),
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
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Friends'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Rank'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
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

  Widget _buildMainPlayContent(UserModel user) {
    final int totalGames = user.wins + user.losses;
    final double winRate = totalGames > 0 ? (user.wins / totalGames) * 100 : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          // Logo/Header
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFF4500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'LUDO MASTER',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3.0,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'CONQUER THE BOARD IN REAL-TIME',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats Dashboard
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.emoji_events,
                    iconColor: Colors.amber,
                    label: 'Wins',
                    value: '${user.wins}',
                  ),
                ),
                Container(height: 40, width: 1.5, color: Colors.white24),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.percent,
                    iconColor: AppColors.green,
                    label: 'Win Rate',
                    value: '${winRate.toStringAsFixed(1)}%',
                  ),
                ),
                Container(height: 40, width: 1.5, color: Colors.white24),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.videogame_asset,
                    iconColor: AppColors.secondary,
                    label: 'Battles',
                    value: '$totalGames',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'SELECT GAME MODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 16),

          _buildPrimaryGridCard(
            title: "PASS & PLAY",
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
              AccessibilityService.instance.speak("Pass and Play selected. Choose player counts.");
              setState(() => _playSubMenu = 2);
            },
          ),
          const SizedBox(height: 16),

          _buildPrimaryGridCard(
            title: "ONLINE MATCH",
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
              AccessibilityService.instance.speak("Online Match selected. Host or Join online room.");
              setState(() => _playSubMenu = 3);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glowColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradient.colors[0].withValues(alpha: 0.85),
                      gradient.colors[1].withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                    shadows: [
                                      Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
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

  // Local Pass & Play Menu
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
              const Text('PASS & PLAY', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
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

  // Online Match Menu
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
              const Text('ONLINE MULTIPLAYER', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
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
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradient.colors[0].withValues(alpha: 0.8),
                      gradient.colors[1].withValues(alpha: 0.65),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.03),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
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
