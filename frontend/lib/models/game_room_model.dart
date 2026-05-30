class PlayerModel {
  final String userId;
  final String name;
  final String color;
  final bool isBot;
  bool isReady;
  final bool isConnected;

  PlayerModel({
    required this.userId,
    required this.name,
    required this.color,
    required this.isBot,
    required this.isReady,
    required this.isConnected,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      color: json['color'] ?? 'red',
      isBot: json['isBot'] ?? false,
      isReady: json['isReady'] ?? false,
      isConnected: json['isConnected'] ?? true,
    );
  }
}

class LudoTokenModel {
  final String color;
  final int tokenId;
  int position;

  LudoTokenModel({
    required this.color,
    required this.tokenId,
    required this.position,
  });

  factory LudoTokenModel.fromJson(Map<String, dynamic> json) {
    return LudoTokenModel(
      color: json['color'] ?? 'red',
      tokenId: json['tokenId'] ?? 0,
      position: json['position'] ?? -1,
    );
  }
}

class GameRoomModel {
  final String id;
  final String roomCode;
  final String creator;
  String status; // 'waiting', 'playing', 'finished'
  List<PlayerModel> players;
  List<LudoTokenModel> tokens;
  String turn; // 'red', 'green', 'yellow', 'blue'
  int diceValue;
  bool hasRolled;
  String? winnerId;

  GameRoomModel({
    required this.id,
    required this.roomCode,
    required this.creator,
    required this.status,
    required this.players,
    required this.tokens,
    required this.turn,
    required this.diceValue,
    required this.hasRolled,
    this.winnerId,
  });

  factory GameRoomModel.fromJson(Map<String, dynamic> json) {
    var playerList = json['players'] as List? ?? [];
    List<PlayerModel> players = playerList.map((i) => PlayerModel.fromJson(i)).toList();

    var tokenList = json['tokens'] as List? ?? [];
    List<LudoTokenModel> tokens = tokenList.map((i) => LudoTokenModel.fromJson(i)).toList();

    return GameRoomModel(
      id: json['_id'] ?? '',
      roomCode: json['roomCode'] ?? '',
      creator: json['creator'] ?? '',
      status: json['status'] ?? 'waiting',
      players: players,
      tokens: tokens,
      turn: json['turn'] ?? 'red',
      diceValue: json['diceValue'] ?? 1,
      hasRolled: json['hasRolled'] ?? false,
      winnerId: json['winnerId'],
    );
  }
}
