import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'voice_recognition_service.dart';

class VoiceFeedbackService {
  static final VoiceFeedbackService instance = VoiceFeedbackService._internal();
  VoiceFeedbackService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isTtsInitialized = false;

  Function(String text)? onOverlayMessage;

  Future<void> initialize() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.1);
      await _tts.setSpeechRate(0.45);

      _tts.setStartHandler(() {
        VoiceRecognitionService.instance.updateState(VoiceState.speaking);
      });

      _tts.setCompletionHandler(() {
        VoiceRecognitionService.instance.updateState(VoiceState.offline);
      });

      _tts.setErrorHandler((msg) {
        debugPrint("Voice TTS error: $msg");
        VoiceRecognitionService.instance.updateState(VoiceState.offline);
      });

      _isTtsInitialized = true;
    } catch (e) {
      debugPrint("TTS init error: $e");
    }
  }

  Future<void> speak(String text) async {
    await initialize();
    onOverlayMessage?.call(text);
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint("TTS speak exception: $e");
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
