import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/accessibility_service.dart';
import '../services/auth_service.dart';
import '../widgets/accessible_interactive.dart';
import 'accessibility_settings_screen.dart';
import 'diagnostics_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  double _bgMusicVolume = 0.5;
  int _developerTapCount = 0;

  @override
  void initState() {
    super.initState();
    // Announce screen transition
    AccessibilityService.instance.announceScreen("Settings");
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            _developerTapCount++;
            if (_developerTapCount >= 5) {
              _developerTapCount = 0;
              AccessibilityService.instance.triggerHaptic(intensity: 'heavy');
              AccessibilityService.instance.speak("Developer diagnostics unlocked");
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DiagnosticsScreen()),
              );
            }
          },
          child: const Text('Settings Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            AccessibilityService.instance.triggerHaptic(intensity: 'light');
            AccessibilityService.instance.speak("Back to previous screen");
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ACCESSIBILITY HUB
              _buildSectionHeader("Accessibility Options"),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                ListTile(
                  leading: const Icon(Icons.accessibility_new, color: Colors.pinkAccent),
                  title: const Text("Accessibility Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  subtitle: const Text("Configure screen announcements, text-to-speech, button feedback, and speech engine parameters.", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  onTap: () {
                    AccessibilityService.instance.triggerHaptic(intensity: 'light');
                    AccessibilityService.instance.speak("Opening accessibility settings");
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AccessibilitySettingsScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 28),

              // 2. AUDIO PREFERENCES
              _buildSectionHeader("Audio Preferences"),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Ludo Background Loop", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                        Text("${(_bgMusicVolume * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      activeColor: Colors.amber,
                      inactiveColor: AppColors.surfaceLight,
                      min: 0.0,
                      max: 1.0,
                      value: _bgMusicVolume,
                      onChanged: (val) {
                        setState(() {
                          _bgMusicVolume = val;
                        });
                        // Music volume adjusting
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 3. ACCOUNT INFORMATION
              _buildSectionHeader("Account Details"),
              const SizedBox(height: 12),
              if (user != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10, width: 1),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: NetworkImage(user.avatarUrl),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                             Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                           ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
 
              // 4. DEVELOPER DIAGNOSTICS
              _buildSectionHeader("Developer Diagnostics"),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                ListTile(
                  leading: const Icon(Icons.developer_board, color: Colors.amber),
                  title: const Text("Network & Socket Diagnostics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  subtitle: const Text("Monitor Socket latency, LiveKit server sync, packet statistics, and configure Server IP overrides.", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  onTap: () {
                    AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DiagnosticsScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 40),

              // 4. SIGN OUT BUTTON
              AccessibleButton(
                label: "Sign Out Player",
                hint: "Log out from the Ludo Master multiplayer account.",
                onTap: () async {
                  await _auth.signOut();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
