import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart'; // Add uuid to pubspec.yaml dependencies

// Services
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';

// Utils
import '../utils/constants.dart';

// Define a consistent design system for colors and styles
class AppStyles {
  // Colors
  static const Color primaryColor = Color(
    0xFF6F9E81,
  ); // Green from Activity page
  static const Color secondaryColor = Color(
    0xFFF5AA7D,
  ); // Orange from Journal page
  static const Color tertiaryColor = Color(
    0xFFB290E3,
  ); // Purple from Sleep page
  static const Color backgroundColor = Color(
    0xFFF9F8F3,
  ); // Off-white background
  static const Color cardColor = Colors.white;
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF43A047);
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);

  // Text Styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: textPrimaryColor,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: textSecondaryColor,
  );

  // Box Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(
          13,
        ), // Using withAlpha instead of withOpacity
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration selectedItemDecoration(Color color) {
    return BoxDecoration(
      color: color.withAlpha(38), // Using withAlpha instead of withOpacity
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color, width: 2),
    );
  }
}

class CreateAssessmentPage extends StatefulWidget {
  const CreateAssessmentPage({super.key}); // Using super parameter

  @override
  State<CreateAssessmentPage> createState() => _CreateAssessmentPageState();
}

class _CreateAssessmentPageState extends State<CreateAssessmentPage> {
  final Logger _logger = Logger();

  // Services
  late final StorageService _storageService;
  late final PdfService _pdfService;
  late ApiService? _apiService;

  // Controllers for text fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _difficultyController = TextEditingController(
    text: 'medium',
  );
  final TextEditingController _apiKeyController = TextEditingController();

  // Page controller for the wizard
  final PageController _pageController = PageController();

  // Current step in the wizard
  int _currentStep = 0;

  // PDF handling variables
  File? _pdfFile;
  String? _pdfName;
  String? _pdfUrl;
  int _pdfPageCount = 0;
  RangeValues _pageRange = const RangeValues(1, 2);
  String? _extractedFullText;

  // Question generation options
  final List<String> _selectedQuestionTypes = [
    // Made final
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

  // UI state variables
  bool _isLoading = false;
  bool _isPdfLoading = false;
  bool _isPdfProcessing = false;
  bool _isGeneratingQuestions = false;
  bool _isApiKeySet = false;
  bool _isPublic = true;
  String? _errorMessage;
  String _selectedModel = AppConstants.defaultModel;

  // Total points (calculated dynamically)
  int _totalPoints = 0;

  // Generated content
  Map<String, dynamic>? _generatedQuestions;

  // Step titles for the wizard
  final List<String> _stepTitles = [
    'Select Document',
    'Content & Difficulty',
    'Question Types',
    'Review & Generate',
  ];

  // Step icons
  final List<IconData> _stepIcons = [
    Icons.upload_file,
    Icons.content_paste,
    Icons.quiz,
    Icons.summarize,
  ];

  @override
  void initState() {
    super.initState();

    // Initialize services
    _storageService = StorageService();
    _pdfService = PdfService();

    // Check for stored API key
    _loadApiKey();

    // Calculate initial total points
    _calculateTotalPoints();

    // Log page initialization
    _logger.i('CreateAssessmentPage initialized');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _difficultyController.dispose();
    _apiKeyController.dispose();

    // Dispose question type count controllers
    _questionTypeCounts.forEach((_, controller) => controller.dispose());

    _logger.i('CreateAssessmentPage disposed');
    super.dispose();
  }

  /// Calculate total assessment points based on question type counts
  void _calculateTotalPoints() {
    int total = 0;

    for (final type in _selectedQuestionTypes) {
      final countText = _questionTypeCounts[type]?.text ?? '0';
      final count = int.tryParse(countText) ?? 0;
      final pointsPerQuestion = AppConstants.questionTypePoints[type] ?? 1;
      total += count * pointsPerQuestion;
    }

    setState(() {
      _totalPoints = total;
    });

    _logger.d('Total points calculated: $_totalPoints');
  }

  /// Load Gemini API key from secure storage
  Future<void> _loadApiKey() async {
    try {
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
    } catch (e) {
      _logger.e('Error loading API key', error: e);
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              _isApiKeySet ? 'Update API Key' : 'Set Gemini API Key',
              style: AppStyles.subheadingStyle,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your Gemini API key to use the AI features. You can get an API key from the Google AI Studio.',
                  style: AppStyles.captionStyle,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: 'Enter Gemini API key',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppStyles.textSecondaryColor),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final apiKey = _apiKeyController.text.trim();
                  if (apiKey.isNotEmpty) {
                    _saveApiKey(apiKey);
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('API key saved successfully'),
                        backgroundColor: AppStyles.successColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyles.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  /// Save API key
  Future<void> _saveApiKey(String apiKey) async {
    try {
      final success = await _storageService.saveApiKey(apiKey);

      if (success) {
        setState(() {
          _isApiKeySet = true;
          _apiService = ApiService(apiKey);
        });

        _apiKeyController.clear();
        _logger.i('API key saved successfully');
      } else {
        setState(() {
          _errorMessage = 'Failed to save API key. Please try again.';
        });
        _logger.e('Failed to save API key');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving API key: $e';
      });
      _logger.e('Error saving API key', error: e);
    }
  }

  /// Select and load a PDF file
  Future<void> _pickPdfFile() async {
    if (!mounted) return;

    setState(() {
      _isPdfLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Starting PDF file selection');
      final pdfData = await _pdfService.pickPdfFile();

      if (pdfData != null && mounted) {
        final pdfFile = pdfData['file'] as File;
        final fileName = pdfData['name'] as String;
        final pageCount = pdfData['pageCount'] as int;

        _logger.i('PDF selected: $fileName with $pageCount pages');

        setState(() {
          _pdfFile = pdfFile;
          _pdfName = fileName;
          _pdfPageCount = pageCount > 0 ? pageCount : 1;
          // Ensure end is always greater than start and within bounds
          _pageRange = RangeValues(
            1,
            _pdfPageCount > 1 ? _pdfPageCount.toDouble() : 2,
          );

          // Auto-populate title if empty
          if (_titleController.text.isEmpty) {
            _titleController.text = fileName.replaceAll('.pdf', '');
          }
        });

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
    if (!mounted) return;

    try {
      _logger.i('Uploading PDF to Firebase Storage');

      final downloadUrl = await _storageService.uploadPdfToStorage(
        pdfFile,
        fileName,
      );

      if (downloadUrl != null && mounted) {
        setState(() {
          _pdfUrl = downloadUrl;
        });
        _logger.i('PDF uploaded successfully: $downloadUrl');
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
      _logger.e('No PDF file selected for text extraction');
      throw Exception('No PDF file selected');
    }

    setState(() {
      _isPdfProcessing = true;
    });

    try {
      _logger.i(
        'Starting PDF text extraction from pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()}',
      );
      final extractedText = await _pdfService.extractTextFromPdf(
        _pdfFile!,
        _pageRange,
      );

      setState(() {
        _extractedFullText = extractedText;
      });

      _logger.i(
        'Text extracted successfully (${extractedText.length} characters)',
      );
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

  /// Generate description automatically from extracted text
  Future<void> _generateDescription() async {
    try {
      if (_extractedFullText == null || _extractedFullText!.isEmpty) {
        _logger.i('No extracted text found, extracting text from PDF');
        await _extractTextFromPdf();
      }

      if (_extractedFullText == null || _extractedFullText!.isEmpty) {
        setState(() {
          _errorMessage =
              'Unable to extract text from PDF for description generation';
        });
        _logger.e('Unable to extract text from PDF for description generation');
        return;
      }

      if (!_isApiKeySet || _apiService == null) {
        setState(() {
          _errorMessage = 'Please set your API key first';
        });
        _logger.w('API key not set for description generation');
        _showApiKeyDialog();
        return;
      }

      _logger.i('Generating description from extracted text');

      // Prepare a sample of the text
      final textSample =
          _extractedFullText!.length > 5000
              ? _extractedFullText!.substring(0, 5000)
              : _extractedFullText!;

      // Create prompt for description generation
      final prompt = '''
Based on the following content from a document, write a concise description (maximum 300 characters) 
that summarizes what topics are covered. The description should be suitable for an assessment about this content.
Focus on the main subject and key topics.

Content:
$textSample

Respond with just the description, no additional text.
''';

      // Call the API
      final description = await _apiService!.sendPrompt(prompt, _selectedModel);

      // Clean up the description (remove quotes, trim, etc.)
      final cleanDescription =
          description
              .replaceAll('"', '')
              .replaceAll('Description:', '')
              .replaceAll('Here is a description:', '')
              .trim();

      setState(() {
        _descriptionController.text = cleanDescription;
      });

      _logger.i('Description generated successfully');
    } catch (e) {
      _logger.e('Error generating description', error: e);
      // Set a fallback description
      setState(() {
        _descriptionController.text =
            'Assessment based on ${_pdfName ?? "uploaded document"}';
      });
    }
  }

  /// Generate assessment questions
  Future<void> _generateAssessmentQuestions() async {
    if (_pdfFile == null) {
      setState(() {
        _errorMessage = 'Please upload a PDF document first';
      });
      _logger.w('No PDF uploaded for question generation');
      return;
    }

    if (!_isApiKeySet || _apiService == null) {
      setState(() {
        _errorMessage = 'Please set your API key first';
      });
      _logger.w('API key not set for question generation');
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
      _logger.w('No question types selected with count > 0');
      return;
    }

    // Validate required fields
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a title for the assessment';
      });
      _logger.w('Missing title for assessment');
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

      _logger.d('Question distribution: $questionDistribution');

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

      // Automatically generate description if empty
      if (_descriptionController.text.isEmpty) {
        await _generateDescription();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Questions generated successfully!'),
            backgroundColor: AppStyles.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
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

  /// Save assessment to Firestore
  Future<void> _saveAssessment() async {
    if (_generatedQuestions == null || _pdfName == null || _pdfUrl == null) {
      setState(() {
        _errorMessage = 'No questions generated or document loaded';
      });
      _logger.w('Cannot save assessment: missing questions or document');
      return;
    }

    // Validate required fields
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a title for the assessment';
      });
      _logger.w('Missing title for assessment');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Saving assessment to Firestore');

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Generate unique ID for assessment
      final assessmentId = const Uuid().v4();
      _logger.d('Generated assessment ID: $assessmentId');

      // Create assessment data
      final assessmentData = {
        'title': _titleController.text.trim(),
        'creatorId': user.uid,
        'sourceDocumentId': _pdfUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'description': _descriptionController.text.trim(),
        'difficulty': _difficultyController.text.trim(),
        'isPublic': _isPublic,
        'totalPoints': _totalPoints,
        'tags': [], // Empty array
        'rating': 0,
        'madeByAI': true,
      };

      // Reference to the main assessment document
      final assessmentRef = FirebaseFirestore.instance
          .collection(AppConstants.assessmentsCollection)
          .doc(assessmentId);

      // Create batched write
      final batch = FirebaseFirestore.instance.batch();

      // Set main assessment document
      batch.set(assessmentRef, assessmentData);

      _logger.d('Added main assessment document to batch');

      // Add questions subcollection
      final questions = _generatedQuestions!['questions'] as List<dynamic>;
      for (final question in questions) {
        if (question is Map) {
          final questionId = question['questionId'];
          final questionRef = assessmentRef
              .collection(AppConstants.questionsCollection)
              .doc(questionId);
          batch.set(questionRef, question);
        }
      }

      _logger.d('Added ${questions.length} questions to batch');

      // Add answers subcollection
      final answers = _generatedQuestions!['answers'] as List<dynamic>;
      for (final answer in answers) {
        if (answer is Map) {
          final answerId = answer['answerId'];
          final answerRef = assessmentRef
              .collection(AppConstants.answersCollection)
              .doc(answerId);
          batch.set(answerRef, answer);
        }
      }

      _logger.d('Added ${answers.length} answers to batch');

      // Add assessment to user's assessments subcollection
      final userAssessmentRef = FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.assessmentsCollection)
          .doc(assessmentId);

      batch.set(userAssessmentRef, {
        'title': _titleController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'description': _descriptionController.text.trim(),
        'difficulty': _difficultyController.text.trim(),
        'totalPoints': _totalPoints,
        'sourceDocumentId': _pdfUrl,
        'rating': 0,
        'madeByAI': true,
        'wasSharedWithUser': false,
        'wasSharedInGroup': false,
      });

      _logger.d('Added user assessment reference to batch');

      // Commit the batch
      await batch.commit();

      _logger.i('Assessment saved successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Assessment saved successfully!'),
            backgroundColor: AppStyles.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );

        // Navigate back
        Navigator.pop(context, true);
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

  /// Validate and update page range values
  void _updatePageRange(RangeValues values) {
    // Ensure valid range (start <= end and both within bounds)
    final double start = values.start.clamp(1, _pdfPageCount.toDouble());
    final double end = values.end.clamp(start, _pdfPageCount.toDouble());

    setState(() {
      _pageRange = RangeValues(start, end);
    });

    _logger.d('Page range updated: $start to $end');
  }

  /// Move to the next step in the wizard
  void _nextStep() {
    // Validate before proceeding to next step
    if (_currentStep == 0 && _pdfFile == null) {
      setState(() {
        _errorMessage = 'Please upload a PDF document before continuing';
      });
      _logger.w('Cannot proceed: PDF document not uploaded');
      return;
    }

    if (_currentStep < _stepTitles.length - 1) {
      setState(() {
        _currentStep++;
        _errorMessage =
            null; // Clear any error messages when moving to next step
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _logger.i('Moved to step $_currentStep: ${_stepTitles[_currentStep]}');
    }
  }

  /// Move to the previous step in the wizard
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage =
            null; // Clear any error messages when moving to previous step
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _logger.i(
        'Moved back to step $_currentStep: ${_stepTitles[_currentStep]}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: AppStyles.backgroundColor,
      appBar: AppBar(
        title: const Text('Create Assessment'),
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          // API key icon
          IconButton(
            onPressed: _showApiKeyDialog,
            icon: Icon(
              _isApiKeySet ? Icons.key : Icons.key_off,
              color: _isApiKeySet ? Colors.white : Colors.white70,
            ),
            tooltip: _isApiKeySet ? 'Update API Key' : 'Set API Key',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper progress indicator
            _buildStepperIndicator(isSmallScreen),

            // Error message display
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppStyles.errorColor.withAlpha(
                    26,
                  ), // Using withAlpha instead of withOpacity
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.errorColor.withAlpha(
                      77,
                    ), // Using withAlpha instead of withOpacity
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error, color: AppStyles.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppStyles.errorColor),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: AppStyles.errorColor,
                        size: 18,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Main content area
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  _buildSelectDocumentStep(),
                  _buildContentSelectionStep(),
                  _buildQuestionConfigStep(),
                  _buildReviewStep(),
                ],
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  /// Build the stepper indicator at the top of the page
  /// Only shows the title text for the current active step to prevent overflow
  Widget _buildStepperIndicator(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              13,
            ), // Using withAlpha instead of withOpacity
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_stepTitles.length * 2 - 1, (index) {
          // Check if this is a connector (odd index)
          if (index.isOdd) {
            return Expanded(
              flex: 1,
              child: Container(
                height: 2,
                color:
                    index < _currentStep * 2 + 1
                        ? AppStyles.primaryColor
                        : Colors.grey[300],
              ),
            );
          }

          // Get the step number
          final step = index ~/ 2;
          final isCompleted = step < _currentStep;
          final isActive = step == _currentStep;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle indicator with icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isCompleted
                          ? AppStyles.primaryColor
                          : isActive
                          ? AppStyles.primaryColor.withAlpha(
                            26,
                          ) // Using withAlpha instead of withOpacity
                          : Colors.grey[200],
                  border: Border.all(
                    color:
                        isCompleted || isActive
                            ? AppStyles.primaryColor
                            : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child:
                      isCompleted
                          ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                          : Icon(
                            _stepIcons[step],
                            color:
                                isActive
                                    ? AppStyles.primaryColor
                                    : Colors.grey[600],
                            size: 20,
                          ),
                ),
              ),

              // Only show the text label for the active step to prevent overflow
              if (!isSmallScreen && isActive)
                Column(
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _stepTitles[step],
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          );
        }),
      ),
    );
  }

  /// Build the document selection step
  Widget _buildSelectDocumentStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step title
                Text('Select Document', style: AppStyles.headingStyle),
                const SizedBox(height: 8),
                Text(
                  'Upload a PDF document to create assessment questions',
                  style: AppStyles.captionStyle,
                ),
                const SizedBox(height: 24),

                // PDF upload area
                if (_pdfFile == null)
                  _buildDocumentUploadArea()
                else
                  _buildSelectedDocumentCard(),

                const SizedBox(height: 24),

                // Model selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.smart_toy, color: AppStyles.primaryColor),
                          const SizedBox(width: 8),
                          Text('AI Model', style: AppStyles.subheadingStyle),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select the AI model to use for generating questions',
                        style: AppStyles.captionStyle,
                      ),
                      const SizedBox(height: 16),

                      // Model selection radio buttons
                      ...AppConstants.availableModels.map((model) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  _selectedModel == model['value']
                                      ? AppStyles.primaryColor
                                      : Colors.grey[300]!,
                            ),
                          ),
                          color:
                              _selectedModel == model['value']
                                  ? AppStyles.primaryColor.withAlpha(
                                    13,
                                  ) // Using withAlpha instead of withOpacity
                                  : Colors.white,
                          child: RadioListTile<String>(
                            title: Text(
                              model['label']!,
                              style: TextStyle(
                                fontWeight:
                                    _selectedModel == model['value']
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                            subtitle: _getModelDescription(model['value']!),
                            value: model['value']!,
                            groupValue: _selectedModel,
                            activeColor: AppStyles.primaryColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedModel = value;
                                });
                                _logger.d('Selected model: $value');
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get description for the model
  Widget _getModelDescription(String modelValue) {
    String description;

    switch (modelValue) {
      case 'gemini-2.5-pro-preview-03-25':
        description = 'Most capabilities, higher accuracy, slower response';
        break;
      case 'gemini-2.0-flash':
        description = 'Balance of accuracy and speed';
        break;
      case 'gemini-2.0-flash-lite':
        description = 'Fastest response time, smaller model';
        break;
      default:
        description = '';
    }

    return Text(
      description,
      style: TextStyle(fontSize: 12, color: AppStyles.textSecondaryColor),
    );
  }

  /// Build the document upload area
  Widget _buildDocumentUploadArea() {
    return GestureDetector(
      onTap: _isPdfLoading ? null : _pickPdfFile,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppStyles.primaryColor.withAlpha(
              77,
            ), // Using withAlpha instead of withOpacity
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Center(
          child:
              _isPdfLoading
                  ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppStyles.primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Uploading PDF...',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppStyles.textSecondaryColor,
                        ),
                      ),
                    ],
                  )
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 48,
                        color: AppStyles.primaryColor.withAlpha(
                          179,
                        ), // Using withAlpha instead of withOpacity
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to upload a PDF',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Max file size: 20MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  /// Build the selected document card
  Widget _buildSelectedDocumentCard() {
    return Container(
      decoration: AppStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PDF preview
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppStyles.primaryColor.withAlpha(
                26,
              ), // Using withAlpha instead of withOpacity
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.picture_as_pdf,
                size: 64,
                color: AppStyles.primaryColor.withAlpha(
                  179,
                ), // Using withAlpha instead of withOpacity
              ),
            ),
          ),

          // PDF details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pdfName ?? 'Document',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryColor.withAlpha(
                          26,
                        ), // Using withAlpha instead of withOpacity
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_pdfPageCount pages',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppStyles.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_pdfUrl != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(
                            26,
                          ), // Using withAlpha instead of withOpacity
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Uploaded',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Change PDF button
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _isPdfLoading ? null : _pickPdfFile,
                    icon:
                        _isPdfLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.upload_file),
                    label: Text(_isPdfLoading ? 'Uploading...' : 'Change PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppStyles.primaryColor,
                      side: BorderSide(color: AppStyles.primaryColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
        ],
      ),
    );
  }

  /// Build the content selection step
  Widget _buildContentSelectionStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step title
                Text('Content & Difficulty', style: AppStyles.headingStyle),
                const SizedBox(height: 8),
                Text(
                  'Select which pages to use and set difficulty level',
                  style: AppStyles.captionStyle,
                ),
                const SizedBox(height: 24),

                // Page range selection
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            color: AppStyles.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text('Page Range', style: AppStyles.subheadingStyle),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select which pages to extract content from',
                        style: AppStyles.captionStyle,
                      ),
                      const SizedBox(height: 24),

                      // Page range indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppStyles.primaryColor.withAlpha(
                                26,
                              ), // Using withAlpha instead of withOpacity
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppStyles.primaryColor.withAlpha(
                                  77,
                                ), // Using withAlpha instead of withOpacity
                              ),
                            ),
                            child: Text(
                              'Page ${_pageRange.start.toInt()}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'to',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppStyles.textSecondaryColor,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppStyles.primaryColor.withAlpha(
                                26,
                              ), // Using withAlpha instead of withOpacity
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppStyles.primaryColor.withAlpha(
                                  77,
                                ), // Using withAlpha instead of withOpacity
                              ),
                            ),
                            child: Text(
                              'Page ${_pageRange.end.toInt()}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppStyles.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Range slider
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppStyles.primaryColor,
                          inactiveTrackColor: AppStyles.primaryColor.withAlpha(
                            51,
                          ), // Using withAlpha instead of withOpacity
                          thumbColor: Colors.white,
                          overlayColor: AppStyles.primaryColor.withAlpha(
                            26,
                          ), // Using withAlpha instead of withOpacity
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 12,
                            elevation: 3,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 24,
                          ),
                          rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 12,
                            elevation: 3,
                          ),
                          rangeTrackShape:
                              const RoundedRectRangeSliderTrackShape(),
                          rangeValueIndicatorShape:
                              const PaddleRangeSliderValueIndicatorShape(),
                          showValueIndicator: ShowValueIndicator.always,
                        ),
                        child: RangeSlider(
                          values: _pageRange,
                          min: 1,
                          max: _pdfPageCount > 1 ? _pdfPageCount.toDouble() : 2,
                          divisions: _pdfPageCount > 1 ? _pdfPageCount - 1 : 1,
                          labels: RangeLabels(
                            _pageRange.start.toInt().toString(),
                            _pageRange.end.toInt().toString(),
                          ),
                          onChanged: _updatePageRange,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Page count indicator
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(_pageRange.end.toInt() - _pageRange.start.toInt() + 1)} pages selected',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppStyles.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Difficulty selection
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            color: AppStyles.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Difficulty Level',
                            style: AppStyles.subheadingStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set how challenging the questions should be',
                        style: AppStyles.captionStyle,
                      ),
                      const SizedBox(height: 24),

                      // Difficulty selector
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.5,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        padding: EdgeInsets.zero,
                        children:
                            AppConstants.difficultyLevels.map((level) {
                              final isSelected =
                                  _difficultyController.text == level;

                              Color difficultyColor;
                              switch (level) {
                                case 'easy':
                                  difficultyColor = Colors.green;
                                  break;
                                case 'medium':
                                  difficultyColor = Colors.orange;
                                  break;
                                case 'hard':
                                  difficultyColor = Colors.red;
                                  break;
                                case 'expert':
                                  difficultyColor = Colors.purple;
                                  break;
                                default:
                                  difficultyColor = AppStyles.primaryColor;
                              }

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _difficultyController.text = level;
                                  });
                                  _logger.d('Selected difficulty: $level');
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? difficultyColor.withAlpha(
                                              38,
                                            ) // Using withAlpha instead of withOpacity
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? difficultyColor
                                              : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: difficultyColor,
                                          ),
                                        if (isSelected)
                                          const SizedBox(width: 4),
                                        Text(
                                          level.substring(0, 1).toUpperCase() +
                                              level.substring(1),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color:
                                                isSelected
                                                    ? difficultyColor
                                                    : AppStyles
                                                        .textPrimaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Difficulty explanation
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getDifficultyExplanation(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[800],
                                ),
                              ),
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
      },
    );
  }

  /// Get explanation text for the selected difficulty
  String _getDifficultyExplanation() {
    switch (_difficultyController.text) {
      case 'easy':
        return 'Basic recall and understanding questions. Suitable for beginners or introductory assessments.';
      case 'medium':
        return 'Balanced difficulty with some application and analysis questions. Good for general assessments.';
      case 'hard':
        return 'Challenging questions requiring deep understanding and application of concepts.';
      case 'expert':
        return 'Very challenging questions requiring synthesis, evaluation, and expert knowledge.';
      default:
        return '';
    }
  }

  /// Build the question configuration step
  Widget _buildQuestionConfigStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step title
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Question Types',
                        style: AppStyles.headingStyle,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Total: $_totalPoints pts',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select question types and how many of each',
                  style: AppStyles.captionStyle,
                ),
                const SizedBox(height: 24),

                // Question types list
                ...AppConstants.questionTypes.map((type) {
                  final isSelected = _selectedQuestionTypes.contains(type);
                  final pointsPerQuestion =
                      AppConstants.questionTypePoints[type] ?? 1;

                  Color typeColor;
                  IconData typeIcon;

                  switch (type) {
                    case 'multiple-choice':
                      typeColor = const Color(0xFF42A5F5); // Blue
                      typeIcon = Icons.check_circle_outline;
                      break;
                    case 'multiple-answer':
                      typeColor = const Color(0xFF66BB6A); // Green
                      typeIcon = Icons.library_add_check_outlined;
                      break;
                    case 'true-false':
                      typeColor = const Color(0xFFFFB74D); // Orange
                      typeIcon = Icons.compare_arrows;
                      break;
                    case 'fill-in-the-blank':
                      typeColor = const Color(0xFFAB47BC); // Purple
                      typeIcon = Icons.horizontal_rule;
                      break;
                    case 'short-answer':
                      typeColor = const Color(0xFFEF5350); // Red
                      typeIcon = Icons.short_text;
                      break;
                    default:
                      typeColor = AppStyles.primaryColor;
                      typeIcon = Icons.help_outline;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(
                            13,
                          ), // Using withAlpha instead of withOpacity
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border:
                          isSelected
                              ? Border.all(color: typeColor, width: 2)
                              : null,
                    ),
                    child: Column(
                      children: [
                        // Header
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                if (_selectedQuestionTypes.length > 1) {
                                  _selectedQuestionTypes.remove(type);
                                }
                              } else {
                                _selectedQuestionTypes.add(type);
                              }
                              _calculateTotalPoints();
                            });
                          },
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Type icon with background
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: typeColor.withAlpha(
                                      26,
                                    ), // Using withAlpha instead of withOpacity
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    typeIcon,
                                    color: typeColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Type info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getQuestionTypeDisplayName(type),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: typeColor.withAlpha(
                                                26,
                                              ), // Using withAlpha instead of withOpacity
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '$pointsPerQuestion pts each',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: typeColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Checkbox
                                Checkbox(
                                  value: isSelected,
                                  activeColor: typeColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        if (!_selectedQuestionTypes.contains(
                                          type,
                                        )) {
                                          _selectedQuestionTypes.add(type);
                                        }
                                      } else {
                                        if (_selectedQuestionTypes.length > 1) {
                                          _selectedQuestionTypes.remove(type);
                                        }
                                      }
                                      _calculateTotalPoints();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Count selector (if selected)
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                const SizedBox(height: 8),

                                Row(
                                  children: [
                                    const Text(
                                      'Number of questions:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Counter input with + and - buttons
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: typeColor.withAlpha(
                                            128,
                                          ), // Using withAlpha instead of withOpacity
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Minus button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                final currentValue =
                                                    int.tryParse(
                                                      _questionTypeCounts[type]
                                                              ?.text ??
                                                          '0',
                                                    ) ??
                                                    0;
                                                if (currentValue > 0) {
                                                  setState(() {
                                                    _questionTypeCounts[type]
                                                            ?.text =
                                                        (currentValue - 1)
                                                            .toString();
                                                    _calculateTotalPoints();
                                                  });
                                                }
                                              },
                                              customBorder:
                                                  const CircleBorder(),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 16,
                                                  color: typeColor,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Count input
                                          SizedBox(
                                            width: 50,
                                            child: TextField(
                                              controller:
                                                  _questionTypeCounts[type],
                                              textAlign: TextAlign.center,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              onChanged: (_) {
                                                setState(() {
                                                  _calculateTotalPoints();
                                                });
                                              },
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          // Plus button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                final currentValue =
                                                    int.tryParse(
                                                      _questionTypeCounts[type]
                                                              ?.text ??
                                                          '0',
                                                    ) ??
                                                    0;
                                                setState(() {
                                                  _questionTypeCounts[type]
                                                          ?.text =
                                                      (currentValue + 1)
                                                          .toString();
                                                  _calculateTotalPoints();
                                                });
                                              },
                                              customBorder:
                                                  const CircleBorder(),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Icon(
                                                  Icons.add,
                                                  size: 16,
                                                  color: typeColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Spacer(),

                                    // Subtotal
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeColor.withAlpha(
                                          26,
                                        ), // Using withAlpha instead of withOpacity
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${(int.tryParse(_questionTypeCounts[type]?.text ?? '0') ?? 0) * pointsPerQuestion} pts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: typeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Example button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed:
                                          () => _showQuestionTypeExample(type),
                                      icon: Icon(
                                        Icons.help_outline,
                                        size: 16,
                                        color: typeColor,
                                      ),
                                      label: Text(
                                        'See example',
                                        style: TextStyle(
                                          color: typeColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: typeColor.withAlpha(
                                          13,
                                        ), // Using withAlpha instead of withOpacity
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Info box on how points are calculated
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber[700], size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'How points are calculated',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Different question types are worth different point values. More complex question types are worth more points.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Total assessment points: $_totalPoints',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.amber[900],
                                ),
                              ),
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
      },
    );
  }

  /// Get display name for question type
  String _getQuestionTypeDisplayName(String type) {
    switch (type) {
      case 'multiple-choice':
        return 'Multiple Choice';
      case 'multiple-answer':
        return 'Multiple Answer';
      case 'true-false':
        return 'True/False';
      case 'fill-in-the-blank':
        return 'Fill in the Blank';
      case 'short-answer':
        return 'Short Answer';
      default:
        return type.replaceAll('-', ' ');
    }
  }

  /// Show example of a question type
  void _showQuestionTypeExample(String type) {
    Color typeColor;

    switch (type) {
      case 'multiple-choice':
        typeColor = const Color(0xFF42A5F5); // Blue
        break;
      case 'multiple-answer':
        typeColor = const Color(0xFF66BB6A); // Green
        break;
      case 'true-false':
        typeColor = const Color(0xFFFFB74D); // Orange
        break;
      case 'fill-in-the-blank':
        typeColor = const Color(0xFFAB47BC); // Purple
        break;
      case 'short-answer':
        typeColor = const Color(0xFFEF5350); // Red
        break;
      default:
        typeColor = AppStyles.primaryColor;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Example: ${_getQuestionTypeDisplayName(type)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
            content: SingleChildScrollView(
              child: _buildQuestionTypeExample(type, typeColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
                style: TextButton.styleFrom(foregroundColor: typeColor),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
    );
  }

  /// Build example widget for a question type
  Widget _buildQuestionTypeExample(String type, Color typeColor) {
    switch (type) {
      case 'multiple-choice':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What is the capital of France?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildExampleOption('Paris', true, typeColor),
            _buildExampleOption('London', false, typeColor),
            _buildExampleOption('Berlin', false, typeColor),
            _buildExampleOption('Madrid', false, typeColor),
          ],
        );
      case 'multiple-answer':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Which of the following are primary colors?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildExampleOption('Red', true, typeColor),
            _buildExampleOption('Green', false, typeColor),
            _buildExampleOption('Blue', true, typeColor),
            _buildExampleOption('Yellow', true, typeColor),
          ],
        );
      case 'true-false':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Earth is flat.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildExampleOption('True', false, typeColor),
            _buildExampleOption('False', true, typeColor),
          ],
        );
      case 'fill-in-the-blank':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The process of plants making food using sunlight is called ____________.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withAlpha(
                  26,
                ), // Using withAlpha instead of withOpacity
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: typeColor.withAlpha(77),
                ), // Using withAlpha instead of withOpacity
              ),
              child: Row(
                children: [
                  Text(
                    'Answer:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('photosynthesis', style: TextStyle(color: typeColor)),
                ],
              ),
            ),
          ],
        );
      case 'short-answer':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Explain Newton\'s Third Law of Motion in your own words.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withAlpha(
                  26,
                ), // Using withAlpha instead of withOpacity
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: typeColor.withAlpha(77),
                ), // Using withAlpha instead of withOpacity
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sample answer:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Newton\'s Third Law states that for every action, there is an equal and opposite reaction. When one object exerts a force on a second object, the second object exerts an equal force in the opposite direction on the first object.',
                    style: TextStyle(color: typeColor),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return const Text('Example not available for this question type.');
    }
  }

  /// Build example option
  Widget _buildExampleOption(String text, bool isCorrect, Color typeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCorrect
                      ? typeColor.withAlpha(51)
                      : Colors
                          .transparent, // Using withAlpha instead of withOpacity
              border: Border.all(
                color: isCorrect ? typeColor : Colors.grey,
                width: 1.5,
              ),
            ),
            child:
                isCorrect
                    ? Center(
                      child: Icon(Icons.check, size: 16, color: typeColor),
                    )
                    : null,
          ),
          Text(
            text,
            style: TextStyle(
              color: isCorrect ? typeColor : Colors.black87,
              fontWeight: isCorrect ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the review step
  Widget _buildReviewStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step title
                Text('Review & Generate', style: AppStyles.headingStyle),
                const SizedBox(height: 8),
                Text(
                  'Review settings and create your assessment',
                  style: AppStyles.captionStyle,
                ),
                const SizedBox(height: 24),

                // Title input
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.title, color: AppStyles.primaryColor),
                          const SizedBox(width: 8),
                          Text('Title', style: AppStyles.subheadingStyle),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Give your assessment a clear, descriptive title',
                        style: AppStyles.captionStyle,
                      ),
                      const SizedBox(height: 16),

                      // Title input field
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Enter assessment title',
                          prefixIcon: const Icon(Icons.edit),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Description input field
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter assessment description (optional)',
                          labelText: 'Description',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Visibility option
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility, color: AppStyles.primaryColor),
                          const SizedBox(width: 8),
                          Text('Visibility', style: AppStyles.subheadingStyle),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Control who can see your assessment',
                        style: AppStyles.captionStyle,
                      ),
                      const SizedBox(height: 16),

                      // Toggle switch
                      Row(
                        children: [
                          Expanded(
                            child: _buildVisibilityOption(
                              icon: Icons.public,
                              title: 'Public',
                              description:
                                  'Anyone can find and use this assessment',
                              isSelected: _isPublic,
                              onTap: () {
                                setState(() {
                                  _isPublic = true;
                                });
                                _logger.d('Visibility set to public');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildVisibilityOption(
                              icon: Icons.lock,
                              title: 'Private',
                              description: 'Only you can see this assessment',
                              isSelected: !_isPublic,
                              onTap: () {
                                setState(() {
                                  _isPublic = false;
                                });
                                _logger.d('Visibility set to private');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Summary of settings
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.summarize, color: AppStyles.primaryColor),
                          const SizedBox(width: 8),
                          Text('Summary', style: AppStyles.subheadingStyle),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Summary items
                      _buildSummaryItem(
                        icon: Icons.picture_as_pdf,
                        title: 'Document',
                        value: _pdfName ?? 'None',
                        color: AppStyles.secondaryColor,
                      ),
                      _buildSummaryItem(
                        icon: Icons.book,
                        title: 'Pages',
                        value:
                            'Pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()}',
                        color: AppStyles.secondaryColor,
                      ),
                      _buildSummaryItem(
                        icon: Icons.trending_up,
                        title: 'Difficulty',
                        value:
                            _difficultyController.text
                                .substring(0, 1)
                                .toUpperCase() +
                            _difficultyController.text.substring(1),
                        color: Colors.orange,
                      ),
                      _buildSummaryItem(
                        icon: Icons.help_outline,
                        title: 'Questions',
                        value: _getTotalQuestionCount().toString(),
                        color: Colors.blue,
                      ),
                      _buildSummaryItem(
                        icon: Icons.stars,
                        title: 'Points',
                        value: _totalPoints.toString(),
                        color: Colors.purple,
                      ),
                      _buildSummaryItem(
                        icon: Icons.memory,
                        title: 'AI Model',
                        value: _getModelDisplayName(),
                        color: Colors.teal,
                      ),
                      _buildSummaryItem(
                        icon: Icons.visibility,
                        title: 'Visibility',
                        value: _isPublic ? 'Public' : 'Private',
                        color: Colors.indigo,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Generated questions status
                if (_generatedQuestions != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green[100],
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Questions Generated!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your assessment has ${_getTotalQuestionCount()} questions worth $_totalPoints points.',
                                style: TextStyle(color: Colors.green[700]),
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
      },
    );
  }

  /// Build a visibility option card
  Widget _buildVisibilityOption({
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? AppStyles.primaryColor : Colors.grey[400]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppStyles.primaryColor.withAlpha(
                    26,
                  ) // Using withAlpha instead of withOpacity
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppStyles.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppStyles.primaryColor.withAlpha(
                          51,
                        ) // Using withAlpha instead of withOpacity
                        : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build a summary item
  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(
                26,
              ), // Using withAlpha instead of withOpacity
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Get the total number of questions
  int _getTotalQuestionCount() {
    int total = 0;
    for (final type in _selectedQuestionTypes) {
      final countText = _questionTypeCounts[type]?.text ?? '0';
      final count = int.tryParse(countText) ?? 0;
      total += count;
    }
    return total;
  }

  /// Get the display name for the selected model
  String _getModelDisplayName() {
    for (final model in AppConstants.availableModels) {
      if (model['value'] == _selectedModel) {
        return model['label'] ?? _selectedModel;
      }
    }
    return _selectedModel;
  }

  /// Build the navigation buttons at the bottom of the page
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              13,
            ), // Using withAlpha instead of withOpacity
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back button (except for first step)
            if (_currentStep > 0)
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: AppStyles.primaryColor.withAlpha(
                        128,
                      ), // Using withAlpha instead of withOpacity
                    ),
                    foregroundColor: AppStyles.primaryColor,
                  ),
                ),
              ),

            if (_currentStep > 0) const SizedBox(width: 16),

            // Next/generate button
            Expanded(
              flex: 2,
              child:
                  _currentStep < _stepTitles.length - 1
                      ? ElevatedButton.icon(
                        onPressed: _nextStep,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next Step'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                      : _generatedQuestions == null
                      ? ElevatedButton.icon(
                        onPressed:
                            _isGeneratingQuestions
                                ? null
                                : _generateAssessmentQuestions,
                        icon:
                            _isGeneratingQuestions
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isGeneratingQuestions
                              ? 'Generating...'
                              : 'Generate Questions',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.blue[300],
                        ),
                      )
                      : ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveAssessment,
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
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.green[300],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
