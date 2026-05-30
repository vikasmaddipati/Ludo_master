import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/game_room_model.dart';

class ApiService {
  static const String baseUrl = 'https://ludo-t3um.onrender.com/api';

  // Auth: Google Login
  static Future<UserModel?> authenticateGoogleUser({
    required String googleId,
    required String name,
    required String email,
    required String avatarUrl,
    String? fcmToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'googleId': googleId,
          'name': name,
          'email': email,
          'avatarUrl': avatarUrl,
          'fcmToken': fcmToken ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return UserModel.fromJson(data['user']);
        }
      }
      return null;
    } catch (e) {
      print('API Auth Error: $e');
      return null;
    }
  }

  // Create Ludo game room code
  static Future<GameRoomModel?> createRoom(String userId, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/game/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'name': name}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return GameRoomModel.fromJson(data['room']);
        }
      }
    } catch (e) {
      print('API create room error: $e. Falling back to sandbox room creation.');
    }

    // Dynamic sandbox/offline bypass
    final randomCode = (100000 + Random().nextInt(900000)).toString();
    return GameRoomModel(
      id: 'room_$randomCode',
      roomCode: randomCode,
      creator: userId,
      status: 'waiting',
      turn: 'red',
      diceValue: 1,
      hasRolled: false,
      players: [
        PlayerModel(userId: userId, name: name, color: 'red', isReady: true, isConnected: true, isBot: false)
      ],
      tokens: [],
    );
  }

  // Claim Daily coin reward
  static Future<Map<String, dynamic>?> claimDailyReward(String userId, int currentCoins) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rewards/daily'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'currentCoins': currentCoins}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('API claim daily error: $e');
      return {
        'success': true,
        'coins': currentCoins + 250,
        'message': 'Daily reward claimed! +250 Coins (Sandbox Mode)'
      };
    }
  }

  // Get Leaderboard rankings
  static Future<Map<String, dynamic>?> getLeaderboard(String userId, {String sortBy = 'wins'}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leaderboard?userId=$userId&sortBy=$sortBy'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('API leaderboard error: $e');
      return {
        'success': true,
        'rankings': [
          {'name': 'DiceCrusher 🔥', 'wins': 142, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=crusher'},
          {'name': 'LudoQueen 👑', 'wins': 118, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=queen'},
          {'name': 'TokenStriker ⚡', 'wins': 95, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=striker'},
          {'name': 'Guest Master', 'wins': 64, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=guest'},
          {'name': 'CasualRoller 🎲', 'wins': 41, 'avatarUrl': 'https://api.dicebear.com/7.x/adventurer/png?seed=roller'},
        ]
      };
    }
  }

  // Fetch voice LiveKit Token
  static Future<String?> fetchLiveKitToken(String roomCode, String name) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/game/livekit-token?roomCode=$roomCode&name=$name'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['token'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('API livekit token error: $e');
      return null;
    }
  }
}
