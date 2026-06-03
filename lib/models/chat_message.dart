class ChatMessage {
  final String id;
  final String role; // 'user' or 'model'
  final String message;
  final String timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'message': message,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      role: map['role'] as String,
      message: map['message'] as String,
      timestamp: map['timestamp'] as String,
    );
  }
}
