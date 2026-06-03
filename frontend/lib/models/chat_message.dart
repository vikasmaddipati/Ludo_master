class ChatMessage {
  final String id;
  final String senderName;
  final String message;
  final bool isEmoji;
  final DateTime timestamp;
  final String status; // 'sending', 'delivered', 'read'

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.message,
    this.isEmoji = false,
    required this.timestamp,
    this.status = 'delivered',
  });

  bool get isDelivered => status == 'delivered' || status == 'read';
  bool get isRead => status == 'read';

  ChatMessage copyWith({
    String? id,
    String? senderName,
    String? message,
    bool? isEmoji,
    DateTime? timestamp,
    String? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      isEmoji: isEmoji ?? this.isEmoji,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      senderName: json['senderName'] ?? '',
      message: json['message'] ?? '',
      isEmoji: json['isEmoji'] ?? false,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      status: json['status'] ?? (json['isDelivered'] == false ? 'sending' : 'delivered'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderName': senderName,
    'message': message,
    'isEmoji': isEmoji,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
  };
}
