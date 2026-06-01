import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceLogEntry {
  final String text;
  final String action;
  final String timestamp;
  final bool success;

  VoiceLogEntry({
    required this.text,
    required this.action,
    required this.timestamp,
    required this.success,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'action': action,
        'timestamp': timestamp,
        'success': success,
      };

  factory VoiceLogEntry.fromJson(Map<String, dynamic> json) => VoiceLogEntry(
        text: json['text'] ?? "",
        action: json['action'] ?? "UNKNOWN",
        timestamp: json['timestamp'] ?? "",
        success: json['success'] ?? false,
      );
}

class VoiceCommandHistory {
  static const String _keyHistory = "voice_command_history_logs";

  // Fetches persistent command logs
  static Future<List<VoiceLogEntry>> getLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawData = prefs.getString(_keyHistory);
      if (rawData == null) return [];

      final List<dynamic> decoded = json.decode(rawData);
      return decoded.map((item) => VoiceLogEntry.fromJson(item)).toList();
    } catch (e) {
      print("Error loading voice logs: $e");
      return [];
    }
  }

  // Adds a single voice action execution log
  static Future<void> addLog(String text, String action, bool success) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = await getLogs();

      final entry = VoiceLogEntry(
        text: text,
        action: action,
        timestamp: DateTime.now().toLocal().toString().substring(0, 19),
        success: success,
      );

      logs.insert(0, entry); // Insert latest log at the top

      // Limit logs size to top 50 entries
      if (logs.length > 50) {
        logs.removeLast();
      }

      final String encoded = json.encode(logs.map((item) => item.toJson()).toList());
      await prefs.setString(_keyHistory, encoded);
      print("Voice command log entry saved successfully: '$action' -> success=$success");
    } catch (e) {
      print("Error saving voice log: $e");
    }
  }

  // Clears all history
  static Future<void> clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyHistory);
    } catch (e) {
      print("Error clearing voice logs: $e");
    }
  }
}
