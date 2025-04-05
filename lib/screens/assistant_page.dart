import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

// Services
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';

// Models
import '../models/chat_message.dart';

// Utils
import '../utils/constants.dart';

// Components
import 'chat_message_bubble.dart';
import 'assessment_view.dart';
import 'instruction_item.dart';
import 'welcome_screen.dart';
import 'onboarding_screen.dart';
import 'pdf_options_dialog.dart';
import 'chat_input.dart';
import 'custom_app_bar.dart';

/// Enhanced AI Assistant page with PDF processing capabilities
class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage>
    with SingleTickerProviderStateMixin {
  // Logger instance for better debugging
  final Logger _logger = Logger();

  // Services
  late final StorageService _storageService;
  late final PdfService _pdfService;
  late ApiService? _apiService;

  // Animation controller for UI animations
  late AnimationController _animationController;

  // Controllers
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PageController _onboardingController = PageController();
  final TextEditingController _difficultyController = TextEditingController(
    text: 'medium',
  );
  final TextEditingController _pointsController = TextEditingController(
    text: '100',
  );
  final TextEditingController _customPromptController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  // UI state variables
  bool _isLoading = false;
  bool _isPdfLoading = false;
  bool _isPdfProcessing = false;
  bool _isGeneratingQuestions = false;
  bool _isFirstTime = true;
  String _response = '';
  List<ChatMessage> _chatHistory = [];
  String? _errorMessage;
  String _selectedModel = 'gemini-2.5-pro-preview-03-25';
  bool _showInstructions = false;
  bool _isApiKeySet = false;

  // PDF handling variables
  File? _pdfFile;
  String? _pdfName;
  String? _pdfUrl;
  int _pdfPageCount = 0;
  RangeValues _pageRange = const RangeValues(1, 1);
  String _extractedTextPreview = '';
  String? _extractedFullText;

  // Question generation options
  List<String> _selectedQuestionTypes = [
    'multiple-choice',
    'multiple-answer',
    'true-false',
    'fill-in-the-blank',
    'short-answer',
  ];

  // Question type counts
  final Map<String, TextEditingController> _questionTypeCounts = {
    'multiple-choice': TextEditingController(text: '5'),
    'multiple-answer': TextEditingController(text: '3'),
    'true-false': TextEditingController(text: '4'),
    'fill-in-the-blank': TextEditingController(text: '3'),
    'short-answer': TextEditingController(text: '2'),
  };

  // Total points (calculated dynamically)
  int _totalPoints = 0;

  // Generated content
  Map<String, dynamic>? _generatedQuestions;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _storageService = StorageService();
    _pdfService = PdfService();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Check if this is the first time opening the AI assistant
    _checkFirstTimeUser();

    // Check for stored API key
    _loadApiKey();

    // Calculate initial total points
    _calculateTotalPoints();
  }

  /// Calculate total assessment points based on question type counts
  void _calculateTotalPoints() {
    int total = 0;

    for (final type in _selectedQuestionTypes) {
      // Get the number of questions for this type
      final countText = _questionTypeCounts[type]?.text ?? '0';
      final count = int.tryParse(countText) ?? 0;

      // Get points per question for this type
      final pointsPerQuestion = AppConstants.questionTypePoints[type] ?? 1;

      // Add to total
      total += count * pointsPerQuestion;
    }

    setState(() {
      _totalPoints = total;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _onboardingController.dispose();
    _difficultyController.dispose();
    _pointsController.dispose();
    _customPromptController.dispose();
    _apiKeyController.dispose();
    _animationController.dispose();

    // Dispose all question type count controllers
    _questionTypeCounts.forEach((_, controller) => controller.dispose());

    super.dispose();
  }

  /// Load Gemini API key from secure storage
  Future<void> _loadApiKey() async {
    final apiKey = await _storageService.loadApiKey();

    if (apiKey != null && apiKey.isNotEmpty) {
      setState(() {
        _isApiKeySet = true;
        _apiService = ApiService(apiKey);
      });
      _logger.i('API key loaded from secure storage');
    } else {
      _logger.i('No API key found in secure storage');
      setState(() {
        _isApiKeySet = false;
        _apiService = null;
      });
    }
  }

  /// Show dialog to set or update API key
  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isApiKeySet ? 'Update API Key' : 'Set Gemini API Key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your Gemini API key to use the AI features. You can get an API key from the Google AI Studio.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                    hintText: 'Enter Gemini API key',
                  ),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final apiKey = _apiKeyController.text.trim();
                  if (apiKey.isNotEmpty) {
                    _saveApiKey(apiKey);
                    Navigator.pop(context);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('API key saved successfully'),
                        backgroundColor: AppConstants.successColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  /// Save API key
  Future<void> _saveApiKey(String apiKey) async {
    final success = await _storageService.saveApiKey(apiKey);

    if (success) {
      setState(() {
        _isApiKeySet = true;
        _apiService = ApiService(apiKey);
      });

      // Clear the field
      _apiKeyController.clear();
    } else {
      setState(() {
        _errorMessage = 'Failed to save API key. Please try again.';
      });
    }
  }

  /// Check if this is the first time the user is opening the AI assistant
  Future<void> _checkFirstTimeUser() async {
    final isFirstTime = await _storageService.checkFirstTimeUser();

    setState(() {
      _isFirstTime = isFirstTime;
    });
  }

  /// Send a prompt directly to the Gemini API
  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    if (!_isApiKeySet || _apiService == null) {
      setState(() {
        _errorMessage = 'Please set your Gemini API key first';
      });
      _showApiKeyDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Sending prompt directly to Gemini API');

      // Add user message to chat history
      final userMessage = ChatMessage.user(prompt);
      setState(() {
        _chatHistory.add(userMessage);
      });

      // Send prompt to API
      final responseText = await _apiService!.sendPrompt(
        prompt,
        _selectedModel,
      );

      // Add assistant response to chat history
      final assistantMessage = ChatMessage.assistant(responseText);
      setState(() {
        _response = responseText;
        _chatHistory.add(assistantMessage);
        _isLoading = false;
      });

      // Clear the prompt field
      _promptController.clear();

      // Scroll to bottom of chat
      _scrollToBottom();

      _logger.i('Received response from Gemini API');
    } catch (e) {
      _logger.e('Error sending prompt to Gemini API', error: e);
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Select and load a PDF file
  Future<void> _pickPdfFile() async {
    if (!mounted) return; // Guard against widget being disposed

    setState(() {
      _isPdfLoading = true;
      _errorMessage = null;
    });

    try {
      // Use PDF service to pick a file
      final pdfData = await _pdfService.pickPdfFile();

      if (pdfData != null && mounted) {
        final pdfFile = pdfData['file'] as File;
        final fileName = pdfData['name'] as String;
        final pageCount = pdfData['pageCount'] as int;

        setState(() {
          _pdfFile = pdfFile;
          _pdfName = fileName;
          _pdfPageCount = pageCount;
          _pageRange = RangeValues(1, pageCount.toDouble());
        });

        // Upload PDF to Firebase Storage
        await _uploadPdfToStorage(pdfFile, fileName);
      } else {
        _logger.i('No PDF file selected');
      }
    } catch (e) {
      _logger.e('Error picking PDF file', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error selecting PDF: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPdfLoading = false;
        });
      }
    }
  }

  /// Upload PDF to Firebase Storage
  Future<void> _uploadPdfToStorage(File pdfFile, String fileName) async {
    if (!mounted) return; // Guard against widget being disposed

    try {
      _logger.i('Uploading PDF to Firebase Storage');

      // Use storage service to upload the file
      final downloadUrl = await _storageService.uploadPdfToStorage(
        pdfFile,
        fileName,
      );

      if (downloadUrl != null && mounted) {
        setState(() {
          _pdfUrl = downloadUrl;
        });

        // Add message to chat history
        setState(() {
          _chatHistory.add(ChatMessage.user('I\'ve uploaded a PDF: $_pdfName'));
          _chatHistory.add(
            ChatMessage.assistant(
              'I see you\'ve uploaded "$_pdfName" with $_pdfPageCount pages. You can now select a page range and generate assessment questions from this document.',
            ),
          );
        });

        // Scroll to bottom of chat
        _scrollToBottom();
      } else {
        throw Exception('Failed to upload PDF');
      }
    } catch (e) {
      _logger.e('Error uploading PDF to storage', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Error uploading PDF: $e';
        });
      }
    }
  }

  /// Extract text from PDF
  Future<String> _extractTextFromPdf() async {
    if (_pdfFile == null) {
      throw Exception('No PDF file selected');
    }

    setState(() {
      _isPdfProcessing = true;
    });

    try {
      // Use PDF service to extract text
      final extractedText = await _pdfService.extractTextFromPdf(
        _pdfFile!,
        _pageRange,
      );

      // Set preview text
      setState(() {
        _extractedTextPreview =
            extractedText.length > 500
                ? '${extractedText.substring(0, 500)}...'
                : extractedText;
        _extractedFullText = extractedText;
      });

      return extractedText;
    } catch (e) {
      _logger.e('Error extracting text from PDF', error: e);
      throw Exception('Failed to extract text from PDF: $e');
    } finally {
      setState(() {
        _isPdfProcessing = false;
      });
    }
  }

  /// Generate assessment questions based on the extracted PDF text
  Future<void> _generateAssessmentQuestions() async {
    if (_pdfFile == null) {
      setState(() {
        _errorMessage = 'Please upload a PDF document first';
      });
      return;
    }

    if (!_isApiKeySet || _apiService == null) {
      setState(() {
        _errorMessage = 'Please set your Gemini API key first';
      });
      _showApiKeyDialog();
      return;
    }

    // Calculate total points
    _calculateTotalPoints();

    // Check if user has selected at least one question type with count > 0
    bool hasQuestions = false;
    for (final type in _selectedQuestionTypes) {
      final count = int.tryParse(_questionTypeCounts[type]?.text ?? '0') ?? 0;
      if (count > 0) {
        hasQuestions = true;
        break;
      }
    }

    if (!hasQuestions) {
      setState(() {
        _errorMessage =
            'Please set at least one question type with count greater than 0';
      });
      return;
    }

    setState(() {
      _isGeneratingQuestions = true;
      _errorMessage = null;
      _generatedQuestions = null;
    });

    try {
      _logger.i('Starting assessment question generation');

      // Get parameters
      final difficulty = _difficultyController.text.trim().toLowerCase();

      // Create question distribution information
      final questionDistribution = <String, int>{};
      for (final type in _selectedQuestionTypes) {
        final countText = _questionTypeCounts[type]?.text ?? '0';
        final count = int.tryParse(countText) ?? 0;
        questionDistribution[type] = count;
      }

      // Extract text from PDF locally if not already done
      if (_extractedFullText == null || _extractedFullText!.isEmpty) {
        await _extractTextFromPdf();
      }

      if (_extractedFullText == null || _extractedFullText!.isEmpty) {
        throw Exception('No text could be extracted from the selected pages');
      }

      // Generate questions using API service
      final generatedQuestions = await _apiService!.generateAssessmentQuestions(
        extractedText: _extractedFullText!,
        difficulty: difficulty,
        questionDistribution: questionDistribution,
        questionTypePoints: AppConstants.questionTypePoints,
        totalPoints: _totalPoints,
        modelName: _selectedModel,
        pageRange: _pageRange,
      );

      setState(() {
        _generatedQuestions = generatedQuestions;
      });

      _logger.i('Assessment questions generated successfully');

      // Add to chat history
      setState(() {
        _chatHistory.add(
          ChatMessage.user(
            'Generate assessment questions for pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()} with difficulty $difficulty',
          ),
        );

        _chatHistory.add(
          ChatMessage.assistant(
            'I\'ve generated a set of assessment questions based on the content. There are ${_generatedQuestions!['questions'].length} questions with a total of $_totalPoints points. You can review all questions and answers below.',
            hasAttachment: true,
            attachmentType: 'assessment',
          ),
        );
      });

      // Scroll to bottom of chat
      _scrollToBottom();
    } catch (e) {
      _logger.e('Error generating assessment questions', error: e);
      setState(() {
        _errorMessage = 'Error generating questions: $e';
      });
    } finally {
      setState(() {
        _isGeneratingQuestions = false;
      });
    }
  }

  /// Save generated questions and answers to Firestore
  Future<void> _saveAssessmentToFirestore() async {
    if (_generatedQuestions == null || _pdfName == null || _pdfUrl == null) {
      setState(() {
        _errorMessage = 'No questions generated or document loaded';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use storage service to save assessment
      final success = await _storageService.saveAssessmentToFirestore(
        _generatedQuestions!,
        pdfName: _pdfName!,
        pdfUrl: _pdfUrl!,
        pageRange: _pageRange,
        difficulty: _difficultyController.text,
        totalPoints: _totalPoints,
      );

      if (success) {
        _logger.i('Assessment saved successfully');

        // Add success message to chat history
        setState(() {
          _chatHistory.add(
            ChatMessage.assistant(
              'Assessment saved successfully! You can now find it in your assessments list.',
            ),
          );
        });

        // Scroll to bottom of chat
        _scrollToBottom();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assessment saved successfully!'),
            backgroundColor: AppConstants.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Reset generated questions
        setState(() {
          _generatedQuestions = null;
        });
      } else {
        throw Exception('Failed to save assessment');
      }
    } catch (e) {
      _logger.e('Error saving assessment to Firestore', error: e);
      setState(() {
        _errorMessage = 'Error saving assessment: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Scroll to the bottom of the chat history
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Copy text to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstTime) {
      return OnboardingScreen(
        controller: _onboardingController,
        onComplete: () {
          setState(() {
            _isFirstTime = false;
          });
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            AIAssistantAppBar(
              pdfName: _pdfName,
              selectedModel: _selectedModel,
              isApiKeySet: _isApiKeySet,
              onModelChanged: (value) {
                setState(() {
                  _selectedModel = value;
                });
              },
              onShowApiKeyDialog: _showApiKeyDialog,
              onToggleInstructions: () {
                setState(() {
                  _showInstructions = !_showInstructions;
                });
              },
              onBack: () => Navigator.pop(context),
            ),

            // Chat messages area
            Expanded(
              child:
                  _chatHistory.isEmpty
                      ? WelcomeScreen(
                        isApiKeySet: _isApiKeySet,
                        onShowApiKeyDialog: _showApiKeyDialog,
                        onPickPdf: _pickPdfFile,
                        onSetSampleMessage: (message) {
                          setState(() {
                            _promptController.text = message;
                          });
                        },
                        isPdfLoading: _isPdfLoading,
                        showInstructions: _showInstructions,
                        onToggleInstructions: () {
                          setState(() {
                            _showInstructions = !_showInstructions;
                          });
                        },
                      )
                      : _buildChatMessages(),
            ),

            // Error message display
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppConstants.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: AppConstants.errorColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppConstants.errorColor),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: AppConstants.errorColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Input area
            ChatInput(
              controller: _promptController,
              onSend: _sendPrompt,
              onUploadFile: _pickPdfFile,
              isApiKeySet: _isApiKeySet,
              onShowApiKeyDialog: () {
                setState(() {
                  _errorMessage = 'Please set your API key first';
                });
                _showApiKeyDialog();
              },
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
      floatingActionButton:
          _pdfFile != null
              ? FloatingActionButton(
                onPressed: _showPdfOptionsDialog,
                backgroundColor: AppConstants.primaryColor,
                child: const Icon(Icons.settings),
              )
              : null,
    );
  }

  /// Build the chat messages list
  Widget _buildChatMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final message = _chatHistory[index];

        // Handle special assistant messages with attachments
        if (message.role == 'assistant' && message.hasAttachment) {
          if (message.attachmentType == 'assessment' &&
              _generatedQuestions != null) {
            return AssessmentView(
              generatedQuestions: _generatedQuestions!,
              onSave: _saveAssessmentToFirestore,
              isLoading: _isLoading,
              documentName: _pdfName ?? 'Document',
              pageRange: _pageRange,
              totalPoints: _totalPoints,
              difficulty: _difficultyController.text,
            );
          }
        }

        return ChatMessageBubble(message: message, onCopy: _copyToClipboard);
      },
    );
  }

  /// Show the PDF options dialog
  void _showPdfOptionsDialog() {
    if (_pdfFile == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => PdfOptionsDialog(
            pdfName: _pdfName ?? 'PDF Document',
            pdfPageCount: _pdfPageCount,
            pageRange: _pageRange,
            difficulty: _difficultyController.text,
            selectedQuestionTypes: _selectedQuestionTypes,
            questionTypeCounts: _questionTypeCounts,
            onPageRangeChanged: (values) {
              setState(() {
                _pageRange = values;
              });
            },
            onDifficultyChanged: (value) {
              setState(() {
                _difficultyController.text = value;
              });
            },
            onSelectedQuestionTypesChanged: (types) {
              setState(() {
                _selectedQuestionTypes = types;
              });
            },
            onGenerateQuestions: _generateAssessmentQuestions,
          ),
    );
  }
}
