import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class SpeechItem {
  final String text;
  final String type; // 'dice_rolled', 'token_moved', 'turn_changed', 'game_over', 'generic'
  final String? turnColor;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final Function(String)? onError;

  SpeechItem(this.text, {required this.type, this.turnColor, this.onStart, this.onComplete, this.onError});
}

class VoiceFeedbackService {
  static final VoiceFeedbackService instance = VoiceFeedbackService._internal();
  VoiceFeedbackService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isTtsInitialized = false;
  final List<SpeechItem> _speechQueue = [];
  bool _isSpeaking = false;
  String _currentGameTurn = '';
  Timer? _speechTimeoutTimer;

  Function(String text)? onOverlayMessage;

  Future<void> initialize() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.1);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.voiceChat,
        );
      }

      _isTtsInitialized = true;
    } catch (e) {
      debugPrint("TTS init error: $e");
    }
  }

  void updateCurrentGameTurn(String turnColor) {
    _currentGameTurn = turnColor.toLowerCase();
    print('[TTS] Current game state: turn=$_currentGameTurn');
    _catchUpQueue();
  }

  void _catchUpQueue() {
    if (_currentGameTurn.isEmpty) return;
    final int initialLength = _speechQueue.length;

    // Filter out turn-specific events that do not match the current turn
    _speechQueue.removeWhere((item) {
      if (item.turnColor != null && item.turnColor != _currentGameTurn) {
        print('[TTS] Event skipped: "${item.text}" (Obsolete turn: ${item.turnColor})');
        return true;
      }
      return false;
    });

    if (_speechQueue.length != initialLength) {
      print('[TTS] Current queue length: ${_speechQueue.length}');
    }
  }

  Future<void> setSpeechRate(double rate) async {
    await initialize();
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint("TTS setSpeechRate exception: $e");
    }
  }

  Future<void> setVolume(double volume) async {
    await initialize();
    try {
      await _tts.setVolume(volume);
    } catch (e) {
      debugPrint("TTS setVolume exception: $e");
    }
  }

  Future<void> speak(
    String text, {
    required String type,
    String? turnColor,
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(String)? onError,
  }) async {
    await initialize();
    
    print('[TTS] Event queued: "$text"');
    
    final item = SpeechItem(
      text,
      type: type,
      turnColor: turnColor?.toLowerCase(),
      onStart: onStart,
      onComplete: onComplete,
      onError: onError,
    );

    _speechQueue.add(item);
    print('[TTS] Current queue length: ${_speechQueue.length}');

    _catchUpQueue();

    if (!_isSpeaking) {
      _speakNext();
    }
  }

  Future<void> _speakNext() async {
    _catchUpQueue();

    if (_speechQueue.isEmpty) {
      _isSpeaking = false;
      _speechTimeoutTimer?.cancel();
      return;
    }
    _isSpeaking = true;
    final item = _speechQueue.removeAt(0);
    print('[TTS] Current queue length: ${_speechQueue.length}');

    if (item.turnColor != null && _currentGameTurn.isNotEmpty && item.turnColor != _currentGameTurn) {
      print('[TTS] Event skipped: "${item.text}" (Obsolete turn during playback check: ${item.turnColor})');
      _speakNext();
      return;
    }

    onOverlayMessage?.call(item.text);

    _speechTimeoutTimer?.cancel();
    _speechTimeoutTimer = Timer(const Duration(seconds: 8), () {
      print('[TTS WARNING] Speech timeout reached for: "${item.text}". Forcing next...');
      print('[TTS] Speech completed');
      print('[TTS] Audio focus released');
      _isSpeaking = false;
      _speakNext();
    });

    _tts.setStartHandler(() {
      print('[TTS] Speech started');
      print('[TTS] Event started: "${item.text}"');
      print('[TTS] Audio focus acquired');
      if (item.onStart != null) {
        item.onStart!();
      }
    });

    _tts.setCompletionHandler(() {
      _speechTimeoutTimer?.cancel();
      print('[TTS] Speech completed');
      print('[TTS] Event completed: "${item.text}"');
      print('[TTS] Audio focus released');
      if (item.onComplete != null) {
        item.onComplete!();
      }
      _speakNext();
    });

    _tts.setErrorHandler((msg) {
      _speechTimeoutTimer?.cancel();
      print('[TTS] Speech completed');
      print('[TTS] Event completed: "${item.text}" (Failed with error: $msg)');
      print('[TTS] Audio focus released');
      if (item.onError != null) {
        item.onError!(msg.toString());
      }
      _speakNext();
    });

    try {
      await _tts.speak(item.text);
    } catch (e) {
      _speechTimeoutTimer?.cancel();
      debugPrint("TTS speak exception: $e");
      print('[TTS] Speech completed');
      print('[TTS] Audio focus released');
      if (item.onError != null) {
        item.onError!(e.toString());
      }
      _speakNext();
    }
  }

  Future<void> stop() async {
    _speechTimeoutTimer?.cancel();
    _speechQueue.clear();
    _isSpeaking = false;
    await _tts.stop();
  }
}
