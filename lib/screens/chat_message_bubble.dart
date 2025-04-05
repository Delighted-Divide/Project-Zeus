import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';
import '../utils/constants.dart';

/// A chat message bubble component
class ChatMessageBubble extends StatelessWidget {
  /// The chat message to display
  final ChatMessage message;

  /// Function to copy text to clipboard
  final Function(String) onCopy;

  /// Constructor
  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.onCopy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final time = DateTime.fromMillisecondsSinceEpoch(message.timestamp);
    final timeString = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Card(
          color: isUser ? AppConstants.primaryColor : Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message content
                isUser
                    ? Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    )
                    : MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(
                        p: const TextStyle(fontSize: 15, height: 1.4),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                // Timestamp and actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment:
                      isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isUser
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey,
                      ),
                    ),
                    if (!isUser)
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => onCopy(message.content),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        splashRadius: 16,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
