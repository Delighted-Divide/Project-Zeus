class ChatMessage {
  final String role;
  final String content;
  final int timestamp;
  final bool hasAttachment;
  final String? attachmentType;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.hasAttachment = false,
    this.attachmentType,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      role: map['role'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      hasAttachment: map['hasAttachment'] ?? false,
      attachmentType: map['attachmentType'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp,
      'hasAttachment': hasAttachment,
      if (attachmentType != null) 'attachmentType': attachmentType,
    };
  }

  static ChatMessage user(String content) {
    return ChatMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static ChatMessage assistant(
    String content, {
    bool hasAttachment = false,
    String? attachmentType,
  }) {
    return ChatMessage(
      role: 'assistant',
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      hasAttachment: hasAttachment,
      attachmentType: attachmentType,
    );
  }
}
