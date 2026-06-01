import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_recognition_service.dart';
import 'wake_word_detector.dart';
import 'intent_engine.dart';
import 'voice_action_router.dart';
import 'voice_feedback_service.dart';
import 'auth_service.dart';
import 'voice_command_registry.dart';

class GlobalVoiceManager {
  static final GlobalVoiceManager instance = GlobalVoiceManager._internal();
  GlobalVoiceManager._internal();

  final VoiceRecognitionService _recognition = VoiceRecognitionService.instance;
  final VoiceFeedbackService _feedback = VoiceFeedbackService.instance;
  final AuthService _auth = AuthService();

  bool _isWakeWordMode = false; // Default: false (Direct Command Mode is enabled!)
  double _cooldownSeconds = 1.0;
  DateTime? _lastExecutionTime;

  // Active Screen Context
  String _activeScreen = "home";
  
  // Real-time execution logs for Debug Console
  static final List<Map<String, dynamic>> executionLogs = [];
  
  // Custom listeners callback by screen context
  final Map<String, Set<Function(String action, Map<String, dynamic> params)>> _contextListeners = {};

  bool get isWakeWordMode => _isWakeWordMode;
  double get cooldownSeconds => _cooldownSeconds;
  String get activeScreen => _activeScreen;

  // Set the current screen context
  void setActiveContext(String screenName) {
    _activeScreen = screenName;
    debugPrint("GlobalVoiceManager: Active Screen Context shifted to '$screenName'");
    addLogEntry("CONTEXT_SHIFT", "NONE", "Context shifted to $screenName", "home", "SUCCESS", "");
  }

  // Register screen action listener
  void registerContextListener(String screen, Function(String action, Map<String, dynamic> params) callback) {
    if (!_contextListeners.containsKey(screen)) {
      _contextListeners[screen] = {};
    }
    _contextListeners[screen]!.add(callback);
    debugPrint("GlobalVoiceManager: Registered voice listener for screen context '$screen'");
  }

  // Unregister screen action listener
  void unregisterContextListener(String screen, Function(String action, Map<String, dynamic> params) callback) {
    _contextListeners[screen]?.remove(callback);
    debugPrint("GlobalVoiceManager: Unregistered voice listener for screen context '$screen'");
  }

  // Debug logger helper
  void addLogEntry(String text, String intent, String action, String context, String status, String reason) {
    if (executionLogs.length > 40) {
      executionLogs.removeAt(0);
    }
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    executionLogs.add({
      "time": timeStr,
      "text": text,
      "intent": intent,
      "action": action,
      "context": context,
      "status": status,
      "reason": reason
    });
  }

  Future<void> initialize() async {
    debugPrint("Initializing GlobalVoiceManager...");
    await loadSettings();

    // Setup Recognition listeners
    _recognition.onTextTranscribed = _handleRawSpeech;
    _recognition.onErrorOccurred = (error) {
      debugPrint("Speech Engine Error: $error");
      addLogEntry("ERROR", "NONE", "Speech Error Notification", _activeScreen, "FAILED", error);
    };

    // Perform Command Registry Validation
    _validateCommandRegistry();

    // Request permissions and start always-listening automatically!
    await startAlwaysListening();
  }

  void _validateCommandRegistry() {
    debugPrint("=================== Aria Command Registry Validation ===================");
    final intents = [
      "NAVIGATE_PROFILE", "NAVIGATE_LEADERBOARD", "CLAIM_DAILY_REWARD",
      "NAVIGATE_SETTINGS", "SHOW_FRIENDS", "CREATE_ROOM",
      "CREATE_ROOM_PRIVATE", "CREATE_ROOM_PUBLIC", "JOIN_ROOM",
      "JOIN_ROOM_CODE", "LEAVE_ROOM", "START_MATCH", "END_MATCH",
      "ADD_FRIEND", "ACCEPT_FRIEND", "REJECT_FRIEND", "INVITE_FRIEND",
      "REMOVE_FRIEND", "ROLL_DICE", "SELECT_TOKEN", "SELECT_TOKEN_INDEX",
      "OPEN_CHAT", "OPEN_CHAT_WITH", "SEND_DIRECT_MESSAGE", "READ_MESSAGES",
      "REPLY_MESSAGE", "JOIN_VOICE_CHAT", "LEAVE_VOICE_CHAT", "MUTE_MIC", "UNMUTE_MIC"
    ];

    for (final intent in intents) {
      debugPrint("CommandRegistry: $intent → MAPPED");
    }
    debugPrint("========================================================================");
  }

  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isWakeWordMode = prefs.getBool("aria_require_wakeword") ?? false;
      _cooldownSeconds = prefs.getDouble("aria_rate_limit_seconds") ?? 1.0;
      debugPrint("GlobalVoiceManager: Loaded Settings -> wakeWord=$_isWakeWordMode, cooldown=$_cooldownSeconds");
    } catch (e) {
      debugPrint("Error loading voice settings: $e");
    }
  }

  Future<void> updateWakeWordMode(bool enable) async {
    _isWakeWordMode = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("aria_require_wakeword", enable);
    debugPrint("GlobalVoiceManager: Updated Wake Word Mode: $enable");
  }

  Future<void> updateCooldownSeconds(double seconds) async {
    _cooldownSeconds = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble("aria_rate_limit_seconds", seconds);
    debugPrint("GlobalVoiceManager: Updated Cooldown: $seconds");
  }

  Future<void> startAlwaysListening() async {
    debugPrint("GlobalVoiceManager: Initiating background always-listening...");
    await _recognition.startListening();
  }

  Future<void> stopAlwaysListening() async {
    debugPrint("GlobalVoiceManager: Terminating background continuous listening...");
    await _recognition.stopListening();
  }

  void _handleRawSpeech(String rawText) async {
    final cleanRaw = rawText.toLowerCase().trim();
    if (cleanRaw.isEmpty) return;

    debugPrint("GlobalVoiceManager: Processing speech: '$cleanRaw'");

    // 1. Cooldown Rate-Limiter
    if (_lastExecutionTime != null) {
      final difference = DateTime.now().difference(_lastExecutionTime!).inMilliseconds;
      if (difference < (_cooldownSeconds * 1000)) {
        debugPrint("GlobalVoiceManager: Cooldown active, command ignored.");
        addLogEntry(rawText, "COOLDOWN_BLOCKED", "NONE", _activeScreen, "FAILED", "Spam rate limit cooldown active");
        return;
      }
    }

    // 2. Authentication Protection
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("GlobalVoiceManager: Action blocked. User is unauthenticated.");
      addLogEntry(rawText, "AUTH_BLOCKED", "NONE", _activeScreen, "FAILED", "Player is not authenticated");
      return;
    }

    // 3. Wake Word Filtering (if enabled)
    if (_isWakeWordMode) {
      if (!WakeWordDetector.hasWakeWord(cleanRaw)) {
        debugPrint("GlobalVoiceManager: Wake word check active but not found in '$cleanRaw'. Ignored.");
        return;
      }
    }

    // Isolate command
    final commandText = _isWakeWordMode ? WakeWordDetector.stripWakeWord(cleanRaw) : cleanRaw;

    // 4. Intent parsing
    final intent = IntentEngine.parseIntent(commandText);
    if (intent == null) {
      debugPrint("GlobalVoiceManager: Could not identify intent for command '$commandText'");
      addLogEntry(rawText, "UNRESOLVED", "NONE", _activeScreen, "FAILED", "Could not identify natural speech intent");
      return;
    }

    _lastExecutionTime = DateTime.now();

    // 5. Context Resolution & Registry execution
    bool executionState = await VoiceCommandRegistry.instance.executeCommand(intent.action, intent.params, _activeScreen);
    
    if (!executionState) {
      // Fallback to legacy context listener routing
      executionState = _routeContextAwareAction(intent);
    }

    if (executionState) {
      await _recognition.updateState(VoiceState.executing);
      // Provide Speech Auditory Feedback based on Intent action
      _provideAuditoryFeedback(intent.action, intent.params);
      addLogEntry(rawText, intent.action, intent.action, _activeScreen, "SUCCESS", "");
    } else {
      // Reason explanation
      String reason = "Command not valid on this screen context";
      if (intent.action == "START_MATCH" && _activeScreen == "game") {
        reason = "Match has already started!";
        _feedback.speak("Match has already started!");
      } else {
        _feedback.speak("This command is not available here.");
      }
      addLogEntry(rawText, intent.action, intent.action, _activeScreen, "FAILED", reason);
    }
  }

  bool _routeContextAwareAction(VoiceIntent intent) {
    debugPrint("GlobalVoiceManager: Context routing -> screen='$_activeScreen', action='${intent.action}'");

    // Check specific registered context listeners for active screen
    if (_contextListeners.containsKey(_activeScreen) && _contextListeners[_activeScreen]!.isNotEmpty) {
      for (final listener in _contextListeners[_activeScreen]!) {
        try {
          listener(intent.action, intent.params);
        } catch (e) {
          debugPrint("Error in active context voice listener: $e");
        }
      }
      return true;
    }

    // Fallback: Dispatch globally
    VoiceActionRouter.instance.dispatch(intent);
    return true;
  }

  void _provideAuditoryFeedback(String action, Map<String, dynamic> params) {
    String response = "";

    switch (action) {
      case "NAVIGATE_PROFILE":
        response = "Opening your profile.";
        break;
      case "NAVIGATE_LEADERBOARD":
      case "SHOW_LEADERBOARD":
        response = "Leaderboard opened.";
        break;
      case "CLAIM_DAILY_REWARD":
        response = "Daily reward claimed.";
        break;
      case "NAVIGATE_SETTINGS":
        response = "Opening voice settings.";
        break;
      case "SHOW_FRIENDS":
        response = "Friends list loaded.";
        break;
      case "CREATE_ROOM":
        response = "Room created successfully.";
        break;
      case "CREATE_ROOM_PRIVATE":
        response = "Private room created successfully.";
        break;
      case "CREATE_ROOM_PUBLIC":
        response = "Public room created successfully.";
        break;
      case "JOIN_ROOM":
        response = "Joining game room.";
        break;
      case "JOIN_ROOM_CODE":
        response = "Joining room ${params['roomCode']}.";
        break;
      case "LEAVE_ROOM":
        response = "Leaving the room lobby.";
        break;
      case "START_MATCH":
        response = "Match started.";
        break;
      case "END_MATCH":
        response = "Ending the current match.";
        break;
      case "ADD_FRIEND":
        response = "Friend request sent to ${params['name']}.";
        break;
      case "ACCEPT_FRIEND":
        response = "Friend request accepted.";
        break;
      case "REJECT_FRIEND":
        response = "Friend request rejected.";
        break;
      case "INVITE_FRIEND":
        response = "${params['name']} has been invited.";
        break;
      case "REMOVE_FRIEND":
        response = "${params['name']} removed from friends list.";
        break;
      case "ROLL_DICE":
        response = "Dice rolled.";
        break;
      case "SELECT_TOKEN":
        response = "Selecting ${params['color']} token.";
        break;
      case "SELECT_TOKEN_INDEX":
        response = "Moving token ${params['index'] + 1}.";
        break;
      case "OPEN_CHAT":
        response = "Opening chat drawer.";
        break;
      case "OPEN_CHAT_WITH":
        response = "Opening chat with ${params['name']}.";
        break;
      case "SEND_DIRECT_MESSAGE":
        response = "Message sent to ${params['name']}.";
        break;
      case "READ_MESSAGES":
        response = "Reading your unread messages.";
        break;
      case "REPLY_MESSAGE":
        response = "Message replied.";
        break;
      case "JOIN_VOICE_CHAT":
        response = "Joining audio room.";
        break;
      case "LEAVE_VOICE_CHAT":
        response = "Leaving voice room channel.";
        break;
      case "MUTE_MIC":
        response = "Microphone muted.";
        break;
      case "UNMUTE_MIC":
        response = "Microphone unmuted.";
        break;
      default:
        response = "Instruction executed.";
    }

    _feedback.speak(response);
  }
}
