import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

/// Enhanced AI Assistant page with PDF processing capabilities
class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage>
    with SingleTickerProviderStateMixin {
  // Logger instance for better debugging
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Uuid _uuid = Uuid();

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

  // UI state variables
  bool _isLoading = false;
  bool _isPdfLoading = false;
  bool _isPdfProcessing = false;
  bool _isGeneratingQuestions = false;
  bool _isFirstTime = true;
  String _response = '';
  List<Map<String, dynamic>> _chatHistory = [];
  String? _errorMessage;
  String _selectedModel = 'gemini-2.5-pro';
  bool _showInstructions = false;

  // PDF handling variables
  File? _pdfFile;
  String? _pdfName;
  String? _pdfUrl;
  int _pdfPageCount = 0;
  RangeValues _pageRange = const RangeValues(1, 1);
  String _extractedTextPreview = '';

  // Question generation options
  final List<String> _difficultyLevels = ['easy', 'medium', 'hard', 'expert'];
  final List<String> _questionTypes = [
    'multiple-choice',
    'multiple-answer',
    'true-false',
    'fill-in-the-blank',
    'short-answer',
  ];
  List<String> _selectedQuestionTypes = [
    'multiple-choice',
    'multiple-answer',
    'true-false',
    'fill-in-the-blank',
    'short-answer',
  ];

  // Generated content
  Map<String, dynamic>? _generatedQuestions;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Check if this is the first time opening the AI assistant
    _checkFirstTimeUser();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _onboardingController.dispose();
    _difficultyController.dispose();
    _pointsController.dispose();
    _customPromptController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Check if this is the first time the user is opening the AI assistant
  Future<void> _checkFirstTimeUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          setState(() {
            _isFirstTime = userData?['hasUsedAIAssistant'] != true;
          });

          // If this is the first time, show onboarding
          if (_isFirstTime) {
            // Mark that user has used AI assistant
            await _firestore.collection('users').doc(currentUser.uid).update({
              'hasUsedAIAssistant': true,
            });
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error checking first time user',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send a prompt to the Gemini API through Firebase Cloud Functions
  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Sending prompt to Gemini API via Cloud Function');

      // Add user message to chat history
      _chatHistory.add({
        'role': 'user',
        'content': prompt,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Add more detailed logging before the call
      _logger.i('Sending prompt to Gemini API via Cloud Function with params:');
      _logger.i('Prompt: ${prompt.substring(0, min(50, prompt.length))}...');
      _logger.i('Model: $_selectedModel');
      _logger.i('MaxTokens: 1024');
      _logger.i('Temperature: 0.7');

      // Ensure data is properly formatted
      final paramsMap = {
        'prompt': prompt,
        'model': _selectedModel,
        'maxTokens': 1024,
        'temperature': 0.7,
      };

      // Log the exact params being sent
      _logger.i('Params map: $paramsMap');

      // Call Firebase Cloud Function
      final result = await _functions.httpsCallable('callGeminiApi').call({
        'prompt': prompt,
        'model': _selectedModel,
        'maxTokens': 1024,
        'temperature': 0.7,
      });

      final data = result.data;

      if (data['success']) {
        final responseText = data['text'] ?? 'No response received';

        // Add assistant response to chat history
        _chatHistory.add({
          'role': 'assistant',
          'content': responseText,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        setState(() {
          _response = responseText;
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? 'Unknown error occurred');
      }

      // Clear the prompt field
      _promptController.clear();

      // Scroll to bottom of chat
      _scrollToBottom();

      _logger.i('Received response from Gemini API');
    } catch (e, stackTrace) {
      _logger.e(
        'Error sending prompt to Gemini API',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  /// Select and load a PDF file
  /// Select and load a PDF file
  Future<void> _pickPdfFile() async {
    if (!mounted) return; // Guard against widget being disposed

    setState(() {
      _isPdfLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Opening file picker for PDF selection');

      // Open file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;

        if (file.path != null) {
          _logger.i('PDF selected: ${file.name}');

          final pdfFile = File(file.path!);

          // Load the PDF document to get page count
          final pdfBytes = await pdfFile.readAsBytes();
          final document = PdfDocument(inputBytes: pdfBytes);
          final pageCount = document.pages.count;
          document.dispose();

          if (mounted) {
            setState(() {
              _pdfFile = pdfFile;
              _pdfName = file.name;
              _pdfPageCount = pageCount;
              _pageRange = RangeValues(1, pageCount.toDouble());
            });

            // Upload PDF to Firebase Storage
            await _uploadPdfToStorage(pdfFile, file.name);
          }

          _logger.i('PDF loaded successfully with $pageCount pages');
        } else if (file.bytes != null && mounted) {
          // Handle in-memory file for web platform
          _logger.i('PDF selected (web): ${file.name}');

          // Save bytes to temporary file for processing
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/${file.name}');
          await tempFile.writeAsBytes(file.bytes!);

          // Load the PDF document to get page count
          final document = PdfDocument(inputBytes: file.bytes!);
          final pageCount = document.pages.count;
          document.dispose();

          if (mounted) {
            setState(() {
              _pdfFile = tempFile;
              _pdfName = file.name;
              _pdfPageCount = pageCount;
              _pageRange = RangeValues(1, pageCount.toDouble());
            });

            // Upload PDF to Firebase Storage
            await _uploadPdfToStorage(tempFile, file.name);
          }

          _logger.i('PDF loaded successfully with $pageCount pages');
        }
      } else {
        _logger.i('No PDF file selected');
      }
    } catch (e, stackTrace) {
      _logger.e('Error picking PDF file', error: e, stackTrace: stackTrace);
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

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create a storage reference
      final storageRef = _storage.ref().child(
        'pdfs/${currentUser.uid}/$fileName',
      );

      // Upload the file
      final uploadTask = storageRef.putFile(pdfFile);

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        _logger.d('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // Wait for the upload to complete
      final snapshot = await uploadTask.whenComplete(() => null);

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _pdfUrl = downloadUrl;
        });

        // Add message to chat history
        _chatHistory.add({
          'role': 'user',
          'content': 'I\'ve uploaded a PDF: $_pdfName',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        _chatHistory.add({
          'role': 'assistant',
          'content':
              'I see you\'ve uploaded "$_pdfName" with $_pdfPageCount pages. You can now select a page range and generate assessment questions from this document.',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        // Scroll to bottom of chat
        _scrollToBottom();
      }

      _logger.i('PDF uploaded successfully, URL: $downloadUrl');
    } catch (e, stackTrace) {
      _logger.e(
        'Error uploading PDF to storage',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() {
          _errorMessage = 'Error uploading PDF: $e';
        });
      }
    }
  }

  /// Extract text from PDF using Cloud Function
  Future<String> _extractTextFromPdf() async {
    if (_pdfFile == null || _pdfUrl == null) {
      throw Exception('No PDF file selected');
    }

    setState(() {
      _isPdfProcessing = true;
    });

    try {
      _logger.i('Extracting text from PDF using SyncFusion');

      // Load the PDF document
      final bytes = await _pdfFile!.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      // Extract text from selected pages
      final startPage = _pageRange.start.toInt();
      final endPage = _pageRange.end.toInt();

      // Create PDF text extractor
      final extractor = PdfTextExtractor(document);

      // Extract text from specific pages
      String extractedText = '';
      for (int i = startPage; i <= endPage; i++) {
        // Page numbers in SyncFusion are 1-based
        final pageText = extractor.extractText(
          startPageIndex: i - 1,
          endPageIndex: i - 1,
        );
        extractedText += 'Page $i:\n$pageText\n\n';
      }

      // Dispose the document
      document.dispose();

      // Set preview text
      setState(() {
        _extractedTextPreview =
            extractedText.length > 500
                ? '${extractedText.substring(0, 500)}...'
                : extractedText;
      });

      _logger.i(
        'Successfully extracted ${extractedText.length} characters from PDF',
      );
      return extractedText;
    } catch (e, stackTrace) {
      _logger.e(
        'Error extracting text from PDF',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Failed to extract text from PDF: $e');
    } finally {
      setState(() {
        _isPdfProcessing = false;
      });
    }
  }

  /// Generate assessment questions based on the extracted PDF text
  Future<void> _generateAssessmentQuestions() async {
    if (_pdfFile == null || _pdfUrl == null) {
      setState(() {
        _errorMessage = 'Please upload a PDF document first';
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
      final totalPoints = int.tryParse(_pointsController.text) ?? 100;

      // Extract text from PDF
      final extractedText = await _extractTextFromPdf();

      if (extractedText.isEmpty) {
        throw Exception('No text could be extracted from the selected pages');
      }

      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      print("Current user: ${FirebaseAuth.instance.currentUser?.uid}");
      print("Is user null? ${FirebaseAuth.instance.currentUser == null}");

      // Call Firebase Cloud Function for question generation
      final result = await _functions
          .httpsCallable('extractPdfTextAndGenerateQuestions')
          .call({
            'fileUrl': _pdfUrl,
            'startPage': _pageRange.start.toInt(),
            'endPage': _pageRange.end.toInt(),
            'difficulty': difficulty,
            'totalPoints': totalPoints,
            'questionTypes': _selectedQuestionTypes,
          });

      final data = result.data;

      if (data['success']) {
        setState(() {
          _generatedQuestions = data['generatedQuestions'];
        });

        _logger.i('Assessment questions generated successfully');

        // Add to chat history
        _chatHistory.add({
          'role': 'user',
          'content':
              'Generate assessment questions for pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()} with difficulty $difficulty and total points $totalPoints',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        _chatHistory.add({
          'role': 'assistant',
          'content':
              'I\'ve generated a set of assessment questions based on the content. There are ${_generatedQuestions!['questions'].length} questions with a total of $totalPoints points. Would you like to save these questions to your database?',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'hasAttachment': true,
          'attachmentType': 'assessment',
        });

        // Scroll to bottom of chat
        _scrollToBottom();
      } else {
        throw Exception(data['error'] ?? 'Failed to generate questions');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error generating assessment questions',
        error: e,
        stackTrace: stackTrace,
      );
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
    if (_generatedQuestions == null || _pdfName == null) {
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
      _logger.i('Saving assessment to Firestore');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Create assessment document
      final assessmentId = _uuid.v4();
      final assessmentRef = _firestore
          .collection('assessments')
          .doc(assessmentId);

      // Basic assessment data
      await assessmentRef.set({
        'title': 'Assessment on $_pdfName',
        'creatorId': currentUser.uid,
        'sourceDocumentId': _pdfUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'description':
            'Generated from pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()} of $_pdfName',
        'difficulty': _difficultyController.text,
        'isPublic': false,
        'totalPoints': int.tryParse(_pointsController.text) ?? 100,
        'tags':
            _generatedQuestions!['tags'].map((tag) => tag['tagId']).toList(),
        'rating': 0,
        'madeByAI': true,
      });

      // Add questions
      final questions = _generatedQuestions!['questions'] as List<dynamic>;
      for (final question in questions) {
        await assessmentRef
            .collection('questions')
            .doc(question['questionId'])
            .set({
              'questionType': question['questionType'],
              'questionText': question['questionText'],
              'options': question['options'] ?? [],
              'points': question['points'],
            });
      }

      // Add answers
      final answers = _generatedQuestions!['answers'] as List<dynamic>;
      for (final answer in answers) {
        await assessmentRef.collection('answers').doc(answer['answerId']).set({
          'questionId': answer['questionId'],
          'answerType': answer['answerType'],
          'answerText': answer['answerText'],
          'reasoning': answer['reasoning'],
        });
      }

      // Save tags to tags collection if they don't exist
      final tags = _generatedQuestions!['tags'] as List<dynamic>;
      for (final tag in tags) {
        final tagRef = _firestore.collection('tags').doc(tag['tagId']);
        final tagDoc = await tagRef.get();

        if (!tagDoc.exists) {
          await tagRef.set({
            'name': tag['name'],
            'description': tag['description'],
            'category': tag['category'],
          });
        }
      }

      // Add assessment to user's assessments
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('assessments')
          .doc(assessmentId)
          .set({
            'title': 'Assessment on $_pdfName',
            'createdAt': FieldValue.serverTimestamp(),
            'description':
                'Generated from pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()} of $_pdfName',
            'difficulty': _difficultyController.text,
            'totalPoints': int.tryParse(_pointsController.text) ?? 100,
            'rating': 0,
            'sourceDocumentId': _pdfUrl,
            'madeByAI': true,
            'wasSharedWithUser': false,
            'wasSharedInGroup': false,
          });

      _logger.i('Assessment saved successfully with ID: $assessmentId');

      // Add success message to chat history
      _chatHistory.add({
        'role': 'assistant',
        'content':
            'Assessment saved successfully! You can now find it in your assessments list.',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Scroll to bottom of chat
      _scrollToBottom();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessment saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reset generated questions
      setState(() {
        _generatedQuestions = null;
      });
    } catch (e, stackTrace) {
      _logger.e(
        'Error saving assessment to Firestore',
        error: e,
        stackTrace: stackTrace,
      );
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

  /// Show the PDF options dialog
  void _showPdfOptionsDialog() {
    if (_pdfFile == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A3DE8).withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description,
                            color: Color(0xFF6A3DE8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pdfName ?? 'PDF Document',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6A3DE8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Page range selection
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Page Range',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Page ${_pageRange.start.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Page ${_pageRange.end.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          RangeSlider(
                            values: _pageRange,
                            min: 1,
                            max: _pdfPageCount.toDouble(),
                            divisions:
                                _pdfPageCount > 1 ? _pdfPageCount - 1 : 1,
                            activeColor: const Color(0xFF6A3DE8),
                            inactiveColor: const Color(
                              0xFF6A3DE8,
                            ).withOpacity(0.2),
                            labels: RangeLabels(
                              _pageRange.start.toInt().toString(),
                              _pageRange.end.toInt().toString(),
                            ),
                            onChanged: (values) {
                              setModalState(() {
                                _pageRange = values;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Question generation options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Question Generation Options',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Difficulty
                          Row(
                            children: [
                              const Text(
                                'Difficulty:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _difficultyController.text,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items:
                                      _difficultyLevels
                                          .map(
                                            (level) => DropdownMenuItem(
                                              value: level,
                                              child: Text(
                                                level
                                                        .substring(0, 1)
                                                        .toUpperCase() +
                                                    level.substring(1),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setModalState(() {
                                        _difficultyController.text = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Total points
                          Row(
                            children: [
                              const Text(
                                'Total Points:',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _pointsController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Question types
                          const Text(
                            'Question Types:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children:
                                _questionTypes.map((type) {
                                  final isSelected = _selectedQuestionTypes
                                      .contains(type);
                                  return FilterChip(
                                    label: Text(
                                      type
                                          .split('-')
                                          .map(
                                            (word) =>
                                                word
                                                    .substring(0, 1)
                                                    .toUpperCase() +
                                                word.substring(1),
                                          )
                                          .join(' '),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setModalState(() {
                                        if (selected) {
                                          if (!_selectedQuestionTypes.contains(
                                            type,
                                          )) {
                                            _selectedQuestionTypes.add(type);
                                          }
                                        } else {
                                          if (_selectedQuestionTypes.length >
                                              1) {
                                            _selectedQuestionTypes.remove(type);
                                          }
                                        }
                                      });
                                    },
                                    selectedColor: const Color(
                                      0xFF6A3DE8,
                                    ).withOpacity(0.2),
                                    checkmarkColor: const Color(0xFF6A3DE8),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Generate button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _generateAssessmentQuestions();
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text(
                            'Generate Assessment Questions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A3DE8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstTime) {
      return _buildOnboardingScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            _buildCustomAppBar(),

            // Chat messages area
            Expanded(
              child:
                  _chatHistory.isEmpty
                      ? _buildWelcomeScreen()
                      : _buildChatMessages(),
            ),

            // Error message display
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
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
            _buildChatInputArea(),
          ],
        ),
      ),
      floatingActionButton:
          _pdfFile != null
              ? FloatingActionButton(
                onPressed: _showPdfOptionsDialog,
                backgroundColor: const Color(0xFF6A3DE8),
                child: const Icon(Icons.settings),
              )
              : null,
    );
  }

  /// Build the custom app bar
  Widget _buildCustomAppBar() {
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
            onPressed: () => Navigator.pop(context),
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
                    color: Color(0xFF6A3DE8),
                  ),
                ),
                if (_pdfFile != null)
                  Text(
                    _pdfName ?? 'PDF Document',
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
              color: const Color(0xFF6A3DE8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButton<String>(
              value: _selectedModel,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6A3DE8)),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6A3DE8),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'gemini-2.5-pro',
                  child: Text('Gemini 2.5 Pro'),
                ),
                DropdownMenuItem(
                  value: 'gemini-2.0-pro',
                  child: Text('Gemini 2.0 Pro'),
                ),
                DropdownMenuItem(
                  value: 'gemini-2.0-lite',
                  child: Text('Gemini 2.0 Lite'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedModel = value;
                  });
                }
              },
            ),
          ),

          const SizedBox(width: 8),

          // Help button
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              setState(() {
                _showInstructions = !_showInstructions;
              });
            },
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  /// Build the welcome screen
  Widget _buildWelcomeScreen() {
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
                    color: const Color(0xFF6A3DE8).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.smart_toy,
                      size: 72,
                      color: const Color(0xFF6A3DE8).withOpacity(0.8),
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
                    color: Color(0xFF6A3DE8),
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
                const SizedBox(height: 48),

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
                            color: const Color(0xFF6A3DE8).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            size: 36,
                            color: Color(0xFF6A3DE8),
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
                            onPressed: _pickPdfFile,
                            icon:
                                _isPdfLoading
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
                              _isPdfLoading ? 'Uploading...' : 'Select PDF',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A3DE8),
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
                            color: const Color(0xFF6A3DE8).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat,
                            size: 36,
                            color: Color(0xFF6A3DE8),
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
                            onPressed: () {
                              // Set focus to chat input
                              FocusScope.of(context).requestFocus(FocusNode());
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                // Add delay to ensure the UI update has completed
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    _promptController.text =
                                        'Hello, I need help with creating an assessment.';
                                  },
                                );
                              });
                            },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text(
                              'Start Chatting',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6A3DE8),
                              side: const BorderSide(
                                color: Color(0xFF6A3DE8),
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
        if (_showInstructions)
          GestureDetector(
            onTap: () {
              setState(() {
                _showInstructions = false;
              });
            },
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
                          color: Color(0xFF6A3DE8),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                        onPressed: () {
                          setState(() {
                            _showInstructions = false;
                          });
                        },
                        child: const Text(
                          'Got it!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6A3DE8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
        final isUser = message['role'] == 'user';

        // Handle special assistant messages with attachments
        if (!isUser && message['hasAttachment'] == true) {
          return _buildAssistantSpecialMessage(message);
        }

        return _buildChatMessageBubble(
          message['content'],
          isUser,
          timestamp: message['timestamp'],
        );
      },
    );
  }

  /// Build a chat message bubble
  Widget _buildChatMessageBubble(
    String message,
    bool isUser, {
    int? timestamp,
  }) {
    final time =
        timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now();

    final timeString = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Card(
          color: isUser ? const Color(0xFF6A3DE8) : Colors.white,
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
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    )
                    : MarkdownBody(
                      data: message,
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
                        onPressed: () => _copyToClipboard(message),
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

  /// Build a special assistant message with assessment attachment
  Widget _buildAssistantSpecialMessage(Map<String, dynamic> message) {
    if (message['attachmentType'] == 'assessment' &&
        _generatedQuestions != null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6A3DE8).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment, color: Color(0xFF6A3DE8)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Generated Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A3DE8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'],
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // Statistics
                  _buildAssessmentStatistics(),
                  const SizedBox(height: 24),

                  // Preview of questions
                  const Text(
                    'Preview of Questions:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Sample questions
                  ..._buildSampleQuestions(),
                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveAssessmentToFirestore,
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.save),
                      label: Text(
                        _isLoading ? 'Saving...' : 'Save Assessment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A3DE8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Fallback for other types
    return _buildChatMessageBubble(
      message['content'],
      false,
      timestamp: message['timestamp'],
    );
  }

  /// Build assessment statistics
  Widget _buildAssessmentStatistics() {
    if (_generatedQuestions == null) {
      return const SizedBox.shrink();
    }

    final questions = _generatedQuestions!['questions'] as List<dynamic>;
    final questionTypes = <String, int>{};
    int totalPoints = 0;

    // Calculate statistics
    for (final question in questions) {
      final type = question['questionType'] as String;
      questionTypes[type] = (questionTypes[type] ?? 0) + 1;
      totalPoints += (question['points'] as int);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary statistics
          Row(
            children: [
              _buildStatItem(
                'Questions',
                questions.length.toString(),
                Icons.help_outline,
              ),
              _buildStatItem(
                'Total Points',
                totalPoints.toString(),
                Icons.stars,
              ),
              _buildStatItem(
                'Difficulty',
                _difficultyController.text.substring(0, 1).toUpperCase() +
                    _difficultyController.text.substring(1),
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question types breakdown
          const Text(
            'Question Types:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children:
                questionTypes.entries.map((entry) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF6A3DE8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatQuestionType(entry.key),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  /// Format question type for display
  String _formatQuestionType(String type) {
    switch (type) {
      case 'multiple-choice':
        return 'Multiple Choice';
      case 'multiple-answer':
        return 'Multiple Answer';
      case 'true-false':
        return 'True/False';
      case 'fill-in-the-blank':
        return 'Fill in Blank';
      case 'short-answer':
        return 'Short Answer';
      default:
        return type
            .split('-')
            .map(
              (word) => word.substring(0, 1).toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  /// Build a stat item
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6A3DE8), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  /// Build sample questions for preview
  List<Widget> _buildSampleQuestions() {
    if (_generatedQuestions == null) {
      return [];
    }

    final questions = _generatedQuestions!['questions'] as List<dynamic>;
    final answers = _generatedQuestions!['answers'] as List<dynamic>;

    // Show at most 3 questions as samples
    final sampleCount = questions.length > 3 ? 3 : questions.length;
    final samples = <Widget>[];

    for (int i = 0; i < sampleCount; i++) {
      final question = questions[i];
      final questionId = question['questionId'];

      // Find matching answer
      final answer = answers.firstWhere(
        (a) => a['questionId'] == questionId,
        orElse: () => {'answerText': 'No answer available'},
      );

      samples.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question type and points
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A3DE8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatQuestionType(question['questionType']),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6A3DE8),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${question['points']} pts',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Question text
              Text(
                question['questionText'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Options if applicable
              if (question['options'] != null &&
                  (question['options'] as List).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      (question['options'] as List).map((option) {
                        final isAnswer =
                            question['questionType'] == 'multiple-choice'
                                ? answer['answerText'] == option
                                : question['questionType'] ==
                                        'multiple-answer' &&
                                    answer['answerText'] is List &&
                                    (answer['answerText'] as List).contains(
                                      option,
                                    );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(right: 8, top: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        isAnswer
                                            ? const Color(0xFF6A3DE8)
                                            : Colors.grey[400]!,
                                    width: 1.5,
                                  ),
                                  color:
                                      isAnswer
                                          ? const Color(
                                            0xFF6A3DE8,
                                          ).withOpacity(0.1)
                                          : Colors.transparent,
                                ),
                                child:
                                    isAnswer
                                        ? const Center(
                                          child: Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Color(0xFF6A3DE8),
                                          ),
                                        )
                                        : null,
                              ),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isAnswer
                                            ? const Color(0xFF6A3DE8)
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
            ],
          ),
        ),
      );
    }

    return samples;
  }

  /// Build the chat input area
  Widget _buildChatInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // PDF upload button
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickPdfFile,
              tooltip: 'Upload PDF',
              color: const Color(0xFF6A3DE8),
              splashRadius: 24,
            ),

            // Prompt input field
            Expanded(
              child: TextField(
                controller: _promptController,
                decoration: InputDecoration(
                  hintText: 'Ask AI Assistant...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                onSubmitted: (_) => _sendPrompt(),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6A3DE8),
                borderRadius: BorderRadius.circular(50),
              ),
              child: IconButton(
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.send, color: Colors.white),
                onPressed: _isLoading ? null : _sendPrompt,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the onboarding screen for first-time users
  Widget _buildOnboardingScreen() {
    return Scaffold(
      body: PageView(
        controller: _onboardingController,
        children: [
          // Introduction page
          _buildOnboardingPage(
            title: 'Welcome to Your AI Assistant',
            description:
                'Your intelligent companion for creating educational assessments, analyzing documents, and more.',
            icon: Icons.smart_toy,
            backgroundColor: const Color(0xFF6A3DE8),
            isFirstPage: true,
          ),

          // PDF Processing page
          _buildOnboardingPage(
            title: 'Upload PDFs for Analysis',
            description:
                'Upload your educational content and select specific pages to process.',
            icon: Icons.description,
            backgroundColor: const Color(0xFF4CAF50),
          ),

          // Assessment Generation page
          _buildOnboardingPage(
            title: 'Generate Assessments',
            description:
                'Create customized questions with adjustable difficulty, question types, and point values.',
            icon: Icons.assignment,
            backgroundColor: const Color(0xFFFFC107),
          ),

          // Chat Interface page
          _buildOnboardingPage(
            title: 'Intelligent Chat',
            description:
                'Ask questions, get explanations, and receive assistance with your educational needs.',
            icon: Icons.chat,
            backgroundColor: const Color(0xFF2196F3),
            isLastPage: true,
          ),
        ],
      ),
    );
  }

  /// Build a single onboarding page
  Widget _buildOnboardingPage({
    required String title,
    required String description,
    required IconData icon,
    required Color backgroundColor,
    bool isFirstPage = false,
    bool isLastPage = false,
  }) {
    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Skip button for first page
            if (isFirstPage)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isFirstTime = false;
                    });
                  },
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

            // Content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Icon(icon, size: 120, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(height: 48),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button (except for first page)
                  if (!isFirstPage)
                    TextButton(
                      onPressed: () {
                        _onboardingController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(width: 80),

                  // Page indicator
                  Row(
                    children: List.generate(4, (index) {
                      final isActive =
                          index == _onboardingController.page?.round() ||
                          (index == 0 && _onboardingController.page == null);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 12 : 8,
                        height: isActive ? 12 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                        ),
                      );
                    }),
                  ),

                  // Next/Done button
                  TextButton(
                    onPressed: () {
                      if (isLastPage) {
                        setState(() {
                          _isFirstTime = false;
                        });
                      } else {
                        _onboardingController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLastPage ? Icons.check : Icons.arrow_forward,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Instruction item for the instruction overlay
class InstructionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const InstructionItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6A3DE8).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF6A3DE8), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
