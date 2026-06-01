import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';

enum VoiceState { listening, thinking, executing, speaking, offline }

class VoiceRecognitionService {
  static final VoiceRecognitionService instance = VoiceRecognitionService._internal();
  VoiceRecognitionService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  VoiceState _state = VoiceState.offline;
  bool _isListening = false;
  bool _isEnabled = true;
  
  // Callbacks
  Function(VoiceState state)? onStateChanged;
  Function(String text)? onTextTranscribed;
  Function(String error)? onErrorOccurred;

  VoiceState get state => _state;
  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;

  Future<void> updateState(VoiceState newState) async {
    _state = newState;
    onStateChanged?.call(newState);
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("aria_mic_enabled", enabled);
    debugPrint("VoiceRecognitionService: Mic enabled state set to: $enabled");
    if (!enabled) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  Future<bool> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool("aria_mic_enabled") ?? true;
    } catch (e) {
      debugPrint("Error loading mic enabled state: $e");
    }

    if (_isInitialized) return true;
    try {
      await updateState(VoiceState.offline);
      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Voice STT Status: $status');
          if (status == 'listening') {
            updateState(VoiceState.listening);
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
            if (_state == VoiceState.listening) {
              updateState(VoiceState.offline);
            }
            // Auto restart listening loop if we should be active
            _restartListeningIfNeeded();
          }
        },
        onError: (errorNotification) {
          debugPrint('Voice STT Error: ${errorNotification.errorMsg}');
          onErrorOccurred?.call(errorNotification.errorMsg);
          _isListening = false;
          updateState(VoiceState.offline);
          _restartListeningIfNeeded();
        },
      );
      _isInitialized = available;
      if (available) {
        await updateState(VoiceState.offline);
      }
      return available;
    } catch (e) {
      debugPrint('Voice STT Init Exception: $e');
      _isInitialized = false;
      await updateState(VoiceState.offline);
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isEnabled) {
      debugPrint("STT is disabled. Skipping startListening.");
      return;
    }

    bool hasInit = await initialize();
    if (!hasInit) {
      debugPrint("STT initialization failed, cannot start listening.");
      return;
    }

    if (_isListening) return;

    try {
      _isListening = true;
      await updateState(VoiceState.listening);
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          if (text.isNotEmpty) {
            onTextTranscribed?.call(text);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      debugPrint("Error in startListening: $e");
      _isListening = false;
      await updateState(VoiceState.offline);
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _speech.stop();
    await updateState(VoiceState.offline);
  }

  void _restartListeningIfNeeded() {
    if (!_isEnabled) return;
    // Small delay to prevent tight loop in case of fast failure
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!_isEnabled) return;
      startListening();
    });
  }
}
