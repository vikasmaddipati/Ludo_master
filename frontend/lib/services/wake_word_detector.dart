class WakeWordDetector {
  static const List<String> wakeWords = ["ludo master", "hey ludo", "ludo"];

  /// Returns true if the input contains any wake word
  static bool hasWakeWord(String input) {
    final clean = input.toLowerCase().trim();
    for (final word in wakeWords) {
      if (clean.contains(word)) {
        return true;
      }
    }
    return false;
  }

  /// Removes the wake word and any leading/trailing whitespace/punctuation from the input
  static String stripWakeWord(String input) {
    var clean = input.toLowerCase().trim();
    for (final word in wakeWords) {
      if (clean.startsWith(word)) {
        clean = clean.replaceFirst(word, "").trim();
      }
    }
    // Also remove clean starting separators like commas
    if (clean.startsWith(",") || clean.startsWith(".") || clean.startsWith("?")) {
      clean = clean.substring(1).trim();
    }
    return clean;
  }
}
