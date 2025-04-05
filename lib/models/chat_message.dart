/// Model representing a chat message in the AI assistant
class ChatMessage {
  /// The role of the sender (user or assistant)
  final String role;

  /// The content of the message
  final String content;

  /// Timestamp of when the message was created
  final int timestamp;

  /// Whether the message has an attachment
  final bool hasAttachment;

  /// The type of attachment if present
  final String? attachmentType;

  /// Constructor
  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.hasAttachment = false,
    this.attachmentType,
  });

  /// Create a message from a map
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      role: map['role'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      hasAttachment: map['hasAttachment'] ?? false,
      attachmentType: map['attachmentType'],
    );
  }

  /// Convert message to a map
  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'timestamp': timestamp,
      'hasAttachment': hasAttachment,
      if (attachmentType != null) 'attachmentType': attachmentType,
    };
  }

  /// Create a user message
  static ChatMessage user(String content) {
    return ChatMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Create an assistant message
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
