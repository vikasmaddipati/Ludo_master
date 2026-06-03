import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_feedback_service.dart';

class AccessibilityService {
  static final AccessibilityService instance = AccessibilityService._internal();
  AccessibilityService._internal();

  bool _isBlindModeEnabled = false;
  bool _isVoiceGuidedNavigationEnabled = true;
  bool _isButtonAnnouncementsEnabled = true;
  bool _isScreenAnnouncementsEnabled = true;
  bool _isTtsEnabled = true;
  double _speechRate = 0.5;
  double _speechVolume = 1.0;

  bool get isBlindModeEnabled => _isBlindModeEnabled;
  bool get isVoiceGuidedNavigationEnabled => _isVoiceGuidedNavigationEnabled;
  bool get isButtonAnnouncementsEnabled => _isButtonAnnouncementsEnabled;
  bool get isScreenAnnouncementsEnabled => _isScreenAnnouncementsEnabled;
  bool get isTtsEnabled => _isTtsEnabled;
  double get speechRate => _speechRate;
  double get speechVolume => _speechVolume;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBlindModeEnabled = prefs.getBool("accessibility_blind_mode") ?? false;
      _isVoiceGuidedNavigationEnabled = prefs.getBool("accessibility_voice_guided") ?? true;
      _isButtonAnnouncementsEnabled = prefs.getBool("accessibility_button_announcements") ?? true;
      _isScreenAnnouncementsEnabled = prefs.getBool("accessibility_screen_announcements") ?? true;
      _isTtsEnabled = prefs.getBool("accessibility_tts_enabled") ?? true;
      _speechRate = prefs.getDouble("accessibility_speech_rate") ?? 0.5;
      _speechVolume = prefs.getDouble("accessibility_speech_volume") ?? 1.0;

      // Initialize TTS speed and volume
      await VoiceFeedbackService.instance.setSpeechRate(_speechRate);
      await VoiceFeedbackService.instance.setVolume(_speechVolume);
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
      speak("Touch audio feedback enabled.", force: true);
    } else {
      speak("Touch audio feedback disabled.", force: true);
    }
  }

  Future<void> toggleButtonAnnouncements(bool enabled) async {
    _isButtonAnnouncementsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("accessibility_button_announcements", enabled);
    } catch (e) {
      print("Error saving button announcements state: $e");
    }
    if (enabled) {
      speak("Button announcements enabled.", force: true);
    } else {
      speak("Button announcements disabled.", force: true);
    }
  }

  Future<void> toggleScreenAnnouncements(bool enabled) async {
    _isScreenAnnouncementsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("accessibility_screen_announcements", enabled);
    } catch (e) {
      print("Error saving screen announcements state: $e");
    }
    if (enabled) {
      speak("Screen announcements enabled.", force: true);
    } else {
      speak("Screen announcements disabled.", force: true);
    }
  }

  Future<void> toggleTts(bool enabled) async {
    _isTtsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("accessibility_tts_enabled", enabled);
    } catch (e) {
      print("Error saving TTS state: $e");
    }
    if (enabled) {
      speak("Text to speech enabled.", force: true);
    } else {
      await VoiceFeedbackService.instance.stop();
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble("accessibility_speech_rate", rate);
      await VoiceFeedbackService.instance.setSpeechRate(rate);
    } catch (e) {
      print("Error saving speech rate state: $e");
    }
  }

  Future<void> setSpeechVolume(double volume) async {
    _speechVolume = volume;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble("accessibility_speech_volume", volume);
      await VoiceFeedbackService.instance.setVolume(volume);
    } catch (e) {
      print("Error saving speech volume state: $e");
    }
  }

  Future<void> speak(
    String text, {
    bool force = false,
    bool isButton = false,
    bool isScreen = false,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(String)? onError,
    String? turnColor,
    String type = 'generic',
  }) async {
    if (!_isTtsEnabled) return;
    if (isButton && !_isButtonAnnouncementsEnabled) return;
    if (isScreen && !_isScreenAnnouncementsEnabled) return;

    if (force || _isBlindModeEnabled || _isVoiceGuidedNavigationEnabled) {
      await VoiceFeedbackService.instance.speak(
        text,
        type: type,
        turnColor: turnColor,
        onStart: onStart,
        onComplete: onComplete,
        onError: onError,
      );
    }
  }

  Future<void> announceScreen(String screenName) async {
    if (_isScreenAnnouncementsEnabled) {
      await speak("$screenName Screen", force: true, isScreen: true, type: 'turn_changed');
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
    await speak(msg, type: 'generic');
  }

  Future<void> announceGameEvent(String eventName, {String? turnColor, String type = 'generic'}) async {
    await speak(eventName, force: true, turnColor: turnColor, type: type);
  }
}
