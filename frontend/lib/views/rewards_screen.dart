import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/accessibility_service.dart';
import '../services/global_voice_manager.dart';
import '../services/voice_command_registry.dart';
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

  List<dynamic> _missions = [];
  List<dynamic> _achievements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _coins = widget.currentUser.coins;
    _fetchRewardsSummary();

    // Register active vocal handlers
    final registry = VoiceCommandRegistry.instance;
    registry.registerHandler("OPEN_REWARDS", (params) async => _handleVoiceAction("OPEN_REWARDS", params));
    registry.registerHandler("SHOW_COINS", (params) async => _handleVoiceAction("SHOW_COINS", params));
    registry.registerHandler("SHOW_XP", (params) async => _handleVoiceAction("SHOW_XP", params));
    registry.registerHandler("SHOW_LEVEL", (params) async => _handleVoiceAction("SHOW_LEVEL", params));
    registry.registerHandler("CLAIM_DAILY_REWARD", (params) async => _handleVoiceAction("CLAIM_DAILY_REWARD", params));
    registry.registerHandler("SHOW_MISSIONS", (params) async => _handleVoiceAction("SHOW_MISSIONS", params));
  }

  void _handleVoiceAction(String action, Map<String, dynamic> params) {
    if (!mounted) return;

    if (action == "OPEN_REWARDS") {
      AccessibilityService.instance.speak("Opening rewards panel.", force: true);
    } else if (action == "SHOW_COINS") {
      AccessibilityService.instance.speak("You have $_coins coins.", force: true);
    } else if (action == "SHOW_XP") {
      AccessibilityService.instance.speak("You have $_xp experience points out of $_xpThreshold for level ${_level + 1}.", force: true);
    } else if (action == "SHOW_LEVEL") {
      AccessibilityService.instance.speak("You are currently level $_level.", force: true);
    } else if (action == "CLAIM_DAILY_REWARD") {
      _claimDailyLogin();
    } else if (action == "SHOW_MISSIONS") {
      _tabController.animateTo(1);
      AccessibilityService.instance.speak("Here is your daily missions board.", force: true);
    }
  }

  Future<void> _fetchRewardsSummary() async {
    setState(() => _isLoading = true);
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
      });
    }
  }

  void _claimDailyLogin() async {
    AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
    final res = await ApiService.claimDailyStreak(widget.currentUser.id, _coins, _streakCount);
    if (res != null && mounted) {
      setState(() {
        _coins = res['coins'] ?? (_coins + 150);
        _streakCount = res['streakCount'] ?? (_streakCount + 1);
        if (res['xp'] != null) _xp = res['xp'];
        if (res['level'] != null) _level = res['level'];
      });
      AccessibilityService.instance.speak(res['message'] ?? "Daily reward claimed successfully!", force: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? "Daily login reward claimed!"),
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
                Tab(icon: Icon(Icons.calendar_today), text: 'Daily Streak'),
                Tab(icon: Icon(Icons.assignment), text: 'Missions'),
                Tab(icon: Icon(Icons.emoji_events), text: 'Trophies'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStreakTab(),
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

  Widget _buildStreakTab() {
    final dailyCoinRewards = [50, 100, 150, 250, 500, 750, 1000];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CONSECUTIVE LOGIN CALENDAR',
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          // Grid Days Calendar
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              final dayNum = index + 1;
              final coinsAmount = dailyCoinRewards[index];
              final isClaimed = dayNum <= _streakCount;
              final isCurrent = dayNum == _streakCount + 1;
              final isLocked = dayNum > _streakCount + 1;

              Color cardBg = AppColors.surface;
              Color borderCol = isCurrent ? AppColors.secondary : AppColors.surfaceLight;

              return Semantics(
                label: "Day $dayNum consecutive login reward of $coinsAmount coins. Status: ${isClaimed ? 'Claimed' : isCurrent ? 'Available to claim' : 'Locked'}.",
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderCol, width: isCurrent ? 2 : 1),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              blurRadius: 10,
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'DAY $dayNum',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isCurrent ? AppColors.secondary : AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Icon(
                        dayNum == 7 ? Icons.card_giftcard : Icons.monetization_on,
                        color: isClaimed ? Colors.grey : isCurrent ? Colors.amber : Colors.amber.withOpacity(0.4),
                        size: dayNum == 7 ? 28 : 22,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+$coinsAmount',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isClaimed ? Colors.grey : Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // Claim button
          AccessibleButton(
            label: 'CLAIM TODAY\'S REWARD',
            hint: 'Claim login reward for Day ${_streakCount + 1}',
            onTap: _claimDailyLogin,
            isFullWidth: true,
          ),
        ],
      ),
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
        final current = a['currentValue'] ?? 0;
        final target = a['targetValue'] ?? 1;
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
    final registry = VoiceCommandRegistry.instance;
    registry.unregisterHandler("OPEN_REWARDS");
    registry.unregisterHandler("SHOW_COINS");
    registry.unregisterHandler("SHOW_XP");
    registry.unregisterHandler("SHOW_LEVEL");
    registry.unregisterHandler("CLAIM_DAILY_REWARD");
    registry.unregisterHandler("SHOW_MISSIONS");

    _tabController.dispose();
    super.dispose();
  }
}
