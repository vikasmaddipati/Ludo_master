import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/accessibility_service.dart';
import '../widgets/accessible_interactive.dart';

class RewardsScreen extends StatefulWidget {
  final UserModel currentUser;

  const RewardsScreen({super.key, required this.currentUser});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Reward Data State
  int _coins = 1000;
  int _xp = 0;
  int _level = 1;
  int _streakCount = 0;
  int _xpThreshold = 100;

  bool _claimedToday = false;
  DateTime? _lastClaimedDate;
  Timer? _countdownTimer;
  String _timeRemainingStr = "";

  List<dynamic> _missions = [];
  List<dynamic> _achievements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _coins = widget.currentUser.coins;
    _fetchRewardsSummary();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemainingStr = _calculateTimeUntilMidnight();
        });
      }
    });
  }

  String _calculateTimeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);

    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    return "${hours}h ${minutes}m ${seconds}s";
  }

  Future<void> _fetchRewardsSummary() async {
    setState(() => _isLoading = true);
    
    // Check local SharedPreferences daily claim state first (for guest users and offline resilience)
    final prefs = await SharedPreferences.getInstance();
    final lastClaimStr = prefs.getString('guest_last_daily_claim_${widget.currentUser.id}');
    
    final res = await ApiService.getRewardsSummary(widget.currentUser.id);
    if (res != null && mounted) {
      setState(() {
        _coins = res['coins'] ?? widget.currentUser.coins;
        _xp = res['xp'] ?? 0;
        _level = res['level'] ?? 1;
        _streakCount = res['streakCount'] ?? 0;
        _xpThreshold = res['xpThreshold'] ?? 100;
        _missions = res['missions'] ?? [];
        _achievements = res['achievements'] ?? [];
        
        // Use backend or fall back to local Prefs for Sandbox/Local match robustness
        _claimedToday = res['claimedToday'] ?? false;
        if (res['lastClaimedDate'] != null) {
          _lastClaimedDate = DateTime.parse(res['lastClaimedDate']);
        }
        
        // If local SharedPreferences claims it was claimed today, enforce it locally too
        if (lastClaimStr != null) {
          final localLastClaim = DateTime.parse(lastClaimStr);
          final now = DateTime.now();
          if (localLastClaim.year == now.year &&
              localLastClaim.month == now.month &&
              localLastClaim.day == now.day) {
            _claimedToday = true;
            _lastClaimedDate = localLastClaim;
          }
        }
        
        _isLoading = false;
      });
    } else {
      // Offline fallback seeding
      setState(() {
        _isLoading = false;
        _missions = [
          { '_id': 'm1', 'title': 'Roll Dice 20 Times', 'currentCount': 12, 'targetCount': 20, 'rewardCoins': 100, 'rewardXp': 20, 'isWeekly': false, 'isClaimed': false },
          { '_id': 'm2', 'title': 'Send 5 Chat Messages', 'currentCount': 2, 'targetCount': 5, 'rewardCoins': 50, 'rewardXp': 10, 'isWeekly': false, 'isClaimed': false },
          { '_id': 'm3', 'title': 'Play 3 Matches', 'currentCount': 3, 'targetCount': 3, 'rewardCoins': 150, 'rewardXp': 30, 'isWeekly': false, 'isClaimed': false }
        ];
        _achievements = [
          { '_id': 'a1', 'title': 'First Steps', 'description': 'Play your first match.', 'currentValue': 1, 'targetValue': 1, 'rewardCoins': 100, 'rewardXp': 20, 'isUnlocked': true, 'isClaimed': false },
          { '_id': 'a2', 'title': 'Victor!', 'description': 'Claim your first win.', 'currentValue': 0, 'targetValue': 1, 'rewardCoins': 250, 'rewardXp': 50, 'isUnlocked': false, 'isClaimed': false }
        ];
        
        if (lastClaimStr != null) {
          final localLastClaim = DateTime.parse(lastClaimStr);
          final now = DateTime.now();
          _claimedToday = localLastClaim.year == now.year &&
                          localLastClaim.month == now.month &&
                          localLastClaim.day == now.day;
          _lastClaimedDate = localLastClaim;
        } else {
          _claimedToday = false;
          _lastClaimedDate = null;
        }
      });
    }
  }

  void _claimDailyLogin() async {
    if (_claimedToday) return;

    AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
    final res = await ApiService.claimDailyStreak(widget.currentUser.id, _coins, _streakCount);
    if (res != null && mounted) {
      setState(() {
        _coins = res['coins'] ?? (_coins + 100);
        _claimedToday = true;
        _lastClaimedDate = DateTime.now();
        if (res['xp'] != null) _xp = res['xp'];
        if (res['level'] != null) _level = res['level'];
      });

      // Persist the claim locally for guest/sandbox users
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_last_daily_claim_${widget.currentUser.id}', DateTime.now().toIso8601String());
      widget.currentUser.coins = _coins; // update on user model

      AccessibilityService.instance.speak("Daily reward of 100 coins claimed successfully!", force: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Daily reward of 100 coins claimed!"),
          backgroundColor: AppColors.green,
        ),
      );
      if (res['levelUp'] == true) {
        AccessibilityService.instance.speak("Level Up! You reached level $_level!", force: true);
      }
    }
  }

  void _claimMission(dynamic mission) async {
    AccessibilityService.instance.triggerHaptic(intensity: 'medium');
    final res = await ApiService.claimMissionReward(widget.currentUser.id, mission['_id']);
    if (res != null && res['success'] == true && mounted) {
      setState(() {
        _coins = res['coins'] ?? (_coins + mission['rewardCoins']);
        _xp = res['xp'] ?? _xp;
        _level = res['level'] ?? _level;
        mission['isClaimed'] = true;
      });
      AccessibilityService.instance.speak("Claimed ${mission['rewardCoins']} coins and ${mission['rewardXp']} XP for completing ${mission['title']}.", force: true);
    }
  }

  void _claimAchievement(dynamic achievement) async {
    AccessibilityService.instance.triggerHaptic(intensity: 'medium');
    final res = await ApiService.claimAchievementReward(widget.currentUser.id, achievement['_id']);
    if (res != null && res['success'] == true && mounted) {
      setState(() {
        _coins = res['coins'] ?? (_coins + achievement['rewardCoins']);
        _xp = res['xp'] ?? _xp;
        _level = res['level'] ?? _level;
        achievement['isClaimed'] = true;
      });
      AccessibilityService.instance.speak("Claimed ${achievement['rewardCoins']} coins and ${achievement['rewardXp']} XP for achievement ${achievement['title']}.", force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.secondary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Elegant Header containing user level & XP progressions
          _buildProgressionHeader(),
          
          // Custom Gaming Style Tabs
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.secondary,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
              tabs: const [
                Tab(icon: Icon(Icons.calendar_today), text: 'Daily Reward'),
                Tab(icon: Icon(Icons.assignment), text: 'Missions'),
                Tab(icon: Icon(Icons.emoji_events), text: 'Trophies'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyRewardTab(),
                _buildMissionsTab(),
                _buildAchievementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionHeader() {
    final progress = _xp / _xpThreshold;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Level Badge
              Semantics(
                label: "Player Level $_level",
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'LVL $_level',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXPERIENCE PROGRESS', style: TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text('$_xp / $_xpThreshold XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Coins display
              Semantics(
                label: "$_coins Coins",
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '$_coins',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          // Glow Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 10,
              width: double.infinity,
              color: AppColors.surfaceLight,
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.05, 1.0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRewardTab() {
    final String lastClaimText = _lastClaimedDate != null
        ? "${_lastClaimedDate!.day} ${_getMonthName(_lastClaimedDate!.month)} ${_lastClaimedDate!.year} at ${_lastClaimedDate!.hour.toString().padLeft(2, '0')}:${_lastClaimedDate!.minute.toString().padLeft(2, '0')}"
        : "Never";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Elegant Header Title
          const Text(
            'DAILY COIN BONUS',
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),

          // High Premium reward card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E2DE2).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.monetization_on, color: Colors.amber, size: 50),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Daily Reward',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                const Text(
                  '100 Coins',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: Colors.white, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _claimedToday ? 'Claimed Today' : 'Available to Claim',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _claimedToday ? Colors.white54 : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reward Status Stats Grid
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.surfaceLight, width: 1.5),
            ),
            child: Column(
              children: [
                _buildRewardDetailRow(
                  icon: Icons.account_balance_wallet,
                  label: "Current Balance",
                  value: "$_coins Coins",
                  valueColor: Colors.amber,
                ),
                const Divider(color: AppColors.surfaceLight, height: 24),
                _buildRewardDetailRow(
                  icon: Icons.history,
                  label: "Last Claimed Date",
                  value: lastClaimText,
                  valueColor: Colors.white,
                ),
                const Divider(color: AppColors.surfaceLight, height: 24),
                _buildRewardDetailRow(
                  icon: Icons.timer,
                  label: "Next Claim In",
                  value: _claimedToday ? _timeRemainingStr : "Available Now",
                  valueColor: _claimedToday ? AppColors.secondary : AppColors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Modern Claim Button
          AccessibleButton(
            label: _claimedToday ? 'CLAIMED TODAY' : 'CLAIM 100 COINS',
            hint: _claimedToday ? 'Daily reward already claimed today' : 'Claim daily login coins',
            onTap: _claimedToday ? null : _claimDailyLogin,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  Widget _buildRewardDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMissionsTab() {
    if (_missions.isEmpty) {
      return const Center(child: Text('No active missions today.', style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _missions.length,
      itemBuilder: (context, index) {
        final m = _missions[index];
        final isClaimed = m['isClaimed'] == true;
        final current = m['currentCount'] ?? 0;
        final target = m['targetCount'] ?? 1;
        final canClaim = current >= target && !isClaimed;
        final progress = current / target;

        return Semantics(
          label: "Mission: ${m['title']}. Progress is $current out of $target. Reward is ${m['rewardCoins']} coins and ${m['rewardXp']} XP. Status: ${isClaimed ? 'Claimed' : canClaim ? 'Ready to claim' : 'In progress'}.",
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: canClaim ? AppColors.secondary.withValues(alpha: 0.5) : AppColors.surfaceLight, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reward: ${m['rewardCoins']} Coins | ${m['rewardXp']} XP',
                        style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Claim Button
                isClaimed
                    ? const Icon(Icons.check_circle, color: Colors.grey, size: 28)
                    : AccessibleButton(
                        label: 'Claim',
                        hint: 'Claim mission rewards',
                        onTap: canClaim ? () => _claimMission(m) : null,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementsTab() {
    if (_achievements.isEmpty) {
      return const Center(child: Text('No trophies configured.', style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _achievements.length,
      itemBuilder: (context, index) {
        final a = _achievements[index];
        final isClaimed = a['isClaimed'] == true;
        final isUnlocked = a['isUnlocked'] == true;
        final canClaim = isUnlocked && !isClaimed;

        return Semantics(
          label: "Trophy Achievement: ${a['title']}. ${a['description']}. Status: ${isClaimed ? 'Claimed' : canClaim ? 'Unlocked and ready to claim' : 'Locked'}.",
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: canClaim ? Colors.amber.withValues(alpha: 0.5) : AppColors.surfaceLight, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUnlocked ? Colors.amber.withValues(alpha: 0.15) : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_events, color: isUnlocked ? Colors.amber : Colors.grey, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a['description'],
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Trophy: ${a['rewardCoins']} Coins | ${a['rewardXp']} XP',
                        style: TextStyle(color: isUnlocked ? Colors.amber : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                isClaimed
                    ? const Icon(Icons.check_circle, color: Colors.grey, size: 28)
                    : AccessibleButton(
                        label: 'Claim',
                        hint: 'Claim unlocked trophy reward',
                        onTap: canClaim ? () => _claimAchievement(a) : null,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
