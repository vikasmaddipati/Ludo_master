import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/accessibility_service.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  final AccessibilityService _access = AccessibilityService.instance;

  bool _accessibilityMode = false;
  bool _buttonAnnouncements = true;
  bool _screenAnnouncements = true;
  bool _ttsEnabled = true;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _accessibilityMode = _access.isBlindModeEnabled;
      _buttonAnnouncements = _access.isButtonAnnouncementsEnabled;
      _screenAnnouncements = _access.isScreenAnnouncementsEnabled;
      _ttsEnabled = _access.isTtsEnabled;
      _speechRate = _access.speechRate;
      _speechVolume = _access.speechVolume;
    });
    // Announce opening screen
    _access.announceScreen("Accessibility Settings");
  }

  void _updateAccessibilityMode(bool val) async {
    await _access.toggleBlindMode(val);
    setState(() {
      _accessibilityMode = val;
    });
  }

  void _updateButtonAnnouncements(bool val) async {
    await _access.toggleButtonAnnouncements(val);
    setState(() {
      _buttonAnnouncements = val;
    });
  }

  void _updateScreenAnnouncements(bool val) async {
    await _access.toggleScreenAnnouncements(val);
    setState(() {
      _screenAnnouncements = val;
    });
  }

  void _updateTts(bool val) async {
    await _access.toggleTts(val);
    setState(() {
      _ttsEnabled = val;
    });
  }

  void _updateSpeechRate(double val) async {
    await _access.setSpeechRate(val);
    setState(() {
      _speechRate = val;
    });
  }

  void _updateSpeechVolume(double val) async {
    await _access.setSpeechVolume(val);
    setState(() {
      _speechVolume = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Accessibility Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _access.triggerHaptic(intensity: 'light');
            _access.speak("Back to previous screen");
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
              // 1. SYSTEM MODES SECTION
              _buildSectionHeader("Audible Assistance"),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                _buildSwitchRow(
                  icon: Icons.accessibility_new,
                  iconColor: Colors.pinkAccent,
                  title: "Accessibility Mode",
                  subtitle: "Announces screen transitions, button labels, and game actions aloud.",
                  value: _accessibilityMode,
                  onChanged: _updateAccessibilityMode,
                  semanticHint: "Double tap to toggle main accessibility mode.",
                ),
                const Divider(color: Colors.white10),
                _buildSwitchRow(
                  icon: Icons.record_voice_over,
                  iconColor: Colors.orangeAccent,
                  title: "Text-To-Speech",
                  subtitle: "Audible speech engine for visually impaired screen guidance.",
                  value: _ttsEnabled,
                  onChanged: _updateTts,
                  semanticHint: "Double tap to toggle text to speech completely.",
                ),
              ]),
              const SizedBox(height: 28),

              // 2. FEEDBACK VERBOSITY SECTION
              _buildSectionHeader("Feedback Verbosity"),
              const SizedBox(height: 12),
              _buildSettingsGroup([
                _buildSwitchRow(
                  icon: Icons.gesture,
                  iconColor: AppColors.secondary,
                  title: "Button Announcements",
                  subtitle: "Speaks aloud selected options and buttons upon user tap.",
                  value: _buttonAnnouncements,
                  onChanged: _updateButtonAnnouncements,
                  semanticHint: "Double tap to toggle button name announcements.",
                ),
                const Divider(color: Colors.white10),
                _buildSwitchRow(
                  icon: Icons.layers,
                  iconColor: AppColors.primary,
                  title: "Screen Announcements",
                  subtitle: "Announces name alerts immediately when new screens are opened.",
                  value: _screenAnnouncements,
                  onChanged: _updateScreenAnnouncements,
                  semanticHint: "Double tap to toggle screen announcements.",
                ),
              ]),
              const SizedBox(height: 28),

              // 3. SPEECH CUSTOMIZATION
              _buildSectionHeader("Speech Customization"),
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
                    // Speech Speed Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Speech Speed", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                        Text("${_speechRate.toStringAsFixed(1)}x", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text("Adjust the speed rate of the accessibility voice engine.", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 12),
                    Slider(
                      activeColor: AppColors.secondary,
                      inactiveColor: AppColors.surfaceLight,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      value: _speechRate,
                      onChanged: _ttsEnabled ? _updateSpeechRate : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Speech Volume Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Speech Volume", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                        Text("${(_speechVolume * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text("Adjust the volume levels of structural screen announcements.", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 12),
                    Slider(
                      activeColor: Colors.amber,
                      inactiveColor: AppColors.surfaceLight,
                      min: 0.0,
                      max: 1.0,
                      value: _speechVolume,
                      onChanged: _ttsEnabled ? _updateSpeechVolume : null,
                    ),
                  ],
                ),
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
          _access.triggerHaptic(intensity: 'medium');
          onChanged(val);
        },
      ),
    );
  }
}
