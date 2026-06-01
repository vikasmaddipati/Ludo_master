import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/accessibility_service.dart';
import '../services/voice_assistant_service.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../widgets/accessible_interactive.dart';
import 'voice_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AccessibilityService _access = AccessibilityService.instance;
  final VoiceAssistantService _voice = VoiceAssistantService.instance;
  final AuthService _auth = AuthService();

  bool _blindMode = false;
  bool _voiceGuided = true;
  bool _micEnabled = true;
  double _bgMusicVolume = 0.5;

  @override
  void initState() {
    super.initState();
    _blindMode = _access.isBlindModeEnabled;
    _voiceGuided = _access.isVoiceGuidedNavigationEnabled;
    _micEnabled = _voice.isMicEnabled;
    
    // Announce screen transition
    AccessibilityService.instance.announceScreen("Settings");
  }

  void _updateBlindMode(bool val) async {
    await _access.toggleBlindMode(val);
    setState(() {
      _blindMode = val;
    });
  }

  void _updateVoiceGuided(bool val) async {
    await _access.toggleVoiceGuidedNavigation(val);
    setState(() {
      _voiceGuided = val;
    });
  }

  void _updateMicState(bool val) async {
    await _voice.updateMicEnabled(val);
    setState(() {
      _micEnabled = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
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
              // 1. ACCESSIBILITY SETTINGS
              _buildSectionHeader("Accessibility Settings"),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                _buildSwitchRow(
                  icon: Icons.visibility_off,
                  iconColor: Colors.pinkAccent,
                  title: "Blind Assistance Mode",
                  subtitle: "Announces every screen, button label, and game actions aloud.",
                  value: _blindMode,
                  onChanged: _updateBlindMode,
                  semanticHint: "Double tap to toggle blind reader assistance.",
                ),
                const Divider(color: Colors.white10),
                _buildSwitchRow(
                  icon: Icons.record_voice_over,
                  iconColor: AppColors.secondary,
                  title: "Touch Audio Feedback",
                  subtitle: "Speaks aloud screen transition alerts and button selections on touch.",
                  value: _voiceGuided,
                  onChanged: _updateVoiceGuided,
                  semanticHint: "Double tap to toggle touch audio feedback.",
                ),
              ]),
              const SizedBox(height: 28),

              // 2. VOICE CHAT CONFIG
              _buildSectionHeader("Voice Assistant & Speech"),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                _buildSwitchRow(
                  icon: _micEnabled ? Icons.mic : Icons.mic_off,
                  iconColor: _micEnabled ? AppColors.secondary : Colors.grey,
                  title: "Aria Voice Mic",
                  subtitle: "Microphone actively listens hands-free to execute gameplay voice commands.",
                  value: _micEnabled,
                  onChanged: _updateMicState,
                  semanticHint: "Double tap to toggle voice assistant microphone.",
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.tune, color: AppColors.primary),
                  title: const Text("Configure Aria Engine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  subtitle: const Text("Tweak wake words, cooldown rate limit limits, and speech command logs.", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                  onTap: () {
                    AccessibilityService.instance.triggerHaptic(intensity: 'light');
                    AccessibilityService.instance.speak("Opening voice assistant parameters");
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VoiceSettingsScreen()),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 28),

              // 3. AUDIO PREFERENCES
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

              // 4. ACCOUNT INFORMATION
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
              const SizedBox(height: 40),

              // 5. SIGN OUT BUTTON
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

  Widget _buildSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required String semanticHint,
  }) {
    return Semantics(
      label: title,
      hint: semanticHint,
      child: SwitchListTile(
        activeColor: AppColors.secondary,
        secondary: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        value: value,
        onChanged: (val) {
          AccessibilityService.instance.triggerHaptic(intensity: 'medium');
          onChanged(val);
        },
      ),
    );
  }
}
