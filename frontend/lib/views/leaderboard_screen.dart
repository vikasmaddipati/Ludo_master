import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  final String userId;

  const LeaderboardScreen({
    super.key,
    required this.userId,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  int? _userRank;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top user rank display
                if (_userRank != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E245C), Color(0xFF1D1540)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars, color: AppColors.secondary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YOUR RANKING',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Keep rolling to climb!',
                                  style: TextStyle(fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '#$_userRank',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'GLOBAL HALL OF FAME',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Leaderboard List
                Expanded(
                  child: ListView.builder(
                    itemCount: _leaderboard.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final player = _leaderboard[index];
                      final rank = index + 1;
                      
                      Widget rankWidget;
                      Color itemBgColor = AppColors.surface;
                      BorderSide borderSide = BorderSide.none;

                      if (rank == 1) {
                        rankWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 24);
                        itemBgColor = const Color(0xFF2A2359);
                        borderSide = const BorderSide(color: Colors.amber, width: 1.5);
                      } else if (rank == 2) {
                        rankWidget = Icon(Icons.emoji_events, color: Colors.grey.shade400, size: 22);
                        itemBgColor = const Color(0xFF221D48);
                        borderSide = BorderSide(color: Colors.grey.shade400, width: 1);
                      } else if (rank == 3) {
                        rankWidget = Icon(Icons.emoji_events, color: Colors.brown.shade300, size: 20);
                        itemBgColor = const Color(0xFF1E193E);
                        borderSide = BorderSide(color: Colors.brown.shade300, width: 1);
                      } else {
                        rankWidget = Container(
                          width: 24,
                          alignment: Alignment.center,
                          child: Text(
                            '$rank',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 14),
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: itemBgColor,
                          borderRadius: BorderRadius.circular(18),
                          border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Rank Badge/Number
                            SizedBox(
                              width: 32,
                              child: Center(child: rankWidget),
                            ),
                            const SizedBox(width: 8),
                            
                            // User Info
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.surfaceLight,
                              backgroundImage: player['avatarUrl'] != null && player['avatarUrl'].isNotEmpty
                                  ? NetworkImage(player['avatarUrl'])
                                  : null,
                              child: player['avatarUrl'] == null || player['avatarUrl'].isEmpty
                                  ? Text(
                                      player['name'][0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player['name'] ?? 'Player',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${player['wins'] * 200} pts',
                                    style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),

                            // Total Wins info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0B26).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.workspace_premium, color: AppColors.secondary, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${player['wins']} Wins',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
  }

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  void _fetchLeaderboard() async {
    final res = await ApiService.getLeaderboard(widget.userId);
    if (res != null && mounted) {
      setState(() {
        _leaderboard = res['leaderboard'] ?? [];
        _userRank = res['userRank'];
        _isLoading = false;
      });
    } else if (mounted) {
      // Gorgeous premium offline fallback dataset
      setState(() {
        _leaderboard = [
          {'name': 'DiceCrusher 🔥', 'wins': 142, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=crusher'},
          {'name': 'LudoQueen 👑', 'wins': 118, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=queen'},
          {'name': 'TokenStriker ⚡', 'wins': 95, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=striker'},
          {'name': 'Guest Master', 'wins': 64, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=guest'},
          {'name': 'CasualRoller 🎲', 'wins': 41, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=roller'},
        ];
        _userRank = 12;
        _isLoading = false;
      });
    }
  }
}
