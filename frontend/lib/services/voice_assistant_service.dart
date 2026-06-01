import 'package:flutter/material.dart';
import 'voice_recognition_service.dart';
import 'voice_feedback_service.dart';
import 'voice_action_router.dart';
import 'global_voice_manager.dart';

enum AssistantState { idle, listening, thinking, speaking }

class VoiceAssistantService {
  static final VoiceAssistantService instance = VoiceAssistantService._internal();
  VoiceAssistantService._internal();

  bool get isContinuousListeningEnabled => !GlobalVoiceManager.instance.isWakeWordMode;
  bool get requireWakeWord => GlobalVoiceManager.instance.isWakeWordMode;
  double get rateLimitSeconds => GlobalVoiceManager.instance.cooldownSeconds;
  bool get isMicEnabled => VoiceRecognitionService.instance.isEnabled;

  Future<void> updateMicEnabled(bool enabled) async {
    await VoiceRecognitionService.instance.setEnabled(enabled);
  }

  AssistantState get state {
    switch (VoiceRecognitionService.instance.state) {
      case VoiceState.listening:
        return AssistantState.listening;
      case VoiceState.thinking:
      case VoiceState.executing:
        return AssistantState.thinking;
      case VoiceState.speaking:
        return AssistantState.speaking;
      case VoiceState.offline:
      default:
        return AssistantState.idle;
    }
  }

  // Backwards compatibility listeners
  void addActionListener(Function(String action, Map<String, dynamic> params) listener) {
    VoiceActionRouter.instance.registerListener(listener);
  }

  void removeActionListener(Function(String action, Map<String, dynamic> params) listener) {
    VoiceActionRouter.instance.unregisterListener(listener);
  }

  Future<void> initialize() async {
    await GlobalVoiceManager.instance.initialize();
  }

  Future<void> loadSettings() async {
    await GlobalVoiceManager.instance.loadSettings();
  }

  Future<void> updateWakeWordMode(bool require) async {
    await GlobalVoiceManager.instance.updateWakeWordMode(require);
  }

  Future<void> updateContinuousListeningMode(bool enable, [BuildContext? context]) async {
    // In our new always-listening model, we just toggle Wake Word Mode vs Direct Command Mode
    // continuous listening is always on.
    await GlobalVoiceManager.instance.updateWakeWordMode(!enable);
  }

  Future<void> updateRateLimit(double val) async {
    await GlobalVoiceManager.instance.updateCooldownSeconds(val);
  }

  Future<void> speak(String text, [BuildContext? context]) async {
    await VoiceFeedbackService.instance.speak(text);
  }

  Future<void> stopSpeaking() async {
    await VoiceFeedbackService.instance.stop();
  }

  Future<void> startContinuousListening([BuildContext? context]) async {
    await GlobalVoiceManager.instance.startAlwaysListening();
  }

  void stopContinuousListening() {
    GlobalVoiceManager.instance.stopAlwaysListening();
  }

  Future<void> startListening() async {
    await VoiceRecognitionService.instance.startListening();
  }

  Future<void> stopListening() async {
    await VoiceRecognitionService.instance.stopListening();
  }
}
