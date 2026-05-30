class UserModel {
  final String id;
  final String googleId;
  final String name;
  final String email;
  final String avatarUrl;
  int coins;
  final int wins;
  final int losses;
  final String fcmToken;

  UserModel({
    required this.id,
    required this.googleId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.coins,
    required this.wins,
    required this.losses,
    required this.fcmToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? '',
      googleId: json['googleId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      coins: json['coins'] ?? 1000,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      fcmToken: json['fcmToken'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'googleId': googleId,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'coins': coins,
      'wins': wins,
      'losses': losses,
      'fcmToken': fcmToken,
    };
  }
}
