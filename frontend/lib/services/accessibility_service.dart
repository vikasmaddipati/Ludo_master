import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_feedback_service.dart';

class AccessibilityService {
  static final AccessibilityService instance = AccessibilityService._internal();
  AccessibilityService._internal();

  bool _isBlindModeEnabled = false;
  bool _isVoiceGuidedNavigationEnabled = true;
  double _speechRate = 0.5;

  bool get isBlindModeEnabled => _isBlindModeEnabled;
  bool get isVoiceGuidedNavigationEnabled => _isVoiceGuidedNavigationEnabled;
  double get speechRate => _speechRate;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBlindModeEnabled = prefs.getBool("accessibility_blind_mode") ?? false;
      _isVoiceGuidedNavigationEnabled = prefs.getBool("accessibility_voice_guided") ?? true;
      _speechRate = prefs.getDouble("accessibility_speech_rate") ?? 0.5;
    } catch (e) {
      print("AccessibilityService init error: $e");
    }
  }

  Future<void> toggleBlindMode(bool enabled) async {
    _isBlindModeEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("accessibility_blind_mode", enabled);
    } catch (e) {
      print("Error saving blind mode state: $e");
    }
    if (enabled) {
      speak("Blind assistance mode enabled.", force: true);
      triggerHaptic(intensity: 'heavy');
    } else {
      speak("Blind assistance mode disabled.", force: true);
    }
  }

  Future<void> toggleVoiceGuidedNavigation(bool enabled) async {
    _isVoiceGuidedNavigationEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("accessibility_voice_guided", enabled);
    } catch (e) {
      print("Error saving voice guided state: $e");
    }
    if (enabled) {
      speak("Voice guided navigation enabled.", force: true);
    } else {
      speak("Voice guided navigation disabled.", force: true);
    }
  }

  Future<void> speak(String text, {bool force = false}) async {
    if (force || _isBlindModeEnabled || _isVoiceGuidedNavigationEnabled) {
      await VoiceFeedbackService.instance.speak(text);
    }
  }

  Future<void> announceScreen(String screenName) async {
    if (_isBlindModeEnabled) {
      await speak("$screenName Screen", force: true);
    }
  }

  Future<void> triggerHaptic({String intensity = 'light'}) async {
    try {
      if (intensity == 'heavy') {
        await HapticFeedback.vibrate();
      } else if (intensity == 'medium') {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      print("Haptic feedback error: $e");
    }
  }

  Future<void> announceAction(String actionName, {String detail = ''}) async {
    String msg = actionName;
    if (detail.isNotEmpty) {
      msg = "$actionName $detail";
    }
    await speak(msg);
  }

  Future<void> announceGameEvent(String eventName) async {
    await speak(eventName, force: true);
  }
}
