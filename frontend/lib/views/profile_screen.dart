import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;
  final AuthService _auth = AuthService();

  ProfileScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final totalMatches = user.wins + user.losses;
    final winPercentage = totalMatches > 0 ? (user.wins / totalMatches * 100).toStringAsFixed(1) : '0';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Details Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.surfaceLight,
                  backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                  child: user.avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Statistics Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard('Total Matches', '$totalMatches', Icons.sports_esports, AppColors.primary),
                _buildStatCard('Win Percentage', '$winPercentage%', Icons.percent, AppColors.secondary),
                _buildStatCard('Matches Won', '${user.wins}', Icons.emoji_events, Colors.amber),
                _buildStatCard('Matches Lost', '${user.losses}', Icons.trending_down, AppColors.red),
              ],
            ),
          ),

          // Log Out Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.red.withOpacity(0.15),
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              await _auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
