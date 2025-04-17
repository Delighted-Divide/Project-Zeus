import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onUploadFile;
  final bool isApiKeySet;
  final VoidCallback onShowApiKeyDialog;
  final bool isLoading;

  const ChatInput({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.onUploadFile,
    required this.isApiKeySet,
    required this.onShowApiKeyDialog,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed:
                  isApiKeySet
                      ? onUploadFile
                      : () {
                        onShowApiKeyDialog();
                      },
              tooltip: 'Upload PDF',
              color: AppConstants.primaryColor,
              splashRadius: 24,
            ),

            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Ask AI Assistant...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),

            Container(
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: IconButton(
                icon:
                    isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.send, color: Colors.white),
                onPressed: isLoading ? null : onSend,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
