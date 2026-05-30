import 'user_model.dart';

class FriendModel {
  final String id; // friendship ID
  final UserModel friend;

  FriendModel({
    required this.id,
    required this.friend,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['_id'] ?? '',
      friend: UserModel.fromJson(json['friend'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'friend': friend.toJson(),
    };
  }
}

class FriendRequestModel {
  final String id; // friendship ID
  final UserModel requester;
  final String status;

  FriendRequestModel({
    required this.id,
    required this.requester,
    required this.status,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['_id'] ?? '',
      requester: UserModel.fromJson(json['requester'] ?? {}),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'requester': requester.toJson(),
      'status': status,
    };
  }
}
