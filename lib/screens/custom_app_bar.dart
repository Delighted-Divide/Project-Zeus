import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Custom app bar for the AI assistant page
class AIAssistantAppBar extends StatelessWidget {
  /// Name of the PDF document (if loaded)
  final String? pdfName;

  /// Currently selected model
  final String selectedModel;

  /// Whether the API key is set
  final bool isApiKeySet;

  /// Function to handle model change
  final Function(String) onModelChanged;

  /// Function to show API key dialog
  final VoidCallback onShowApiKeyDialog;

  /// Function to toggle instructions
  final VoidCallback onToggleInstructions;

  /// Function to handle back button press
  final VoidCallback onBack;

  /// Constructor
  const AIAssistantAppBar({
    Key? key,
    this.pdfName,
    required this.selectedModel,
    required this.isApiKeySet,
    required this.onModelChanged,
    required this.onShowApiKeyDialog,
    required this.onToggleInstructions,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            splashRadius: 24,
          ),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
                if (pdfName != null)
                  Text(
                    pdfName!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Model selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButton<String>(
              value: selectedModel,
              underline: const SizedBox(),
              icon: const Icon(
                Icons.arrow_drop_down,
                color: AppConstants.primaryColor,
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppConstants.primaryColor,
              ),
              items:
                  AppConstants.availableModels
                      .map(
                        (model) => DropdownMenuItem(
                          value: model['value'],
                          child: Text(model['label'] ?? ''),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  onModelChanged(value);
                }
              },
            ),
          ),

          const SizedBox(width: 8),

          // API key button
          IconButton(
            icon: Icon(
              Icons.vpn_key,
              color: isApiKeySet ? AppConstants.successColor : Colors.orange,
            ),
            onPressed: onShowApiKeyDialog,
            tooltip: isApiKeySet ? 'Update API Key' : 'Set API Key',
            splashRadius: 24,
          ),

          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: onToggleInstructions,
            splashRadius: 24,
          ),
        ],
      ),
    );
  }
}
