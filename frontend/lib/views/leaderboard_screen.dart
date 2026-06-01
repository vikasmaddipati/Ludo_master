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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
    }

    if (_leaderboard.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 80, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'No Winners Yet!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Be the first player to win a match and claim the top of the leaderboard! 🏆',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final showPodium = _leaderboard.length >= 3;

    return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top user rank display
                if (_userRank != null)
                  Semantics(
                    label: "Your Ranking is Number $_userRank",
                    child: Container(
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
                                  color: AppColors.secondary.withValues(alpha: 0.15),
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
                  ),

                // Stunning 3D Podium for Top 3 Players
                if (showPodium) _buildPodium(),

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
                    itemCount: showPodium 
                        ? (_leaderboard.length > 3 ? _leaderboard.length - 3 : 0) 
                        : _leaderboard.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final actualIndex = showPodium ? index + 3 : index;
                      final player = _leaderboard[actualIndex];
                      final rank = actualIndex + 1;
                      
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

                      return Semantics(
                        label: "Rank $rank: ${player['name'] ?? 'Player'}. Points: ${player['wins'] * 200}. Total Wins: ${player['wins']}.",
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: itemBgColor,
                            borderRadius: BorderRadius.circular(18),
                            border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
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
                                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),

                            // Total Wins info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0B26).withValues(alpha: 0.5),
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
                      ),);
                    },
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildPodium() {
    final first = _leaderboard[0];
    final second = _leaderboard[1];
    final third = _leaderboard.length >= 3 ? _leaderboard[2] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceLight, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          _buildPodiumSpot(second, 2, 55, Colors.grey.shade400, '🥈'),
          
          // 1st Place
          _buildPodiumSpot(first, 1, 75, Colors.amber, '👑'),

          // 3rd Place
          if (third != null)
            _buildPodiumSpot(third, 3, 45, Colors.brown.shade300, '🥉'),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(dynamic player, int rank, double height, Color color, String emblem) {
    final winsCount = player['wins'] ?? 0;
    return Semantics(
      label: "Podium rank $rank: ${player['name'] ?? 'Player'} with $winsCount Wins.",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: rank == 1 ? 3 : 2),
                boxShadow: [
                  if (rank == 1)
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: CircleAvatar(
                radius: rank == 1 ? 28 : 22,
                backgroundImage: player['avatarUrl'] != null && player['avatarUrl'].isNotEmpty
                    ? NetworkImage(player['avatarUrl'])
                    : null,
                child: player['avatarUrl'] == null || player['avatarUrl'].isEmpty
                    ? Text(
                        player['name'][0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      )
                    : null,
              ),
            ),
            Positioned(
              top: rank == 1 ? -16 : -12,
              child: Text(
                emblem,
                style: TextStyle(fontSize: rank == 1 ? 22 : 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 75,
          child: Text(
            player['name'] ?? 'Player',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
          ),
        ),
        Text(
          '${player['wins']} Wins',
          style: const TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: 65,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: rank == 1 ? 20 : 16, color: color),
            ),
          ),
        ),
      ],
    ),);
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
      setState(() {
        _leaderboard = [];
        _userRank = null;
        _isLoading = false;
      });
    }
  }
}
