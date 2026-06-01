import 'package:flutter/foundation.dart';

typedef VoiceCommandHandler = Future<void> Function(Map<String, dynamic> params);

class VoiceCommand {
  final String intent;
  final List<String> phrases;
  final String allowedContext; // 'home', 'lobby', 'game', 'friends', 'global'
  String executionStatus; // 'PENDING', 'SUCCESS', 'FAILED'
  String validationResult; // Reason for failure or status description

  VoiceCommand({
    required this.intent,
    required this.phrases,
    required this.allowedContext,
    this.executionStatus = 'PENDING',
    this.validationResult = 'Not tested yet',
  });
}

class VoiceCommandRegistry {
  static final VoiceCommandRegistry instance = VoiceCommandRegistry._internal();
  VoiceCommandRegistry._internal() {
    _registerDefaultCommands();
  }

  final List<VoiceCommand> _commands = [];
  final Map<String, VoiceCommandHandler> _handlers = {};

  List<VoiceCommand> get commands => _commands;

  void registerHandler(String intent, VoiceCommandHandler handler) {
    _handlers[intent] = handler;
    debugPrint("VoiceCommandRegistry: Handler registered for intent '$intent'");
  }

  void unregisterHandler(String intent) {
    _handlers.remove(intent);
    debugPrint("VoiceCommandRegistry: Handler unregistered for intent '$intent'");
  }

  bool hasHandler(String intent) {
    return _handlers.containsKey(intent);
  }

  Future<bool> executeCommand(String intent, Map<String, dynamic> params, String activeContext) async {
    final cmd = _commands.firstWhere((c) => c.intent == intent, orElse: () => VoiceCommand(intent: intent, phrases: [], allowedContext: 'global'));
    
    // Check screen context
    if (cmd.allowedContext != 'global' && cmd.allowedContext != activeContext) {
      cmd.executionStatus = 'FAILED';
      cmd.validationResult = 'Failed: Allowed context is ${cmd.allowedContext}, but active context is $activeContext';
      debugPrint("VoiceCommandRegistry: Command '$intent' blocked due to context mismatch ($activeContext vs ${cmd.allowedContext})");
      return false;
    }

    final handler = _handlers[intent];
    if (handler == null) {
      cmd.executionStatus = 'FAILED';
      cmd.validationResult = 'Failed: No handler registered for this intent';
      debugPrint("VoiceCommandRegistry: Execution failed for '$intent' - No handler found!");
      return false;
    }

    try {
      await handler(params);
      cmd.executionStatus = 'SUCCESS';
      cmd.validationResult = 'Executed successfully';
      debugPrint("VoiceCommandRegistry: Execution SUCCESS for '$intent'");
      return true;
    } catch (e) {
      cmd.executionStatus = 'FAILED';
      cmd.validationResult = 'Failed: $e';
      debugPrint("VoiceCommandRegistry: Execution ERROR for '$intent': $e");
      return false;
    }
  }

  void _registerDefaultCommands() {
    // HOME & NAVIGATION
    _commands.add(VoiceCommand(
      intent: "NAVIGATE_PROFILE",
      phrases: ["open profile", "show profile", "profile kholo", "account page", "profile page"],
      allowedContext: "global",
    ));
    _commands.add(VoiceCommand(
      intent: "NAVIGATE_LEADERBOARD",
      phrases: ["open leaderboard", "show leaderboard", "rankings", "top players", "leaderboard kholo"],
      allowedContext: "global",
    ));
    _commands.add(VoiceCommand(
      intent: "CLAIM_DAILY_REWARD",
      phrases: ["open rewards", "claim reward", "daily reward", "collect daily reward", "reward claim", "gift kholo", "bonus claim karo"],
      allowedContext: "global",
    ));
    _commands.add(VoiceCommand(
      intent: "NAVIGATE_SETTINGS",
      phrases: ["open settings", "voice settings", "settings page", "settings kholo"],
      allowedContext: "global",
    ));
    _commands.add(VoiceCommand(
      intent: "SHOW_FRIENDS",
      phrases: ["show friends", "open friends", "friends page", "dost list kholo", "social tab"],
      allowedContext: "global",
    ));

    // ROOM / MULTIPLAYER SYSTEM
    _commands.add(VoiceCommand(
      intent: "CREATE_ROOM",
      phrases: ["create room", "make room", "open room", "start room", "create game room", "room banao", "room bana do", "start multiplayer", "start multiplayer match"],
      allowedContext: "home",
    ));
    _commands.add(VoiceCommand(
      intent: "CREATE_ROOM_PRIVATE",
      phrases: ["create private room", "make private room", "start private room", "private room banao"],
      allowedContext: "home",
    ));
    _commands.add(VoiceCommand(
      intent: "CREATE_ROOM_PUBLIC",
      phrases: ["create public room", "make public room", "start public room", "public room banao"],
      allowedContext: "home",
    ));
    _commands.add(VoiceCommand(
      intent: "JOIN_ROOM",
      phrases: ["join room", "join game", "room join karo", "join with room code", "join with room"],
      allowedContext: "home",
    ));
    _commands.add(VoiceCommand(
      intent: "JOIN_ROOM_CODE",
      phrases: ["join room 123456", "room code 123456", "join with room code 123456", "join 123456"],
      allowedContext: "home",
    ));

    // LOBBY SYSTEM
    _commands.add(VoiceCommand(
      intent: "START_MATCH",
      phrases: ["start match", "start game", "game shuru", "game chalai", "begin match", "game start"],
      allowedContext: "lobby",
    ));
    _commands.add(VoiceCommand(
      intent: "LEAVE_ROOM",
      phrases: ["leave room", "exit room", "exit lobby", "leave lobby", "exit", "leave"],
      allowedContext: "lobby",
    ));
    _commands.add(VoiceCommand(
      intent: "ADD_BOT",
      phrases: ["add bot", "add computer", "add a bot", "bot add karo", "bot dalo", "computer player dalo"],
      allowedContext: "lobby",
    ));
    _commands.add(VoiceCommand(
      intent: "TOGGLE_READY",
      phrases: ["ready", "ready up", "toggle ready", "unready", "ready ho jao", "khelne ke liye ready"],
      allowedContext: "lobby",
    ));
    _commands.add(VoiceCommand(
      intent: "INVITE_FRIEND",
      phrases: ["invite rahul", "invite friend", "rahul ko invite karo", "rahul ko bulao", "bulao rahul ko"],
      allowedContext: "lobby",
    ));

    // GAMEPLAY
    _commands.add(VoiceCommand(
      intent: "ROLL_DICE",
      phrases: ["roll dice", "roll", "dice fenko", "throw dice", "roll the dice", "dice ghumao"],
      allowedContext: "game",
    ));
    _commands.add(VoiceCommand(
      intent: "SELECT_TOKEN_INDEX",
      phrases: ["token 1", "token one", "select 1", "choose 1", "move 1", "goti ek", "goti 1", "first token", "move first goti"],
      allowedContext: "game",
    ));
    _commands.add(VoiceCommand(
      intent: "SELECT_TOKEN",
      phrases: ["select red token", "move green token", "yellow goti select karo", "blue goti chalo"],
      allowedContext: "game",
    ));
    _commands.add(VoiceCommand(
      intent: "SEND_EMOJI",
      phrases: ["send emoji laughing", "thumbs up emoji send karo", "send emoji thumbs up"],
      allowedContext: "game",
    ));
    _commands.add(VoiceCommand(
      intent: "OPEN_CHAT",
      phrases: ["open chat", "chat box kholo", "open game chat", "message window show karo"],
      allowedContext: "game",
    ));

    // VOICE CHAT (LIVEKIT)
    _commands.add(VoiceCommand(
      intent: "JOIN_VOICE_CHAT",
      phrases: ["join voice chat", "join audio chat", "connect voice room", "audio room join karo"],
      allowedContext: "game",
    ));
    _commands.add(VoiceCommand(
      intent: "LEAVE_VOICE_CHAT",
      phrases: ["leave voice chat", "leave audio chat", "disconnect voice room"],
      allowedContext: "game",
    ));
    _commands.add(VoiceCommand(
      intent: "MUTE_MIC",
      phrases: ["mute microphone", "mute mic", "mute", "mic band karo"],
      allowedContext: "game",
    ));
    _commands.add(VoiceCommand(
      intent: "UNMUTE_MIC",
      phrases: ["unmute microphone", "unmute mic", "unmute", "mic shuru karo"],
      allowedContext: "game",
    ));

    // SOCIAL ACTIONS
    _commands.add(VoiceCommand(
      intent: "ADD_FRIEND",
      phrases: ["add friend rahul", "send friend request to rahul", "rahul ko friend request bhejo"],
      allowedContext: "friends",
    ));
    _commands.add(VoiceCommand(
      intent: "ACCEPT_FRIEND",
      phrases: ["accept friend request", "accept friend", "request accept karo"],
      allowedContext: "friends",
    ));
    _commands.add(VoiceCommand(
      intent: "REJECT_FRIEND",
      phrases: ["reject friend request", "reject friend", "decline friend request"],
      allowedContext: "friends",
    ));
    _commands.add(VoiceCommand(
      intent: "REMOVE_FRIEND",
      phrases: ["remove friend rahul", "unfriend rahul"],
      allowedContext: "friends",
    ));

    // STATS
    _commands.add(VoiceCommand(
      intent: "GET_COINS",
      phrases: ["show coins", "show balance", "paise batao", "show wallet", "mere pas kitne coin hain"],
      allowedContext: "global",
    ));
    _commands.add(VoiceCommand(
      intent: "GET_WINS",
      phrases: ["show wins", "show statistics", "show wins count", "kitne match jeete", "win record batao"],
      allowedContext: "global",
    ));
  }
}
