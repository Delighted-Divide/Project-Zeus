import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isImage;
  final bool isDocument;
  final String? mediaUrl;
  final String? documentName;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isImage = false,
    this.isDocument = false,
    this.mediaUrl,
    this.documentName,
  });

  factory ChatMessage.fromRealtime(Map<dynamic, dynamic> data, String id) {
    int timestampValue =
        data['timestamp'] is int
            ? data['timestamp']
            : DateTime.now().millisecondsSinceEpoch;

    DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(timestampValue);

    return ChatMessage(
      id: id,
      sender: data['sender'] ?? '',
      text: data['text'] ?? '',
      timestamp: messageTime,
      isImage: data['isImage'] ?? false,
      isDocument: data['isDocument'] ?? false,
      mediaUrl: data['mediaUrl'],
      documentName: data['documentName'],
    );
  }

  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(timestamp)}';
    } else {
      return DateFormat('dd/MM HH:mm').format(timestamp);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isImage': isImage,
      'isDocument': isDocument,
      'mediaUrl': mediaUrl,
      'documentName': documentName,
    };
  }
}
