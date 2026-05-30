class ChatMessage {
  final String senderName;
  final String message;
  final bool isEmoji;
  final DateTime timestamp;

  ChatMessage({
    required this.senderName,
    required this.message,
    this.isEmoji = false,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      senderName: json['senderName'] ?? '',
      message: json['message'] ?? '',
      isEmoji: json['isEmoji'] ?? false,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }
}
