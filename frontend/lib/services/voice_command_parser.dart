import 'dart:math';

class VoiceIntent {
  final String action;
  final Map<String, dynamic> params;

  VoiceIntent({required this.action, this.params = const {}});
}

class VoiceCommandParser {
  static const List<String> wakeWords = ["ludo", "hey ludo", "ludo master"];

  // Checks if wake word is detected
  static bool hasWakeWord(String input) {
    final cleanInput = input.toLowerCase().trim();
    for (final word in wakeWords) {
      if (cleanInput.contains(word)) {
        return true;
      }
    }
    return false;
  }

  // Removes wake words from input to process core prompt
  static String stripWakeWord(String input) {
    var cleanInput = input.toLowerCase().trim();
    for (final word in wakeWords) {
      if (cleanInput.startsWith(word)) {
        cleanInput = cleanInput.replaceFirst(word, "").trim();
      }
    }
    return cleanInput;
  }

  // NLP Intent parser with multilingual (English, Hindi, Hinglish) support
  static VoiceIntent? parse(String rawInput, {bool requireWakeWord = false}) {
    final cleanRaw = rawInput.toLowerCase().trim();
    if (cleanRaw.isEmpty) return null;

    if (requireWakeWord && !hasWakeWord(cleanRaw)) {
      print("Wake word not detected in continuous mode. Ignoring prompt.");
      return null;
    }

    final input = stripWakeWord(cleanRaw);
    print("Parsing intent for clean input: '$input'");

    // 1. CREATE ROOM IN TENTS
    if (input.contains("1 player vs bots") || 
        input.contains("one player vs bots") || 
        input.contains("vs bots") || 
        input.contains("bot ke sath") || 
        input.contains("bots game")) {
      return VoiceIntent(action: "CREATE_ROOM_BOTS");
    }
    
    if (input.contains("create room") || 
        input.contains("create game") || 
        input.contains("host game") || 
        input.contains("host room") || 
        input.contains("create game room") ||
        input.contains("room bana") ||
        input.contains("room banao") ||
        input.contains("room bana do") ||
        input.contains("game bana")) {
      return VoiceIntent(action: "CREATE_ROOM");
    }

    // 2. JOIN ROOM
    if (input.contains("join room") || 
        input.contains("join game") || 
        input.contains("room join")) {
      return VoiceIntent(action: "JOIN_ROOM");
    }

    // 3. START MATCH / GAME LAUNCH
    if (input.contains("start game") || 
        input.contains("start match") || 
        input.contains("start play") || 
        input.contains("begin match") ||
        input.contains("game start") ||
        input.contains("game shuru") ||
        input.contains("game chalai")) {
      return VoiceIntent(action: "START_GAME");
    }

    // 4. ADD BOT
    if (input.contains("add bot") || 
        input.contains("add computer") || 
        input.contains("add a bot") ||
        input.contains("bot add") ||
        input.contains("bot dalo")) {
      return VoiceIntent(action: "ADD_BOT");
    }

    // 5. READY / UNREADY
    if (input.contains("toggle ready") || 
        input.contains("unready") ||
        input.contains("ready ho") ||
        input.contains("khelne ke liye ready") ||
        input == "ready") {
      return VoiceIntent(action: "TOGGLE_READY");
    }

    // 6. INVITE FRIEND INTENT
    if (input.contains("invite") || input.contains("bulao") || input.contains("invite karo")) {
      // Find name in string (e.g. "invite rahul" -> extract "rahul")
      final parts = input.split(" ");
      String name = "";
      if (input.contains("invite")) {
        final idx = parts.indexOf("invite");
        if (idx != -1 && idx + 1 < parts.length) {
          name = parts[idx + 1];
        }
      } else if (input.contains("invite karo")) {
        name = input.replaceFirst("invite karo", "").replaceAll("ko", "").trim();
      } else {
        name = input.replaceAll("invite", "").replaceAll("ko", "").replaceAll("bulao", "").trim();
      }
      return VoiceIntent(action: "INVITE_FRIEND", params: {"name": name.trim()});
    }

    // 7. GAMEPLAY DICE ROLL
    if (input.contains("roll") || 
        input.contains("roll dice") || 
        input.contains("throw dice") || 
        input.contains("throw") ||
        input.contains("dice fenko") ||
        input.contains("dice roll") ||
        input.contains("goti chalo") ||
        input.contains("dice ghumao")) {
      return VoiceIntent(action: "ROLL_DICE");
    }

    // 8. GAMEPLAY TOKEN SELECTIONS
    if (input.contains("token 1") || input.contains("token one") || input.contains("select 1") || input.contains("choose 1") || input.contains("move 1") || input.contains("goti ek") || input.contains("goti 1")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"tokenId": 0});
    }
    if (input.contains("token 2") || input.contains("token two") || input.contains("select 2") || input.contains("choose 2") || input.contains("move 2") || input.contains("goti do") || input.contains("goti 2")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"tokenId": 1});
    }
    if (input.contains("token 3") || input.contains("token three") || input.contains("select 3") || input.contains("choose 3") || input.contains("move 3") || input.contains("goti teen") || input.contains("goti 3")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"tokenId": 2});
    }
    if (input.contains("token 4") || input.contains("token four") || input.contains("select 4") || input.contains("choose 4") || input.contains("move 4") || input.contains("goti char") || input.contains("goti 4")) {
      return VoiceIntent(action: "SELECT_TOKEN", params: {"tokenId": 3});
    }

    // 9. DIALOG OPTION SELECTS (PLAYERS/BOTS COUNT)
    if (input.contains("select 1 player") || input.contains("one player") || input.contains("single player") || input.contains("ek player")) {
      return VoiceIntent(action: "SELECT_PLAYERS", params: {"count": 1});
    }
    if (input.contains("select 2 players") || input.contains("two players") || input.contains("do player")) {
      return VoiceIntent(action: "SELECT_PLAYERS", params: {"count": 2});
    }
    if (input.contains("select 3 players") || input.contains("three players") || input.contains("teen player")) {
      return VoiceIntent(action: "SELECT_PLAYERS", params: {"count": 3});
    }
    if (input.contains("select 4 players") || input.contains("four players") || input.contains("char player")) {
      return VoiceIntent(action: "SELECT_PLAYERS", params: {"count": 4});
    }
    if (input.contains("select 1 bot") || input.contains("one bot") || input.contains("1 bot") || input.contains("ek bot")) {
      return VoiceIntent(action: "SELECT_BOTS", params: {"count": 1});
    }
    if (input.contains("select 2 bots") || input.contains("two bots") || input.contains("2 bots") || input.contains("do bot")) {
      return VoiceIntent(action: "SELECT_BOTS", params: {"count": 2});
    }
    if (input.contains("select 3 bots") || input.contains("three bots") || input.contains("3 bots") || input.contains("teen bot")) {
      return VoiceIntent(action: "SELECT_BOTS", params: {"count": 3});
    }

    // 10. REWARDS CLAIM
    if (input.contains("claim") || 
        input.contains("daily reward") || 
        input.contains("claim reward") || 
        input.contains("gift") ||
        input.contains("reward claim")) {
      return VoiceIntent(action: "CLAIM_REWARD");
    }

    // 11. NAVIGATION INTENTS
    if (input.contains("leaderboard") || input.contains("ranking") || input.contains("global") || input.contains("leaderboard kholo")) {
      return VoiceIntent(action: "NAVIGATE", params: {"tabIndex": 2});
    }
    if (input.contains("friend") || input.contains("friends") || input.contains("social") || input.contains("dost list")) {
      return VoiceIntent(action: "NAVIGATE", params: {"tabIndex": 1});
    }
    if (input.contains("profile") || input.contains("account") || input.contains("myself") || input.contains("profile kholo")) {
      return VoiceIntent(action: "NAVIGATE", params: {"tabIndex": 3});
    }
    if (input.contains("play") || input.contains("home") || input.contains("arena") || input.contains("lobby")) {
      return VoiceIntent(action: "NAVIGATE", params: {"tabIndex": 0});
    }

    // 12. LIVEKIT MIC CONTROLS
    if (input.contains("mute microphone") || input.contains("mute mic") || input.contains("voice mute") || input.contains("silent mic")) {
      return VoiceIntent(action: "LIVEKIT_MUTE", params: {"mute": true});
    }
    if (input.contains("unmute microphone") || input.contains("unmute mic") || input.contains("voice unmute") || input.contains("active mic")) {
      return VoiceIntent(action: "LIVEKIT_MUTE", params: {"mute": false});
    }

    // 13. CHAT COMMANDS & EMOJIS
    if (input.contains("send message") || input.contains("message karo") || input.contains("send chat")) {
      final msg = input.replaceAll("send message", "").replaceAll("message karo", "").replaceAll("send chat", "").trim();
      return VoiceIntent(action: "CHAT_MESSAGE", params: {"message": msg, "isEmoji": false});
    }
    if (input.contains("laughing") || input.contains("laugh") || input.contains("hanso") || input.contains("laughing emoji")) {
      return VoiceIntent(action: "CHAT_MESSAGE", params: {"message": "😂", "isEmoji": true});
    }
    if (input.contains("thumbs up") || input.contains("like") || input.contains("thumbsup") || input.contains("like emoji")) {
      return VoiceIntent(action: "CHAT_MESSAGE", params: {"message": "👍", "isEmoji": true});
    }

    // 14. GET INFORMATION STATS
    if (input.contains("coin") || input.contains("coins") || input.contains("money") || input.contains("mere pas kitne paise")) {
      return VoiceIntent(action: "GET_COINS");
    }
    if (input.contains("win") || input.contains("wins") || input.contains("record") || input.contains("kitne match jeete")) {
      return VoiceIntent(action: "GET_WINS");
    }

    return null;
  }
}
