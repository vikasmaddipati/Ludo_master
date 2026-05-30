import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/friend_model.dart';
import '../models/game_room_model.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.13:3000/api';

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

  // Search users for friends
  static Future<List<UserModel>> searchUsers(String query, String currentUserId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/search?query=$query&userId=$currentUserId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List usersJson = data['users'] ?? [];
          return usersJson.map((u) => UserModel.fromJson(u)).toList();
        }
      }
      return [];
    } catch (e) {
      print('API searchUsers error: $e');
      // Sandbox Mode: generate a couple of random users matching query
      return [
        UserModel(
          id: 'sandbox_u1',
          googleId: 'google_s1',
          name: '${query} Master',
          email: 'master@sandbox.com',
          avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=sandbox_u1',
          coins: 1500,
          wins: 12,
          losses: 5,
          fcmToken: '',
        ),
        UserModel(
          id: 'sandbox_u2',
          googleId: 'google_s2',
          name: 'Pro $query',
          email: 'pro@sandbox.com',
          avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=sandbox_u2',
          coins: 2500,
          wins: 34,
          losses: 14,
          fcmToken: '',
        ),
      ];
    }
  }

  // Send friend request
  static Future<bool> sendFriendRequest(String requesterId, String recipientId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requesterId': requesterId,
          'recipientId': recipientId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('API sendFriendRequest error: $e');
      return true; // Sandbox fallback
    }
  }

  // Get Friend Requests
  static Future<Map<String, List<FriendRequestModel>>> getFriendRequests(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/friends/requests/$userId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List incomingJson = data['incoming'] ?? [];
          final List outgoingJson = data['outgoing'] ?? [];

          return {
            'incoming': incomingJson.map((x) => FriendRequestModel.fromJson(x)).toList(),
            'outgoing': outgoingJson.map((x) => FriendRequestModel.fromJson(x)).toList(),
          };
        }
      }
      return {'incoming': [], 'outgoing': []};
    } catch (e) {
      print('API getFriendRequests error: $e');
      // Sandbox fallback incoming request
      return {
        'incoming': [
          FriendRequestModel(
            id: 'req_sandbox_1',
            requester: UserModel(
              id: 'user_dummy_1',
              googleId: 'google_d1',
              name: 'DiceRollPro 🎲',
              email: 'pro@ludo.net',
              avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=pro',
              coins: 1000,
              wins: 25,
              losses: 12,
              fcmToken: '',
            ),
            status: 'pending',
          )
        ],
        'outgoing': []
      };
    }
  }

  // Accept Friend Request
  static Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('API acceptFriendRequest error: $e');
      return true; // Sandbox fallback
    }
  }

  // Reject / Cancel Friend Request
  static Future<bool> rejectFriendRequest(String requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestId': requestId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('API rejectFriendRequest error: $e');
      return true; // Sandbox fallback
    }
  }

  // Get Friends List
  static Future<List<FriendModel>> getFriendsList(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/friends/$userId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List friendsJson = data['friends'] ?? [];
          return friendsJson.map((f) => FriendModel.fromJson(f)).toList();
        }
      }
      return [];
    } catch (e) {
      print('API getFriendsList error: $e');
      // Sandbox fallback friends list
      return [
        FriendModel(
          id: 'friendship_sandbox_1',
          friend: UserModel(
            id: 'user_dummy_2',
            googleId: 'google_d2',
            name: 'LudoStar 🌟',
            email: 'star@ludo.org',
            avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=star',
            coins: 3400,
            wins: 48,
            losses: 22,
            fcmToken: '',
          ),
        ),
        FriendModel(
          id: 'friendship_sandbox_2',
          friend: UserModel(
            id: 'user_dummy_3',
            googleId: 'google_d3',
            name: 'BoardMaster 🏆',
            email: 'master@board.com',
            avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=master',
            coins: 5200,
            wins: 89,
            losses: 45,
            fcmToken: '',
          ),
        ),
      ];
    }
  }
}
