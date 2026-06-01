import 'package:flutter/foundation.dart';
import 'intent_engine.dart';

typedef VoiceActionCallback = void Function(String action, Map<String, dynamic> params);

class VoiceActionRouter {
  static final VoiceActionRouter instance = VoiceActionRouter._internal();
  VoiceActionRouter._internal();

  final Set<VoiceActionCallback> _listeners = {};

  /// Registers a callback to receive voice command action events.
  void registerListener(VoiceActionCallback callback) {
    _listeners.add(callback);
    debugPrint("VoiceActionRouter: Listener registered. Total count: ${_listeners.length}");
  }

  /// Unregisters a callback.
  void unregisterListener(VoiceActionCallback callback) {
    _listeners.remove(callback);
    debugPrint("VoiceActionRouter: Listener unregistered. Total count: ${_listeners.length}");
  }

  /// Dispatches the parsed intent to all active listeners.
  void dispatch(VoiceIntent intent) {
    debugPrint("VoiceActionRouter: Dispatching action '${intent.action}' with parameters: ${intent.params}");
    
    // Create a copy of the listeners set to avoid ConcurrentModificationException if a listener unregisters itself during execution
    final activeListeners = List<VoiceActionCallback>.from(_listeners);
    
    for (final listener in activeListeners) {
      try {
        listener(intent.action, intent.params);
      } catch (e) {
        debugPrint("Error in voice action listener callback: $e");
      }
    }
  }
}
