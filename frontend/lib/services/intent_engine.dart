import 'wake_word_detector.dart';

class VoiceIntent {
  final String action;
  final Map<String, dynamic> params;

  VoiceIntent({required this.action, this.params = const {}});
}

class IntentEngine {
  /// Matches a cleaned transcript into a structured VoiceIntent action
  static VoiceIntent? parseIntent(String input) {
    final clean = input.toLowerCase().trim();
    if (clean.isEmpty) return null;

    // ==========================================
    // 1. SPECIFIC REGEX MATCHES (High Priority)
    // ==========================================

    // Join Room 123456 or variants like "join with room code 123456", "join 123456", etc.
    final joinRoomReg = RegExp(r"(?:join\s+(?:with\s+)?(?:room\s+)?(?:code\s+)?|room\s+code\s+|code\s+)(\d{4,8})");
    if (joinRoomReg.hasMatch(clean)) {
      final match = joinRoomReg.firstMatch(clean);
      final roomCode = match?.group(1);
      return VoiceIntent(action: "JOIN_ROOM_CODE", params: {"roomCode": roomCode});
    }

    // Just digits (4-8) - treat as a room code
    final justDigitsReg = RegExp(r"^\s*(\d{4,8})\s*$");
    if (justDigitsReg.hasMatch(clean)) {
      final match = justDigitsReg.firstMatch(clean);
      final roomCode = match?.group(1);
      return VoiceIntent(action: "JOIN_ROOM_CODE", params: {"roomCode": roomCode});
    }

    // Friend Management Requests
    final addFriendReg = RegExp(r"(?:add|send\s+friend\s+request\s+to)\s+([a-zA-Z0-9\s]+)");
    if (addFriendReg.hasMatch(clean)) {
      final match = addFriendReg.firstMatch(clean);
      final name = match?.group(1)?.trim();
      if (name != null && name.isNotEmpty && name != "friend request" && name != "friend") {
        return VoiceIntent(action: "ADD_FRIEND", params: {"name": name});
      }
    }

    final inviteReg = RegExp(r"(?:invite|bulao|ko invite karo)\s+([a-zA-Z0-9\s]+)");
    if (inviteReg.hasMatch(clean)) {
      final match = inviteReg.firstMatch(clean);
      final name = match?.group(1)?.trim();
      if (name != null && name.isNotEmpty && name != "friend" && name != "player") {
        return VoiceIntent(action: "INVITE_FRIEND", params: {"name": name});
      }
    }

    final removeReg = RegExp(r"remove\s+([a-zA-Z0-9\s]+)");
    if (removeReg.hasMatch(clean)) {
      final match = removeReg.firstMatch(clean);
      final name = match?.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return VoiceIntent(action: "REMOVE_FRIEND", params: {"name": name});
      }
    }

    // Direct Messages
    final openChatWithReg = RegExp(r"open\s+chat\s+with\s+([a-zA-Z0-9\s]+)");
    if (openChatWithReg.hasMatch(clean)) {
      final match = openChatWithReg.firstMatch(clean);
      final name = match?.group(1)?.trim();
      return VoiceIntent(action: "OPEN_CHAT_WITH", params: {"name": name});
    }

    final sendMsgReg = RegExp(r"send\s+message\s+to\s+([a-zA-Z0-9]+)\s+([a-zA-Z0-9\s]+)");
    if (sendMsgReg.hasMatch(clean)) {
      final match = sendMsgReg.firstMatch(clean);
      final name = match?.group(1)?.trim();
      final msg = match?.group(2)?.trim();
      return VoiceIntent(action: "SEND_DIRECT_MESSAGE", params: {"name": name, "message": msg});
    }

    // ==========================================
    // 2. GAMEPLAY & DIALOG CONTROLS (Medium Priority)
    // ==========================================

    // Dice rolling triggers
    if (clean.contains("roll") || clean.contains("throw") || clean.contains("dice") || clean.contains("fenko") || clean.contains("spin")) {
      return VoiceIntent(action: "ROLL_DICE");
    }

    // Token index selections (Tolerant of English, numbers, ordinals, Hindi)
    if (clean.contains("token 1") || clean.contains("token one") || clean.contains("select 1") || clean.contains("choose 1") || clean.contains("move 1") || clean.contains("goti ek") || clean.contains("goti 1") || clean.contains("first token") || clean.contains("first goti") || clean == "1" || clean == "one" || clean == "first") {
      return VoiceIntent(action: "SELECT_TOKEN_INDEX", params: {"index": 0});
    }
    if (clean.contains("token 2") || clean.contains("token two") || clean.contains("select 2") || clean.contains("choose 2") || clean.contains("move 2") || clean.contains("goti do") || clean.contains("goti 2") || clean.contains("second token") || clean.contains("second goti") || clean == "2" || clean == "two" || clean == "second") {
      return VoiceIntent(action: "SELECT_TOKEN_INDEX", params: {"index": 1});
    }
    if (clean.contains("token 3") || clean.contains("token three") || clean.contains("select 3") || clean.contains("choose 3") || clean.contains("move 3") || clean.contains("goti teen") || clean.contains("goti 3") || clean.contains("third token") || clean.contains("third goti") || clean == "3" || clean == "three" || clean == "third") {
      return VoiceIntent(action: "SELECT_TOKEN_INDEX", params: {"index": 2});
    }
    if (clean.contains("token 4") || clean.contains("token four") || clean.contains("select 4") || clean.contains("choose 4") || clean.contains("move 4") || clean.contains("goti char") || clean.contains("goti 4") || clean.contains("fourth token") || clean.contains("fourth goti") || clean == "4" || clean == "four" || clean == "fourth") {
      return VoiceIntent(action: "SELECT_TOKEN_INDEX", params: {"index": 3});
    }

    // Color-based token choices
    if (clean.contains("red goti") || clean.contains("red token")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"color": "red"});
    }
    if (clean.contains("green goti") || clean.contains("green token")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"color": "green"});
    }
    if (clean.contains("blue goti") || clean.contains("blue token")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"color": "blue"});
    }
    if (clean.contains("yellow goti") || clean.contains("yellow token")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"color": "yellow"});
    }

    if (clean.contains("select token") || clean.contains("move token") || clean.contains("goti chalo")) {
      final matchDigit = RegExp(r"(?:token|goti)\s*(\d)").firstMatch(clean);
      if (matchDigit != null) {
        final num = int.tryParse(matchDigit.group(1) ?? "");
        if (num != null) {
          return VoiceIntent(action: "SELECT_TOKEN_INDEX", params: {"index": num - 1});
        }
      }
      return VoiceIntent(action: "SELECT_TOKEN");
    }

    // ==========================================
    // 3. ROOM & LOBBY SYSTEM (Lobby Management)
    // ==========================================
    if (clean.contains("create private room") || clean.contains("make private room") || clean.contains("start private room") || clean.contains("private room")) {
      return VoiceIntent(action: "CREATE_ROOM_PRIVATE");
    }
    if (clean.contains("create public room") || clean.contains("make public room") || clean.contains("start public room") || clean.contains("public room")) {
      return VoiceIntent(action: "CREATE_ROOM_PUBLIC");
    }
    if (clean.contains("create room") || clean.contains("make room") || clean.contains("open room") || clean.contains("start room") || clean.contains("create game room") || clean.contains("host game") || clean.contains("host room") || clean.contains("room bana")) {
      return VoiceIntent(action: "CREATE_ROOM");
    }

    if (clean.contains("join room") || 
        clean.contains("join game") || 
        clean.contains("join with room") || 
        clean.contains("join with room code") || 
        clean.contains("join with") || 
        clean == "join") {
      return VoiceIntent(action: "JOIN_ROOM");
    }

    if (clean.contains("leave room") || clean.contains("exit room") || clean.contains("exit lobby") || clean.contains("leave lobby") || clean == "leave" || clean == "exit") {
      return VoiceIntent(action: "LEAVE_ROOM");
    }

    if (clean.contains("start multiplayer match") || 
        clean.contains("start multiplayer") || 
        clean.contains("start match") || 
        clean.contains("start game") || 
        clean.contains("game shuru") || 
        clean == "start" || 
        clean == "multiplayer" || 
        clean == "multiplayer match") {
      return VoiceIntent(action: "START_MATCH");
    }

    if (clean.contains("add bot") || clean.contains("add computer") || clean.contains("computer players") || clean.contains("add a bot") || clean.contains("bot dalo")) {
      return VoiceIntent(action: "ADD_BOT");
    }

    if (clean.contains("accept friend request") || clean.contains("accept friend") || clean.contains("dost accept")) {
      return VoiceIntent(action: "ACCEPT_FRIEND");
    }
    if (clean.contains("reject friend request") || clean.contains("reject friend") || clean.contains("decline friend")) {
      return VoiceIntent(action: "REJECT_FRIEND");
    }

    if (clean.contains("ready") || clean.contains("toggle ready") || clean.contains("unready")) {
      return VoiceIntent(action: "TOGGLE_READY");
    }

    if (clean.contains("end match") || clean.contains("stop game") || clean.contains("finish match")) {
      return VoiceIntent(action: "END_MATCH");
    }

    // ==========================================
    // 4. CHAT, AUDIO & STATS
    // ==========================================
    if (clean.contains("send emoji")) {
      final parts = clean.split("send emoji");
      final emoji = parts.last.trim();
      return VoiceIntent(action: "SEND_EMOJI", params: {"emoji": emoji});
    }
    if (clean.contains("open chat")) {
      return VoiceIntent(action: "OPEN_CHAT");
    }
    if (clean.contains("read my messages") || clean.contains("read messages") || clean.contains("check messages")) {
      return VoiceIntent(action: "READ_MESSAGES");
    }
    if (clean.contains("reply")) {
      final msg = clean.replaceAll("reply", "").trim();
      return VoiceIntent(action: "REPLY_MESSAGE", params: {"message": msg});
    }

    if (clean.contains("join voice chat") || clean.contains("join audio chat") || clean.contains("voice room")) {
      return VoiceIntent(action: "JOIN_VOICE_CHAT");
    }
    if (clean.contains("leave voice chat") || clean.contains("leave audio chat")) {
      return VoiceIntent(action: "LEAVE_VOICE_CHAT");
    }
    if (clean.contains("mute microphone") || clean.contains("mute mic") || clean == "mute") {
      return VoiceIntent(action: "MUTE_MIC");
    }
    if (clean.contains("unmute microphone") || clean.contains("unmute mic") || clean == "unmute") {
      return VoiceIntent(action: "UNMUTE_MIC");
    }

    // Win/coin stats
    if (clean.contains("coins") || clean.contains("coin") || clean.contains("paise") || clean.contains("money")) {
      return VoiceIntent(action: "SHOW_COINS");
    }
    if (clean.contains("xp") || clean.contains("experience") || clean.contains("level progress")) {
      return VoiceIntent(action: "SHOW_XP");
    }
    if (clean.contains("level") || clean.contains("lvl")) {
      return VoiceIntent(action: "SHOW_LEVEL");
    }
    if (clean.contains("mission") || clean.contains("missions") || clean.contains("daily tasks")) {
      return VoiceIntent(action: "SHOW_MISSIONS");
    }
    if (clean.contains("win") || clean.contains("wins") || clean.contains("record") || clean.contains("match jeete")) {
      return VoiceIntent(action: "GET_WINS");
    }

    // ==========================================
    // 5. NAVIGATION FALLBACKS (Low Priority)
    // ==========================================
    if (clean.contains("profile") || clean.contains("account") || clean.contains("myself") || clean.contains("me")) {
      return VoiceIntent(action: "NAVIGATE_PROFILE");
    }
    if (clean.contains("leaderboard") || clean.contains("ranking") || clean.contains("rankings") || clean.contains("top players") || clean.contains("scores")) {
      return VoiceIntent(action: "NAVIGATE_LEADERBOARD");
    }
    if (clean.contains("rewards") || clean.contains("reward screen") || clean.contains("rewards panel") || clean.contains("rewards kholo")) {
      return VoiceIntent(action: "OPEN_REWARDS");
    }
    if (clean.contains("claim daily") || clean.contains("claim streak") || clean.contains("claim reward") || clean.contains("daily claim")) {
      return VoiceIntent(action: "CLAIM_DAILY_REWARD");
    }
    if (clean.contains("setting") || clean.contains("settings") || clean.contains("option") || clean.contains("options") || clean.contains("configure")) {
      return VoiceIntent(action: "NAVIGATE_SETTINGS");
    }
    if (clean.contains("friend") || clean.contains("friends") || clean.contains("social") || clean.contains("dost")) {
      return VoiceIntent(action: "SHOW_FRIENDS");
    }

    return null;
  }
}
