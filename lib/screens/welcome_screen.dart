import 'package:flutter/material.dart';
import '../utils/constants.dart';
// Import the InstructionItem class here to avoid circular dependency
import 'instruction_item.dart';

/// Welcome screen shown when the user first opens the AI assistant
class WelcomeScreen extends StatelessWidget {
  /// Whether the API key is set
  final bool isApiKeySet;

  /// Function to handle showing API key dialog
  final VoidCallback onShowApiKeyDialog;

  /// Function to handle PDF file picking
  final VoidCallback onPickPdf;

  /// Function to handle setting a sample message
  final Function(String) onSetSampleMessage;

  /// Loading state for PDF upload
  final bool isPdfLoading;

  /// Whether instructions should be shown
  final bool showInstructions;

  /// Function to toggle instructions
  final VoidCallback onToggleInstructions;

  /// Constructor
  const WelcomeScreen({
    Key? key,
    required this.isApiKeySet,
    required this.onShowApiKeyDialog,
    required this.onPickPdf,
    required this.onSetSampleMessage,
    required this.isPdfLoading,
    required this.showInstructions,
    required this.onToggleInstructions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main welcome content
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

                // AI Assistant logo/icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.smart_toy,
                      size: 72,
                      color: AppConstants.primaryColor.withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Welcome text
                const Text(
                  'Welcome to your AI Assistant',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'I can help you create assessments, analyze documents, and assist with your educational content.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // API Key setup card (if not set)
                if (!isApiKeySet)
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.vpn_key,
                              size: 36,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Set Up API Key',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'To use the AI assistant, you need to set up your Gemini API key. You can get an API key from Google AI Studio.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: onShowApiKeyDialog,
                              icon: const Icon(Icons.vpn_key),
                              label: const Text(
                                'Set API Key',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // PDF upload card
                Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            size: 36,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Upload a Document',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Upload a PDF document to generate assessment questions or analyze content.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                isApiKeySet ? onPickPdf : onShowApiKeyDialog,
                            icon:
                                isPdfLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.upload_file),
                            label: Text(
                              isPdfLoading ? 'Uploading...' : 'Select PDF',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Or divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey[300], thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Ask directly card
                Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat,
                            size: 36,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Ask Me Anything',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Type in the chat below to ask questions or get educational assistance.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                isApiKeySet
                                    ? () => onSetSampleMessage(
                                      'Hello, I need help with creating an assessment.',
                                    )
                                    : onShowApiKeyDialog,
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text(
                              'Start Chatting',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppConstants.primaryColor,
                              side: const BorderSide(
                                color: AppConstants.primaryColor,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),

        // Instructions overlay
        if (showInstructions) _buildInstructionsOverlay(onToggleInstructions),
      ],
    );
  }

  /// Build the instructions overlay
  Widget _buildInstructionsOverlay(VoidCallback onClose) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'How to Use the AI Assistant',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                const InstructionItem(
                  icon: Icons.vpn_key,
                  title: 'Set API Key',
                  description:
                      'First, set your Gemini API key from Google AI Studio to enable AI features.',
                ),
                const SizedBox(height: 16),
                const InstructionItem(
                  icon: Icons.upload_file,
                  title: 'Upload a Document',
                  description:
                      'Select a PDF document to generate assessment questions from or analyze.',
                ),
                const SizedBox(height: 16),
                const InstructionItem(
                  icon: Icons.settings,
                  title: 'Configure Options',
                  description:
                      'Set difficulty, total points, and select question types for generation.',
                ),
                const SizedBox(height: 16),
                const InstructionItem(
                  icon: Icons.auto_awesome,
                  title: 'Generate Questions',
                  description:
                      'Use the floating action button to generate assessment questions from your document.',
                ),
                const SizedBox(height: 16),
                const InstructionItem(
                  icon: Icons.chat,
                  title: 'Chat Directly',
                  description:
                      'Ask questions and get educational assistance through the chat interface.',
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: onClose,
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
