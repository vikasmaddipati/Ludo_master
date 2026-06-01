import 'package:flutter/foundation.dart';
import 'voice_command_registry.dart';
import 'intent_engine.dart';

class VoiceTestResult {
  final String intent;
  final String phrase;
  final bool recognition;
  final bool intentDetected;
  final bool contextMatch;
  final bool execution;
  final String reason;

  VoiceTestResult({
    required this.intent,
    required this.phrase,
    required this.recognition,
    required this.intentDetected,
    required this.contextMatch,
    required this.execution,
    required this.reason,
  });
}

class VoiceTestFramework {
  static final VoiceTestFramework instance = VoiceTestFramework._internal();
  VoiceTestFramework._internal();

  final List<VoiceTestResult> _results = [];
  bool _isRunning = false;

  List<VoiceTestResult> get results => _results;
  bool get isRunning => _isRunning;

  Future<List<VoiceTestResult>> runFullTestSuite(String currentContext) async {
    if (_isRunning) return _results;
    _isRunning = true;
    _results.clear();

    final registry = VoiceCommandRegistry.instance;
    final testCommands = List<VoiceCommand>.from(registry.commands);

    debugPrint("VoiceTestFramework: Starting full automated validation suite in context: $currentContext");

    for (final cmd in testCommands) {
      if (cmd.phrases.isEmpty) continue;
      
      final testPhrase = cmd.phrases.first;

      // 1. Simulate Speech Recognition
      bool recognitionPass = testPhrase.isNotEmpty;

      // 2. Intent Detection validation via IntentEngine
      final parsedIntent = IntentEngine.parseIntent(testPhrase);
      bool intentPass = parsedIntent != null && parsedIntent.action == cmd.intent;

      // 3. Screen Context checks
      bool contextPass = cmd.allowedContext == 'global' || cmd.allowedContext == currentContext;

      // 4. Execution check (Is a real handler connected?)
      bool handlerPass = registry.hasHandler(cmd.intent);

      String reason = "PASS";
      bool finalExecution = false;

      if (!intentPass) {
        reason = "Intent Engine Mismatch: expected ${cmd.intent}, parsed ${parsedIntent?.action ?? 'NONE'}";
      } else if (!contextPass) {
        reason = "Context Mismatch: allowed ${cmd.allowedContext}, active $currentContext";
      } else if (!handlerPass) {
        reason = "Handler Mismatch: No active screen/API handler bound to this intent";
      } else {
        finalExecution = true;
      }

      // Update registry's validation telemetry for the visual console
      cmd.executionStatus = finalExecution ? "SUCCESS" : "FAILED";
      cmd.validationResult = reason;

      _results.add(VoiceTestResult(
        intent: cmd.intent,
        phrase: testPhrase,
        recognition: recognitionPass,
        intentDetected: intentPass,
        contextMatch: contextPass,
        execution: finalExecution,
        reason: reason,
      ));
    }

    debugPrint("VoiceTestFramework: Completed suite. Passed ${_results.where((r) => r.execution).length}/${_results.length} commands.");
    _isRunning = false;
    return _results;
  }
}
