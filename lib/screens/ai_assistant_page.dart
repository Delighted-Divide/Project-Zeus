import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_math_fork/flutter_math.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AIAssistantPage extends StatefulWidget {
  const AIAssistantPage({super.key});

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage>
    with SingleTickerProviderStateMixin {
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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _geminiApiBaseUrl =
      'https://generativelanguage.googleapis.com/v1/models/';
  String _apiKey = '';

  late AnimationController _animationController;

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

  bool _isLoading = false;
  bool _isPdfLoading = false;
  bool _isPdfProcessing = false;
  bool _isGeneratingQuestions = false;
  bool _isFirstTime = true;
  String _response = '';
  List<Map<String, dynamic>> _chatHistory = [];
  String? _errorMessage;
  String _selectedModel = 'gemini-2.5-pro-preview-03-25';
  bool _showInstructions = false;
  bool _isApiKeySet = false;

  File? _pdfFile;
  String? _pdfName;
  String? _pdfUrl;
  int _pdfPageCount = 0;
  RangeValues _pageRange = const RangeValues(1, 1);
  String _extractedTextPreview = '';
  String? _extractedFullText;

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

  final Map<String, int> _questionTypePoints = {
    'multiple-choice': 1,
    'multiple-answer': 2,
    'true-false': 1,
    'fill-in-the-blank': 2,
    'short-answer': 3,
  };

  final Map<String, TextEditingController> _questionTypeCounts = {
    'multiple-choice': TextEditingController(text: '5'),
    'multiple-answer': TextEditingController(text: '3'),
    'true-false': TextEditingController(text: '4'),
    'fill-in-the-blank': TextEditingController(text: '3'),
    'short-answer': TextEditingController(text: '2'),
  };

  int _totalPoints = 0;

  Map<String, dynamic>? _generatedQuestions;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _checkFirstTimeUser();

    _loadApiKey();

    _calculateTotalPoints();
  }

  void _calculateTotalPoints() {
    int total = 0;

    for (final type in _selectedQuestionTypes) {
      final countText = _questionTypeCounts[type]?.text ?? '0';
      final count = int.tryParse(countText) ?? 0;

      final pointsPerQuestion = _questionTypePoints[type] ?? 1;

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

    _questionTypeCounts.forEach((_, controller) => controller.dispose());

    super.dispose();
  }

  Future<void> _loadApiKey() async {
    try {
      final apiKey = await _secureStorage.read(key: 'gemini_api_key');
      if (apiKey != null && apiKey.isNotEmpty) {
        setState(() {
          _apiKey = apiKey;
          _isApiKeySet = true;
        });
        _logger.i('API key loaded from secure storage');
      } else {
        _logger.i('No API key found in secure storage');
        setState(() {
          _isApiKeySet = false;
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading API key', error: e, stackTrace: stackTrace);
      setState(() {
        _isApiKeySet = false;
      });
    }
  }

  Future<void> _saveApiKey(String apiKey) async {
    try {
      await _secureStorage.write(key: 'gemini_api_key', value: apiKey);
      setState(() {
        _apiKey = apiKey;
        _isApiKeySet = true;
      });
      _logger.i('API key saved to secure storage');
    } catch (e, stackTrace) {
      _logger.e('Error saving API key', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Failed to save API key: $e';
      });
    }
  }

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

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('API key saved successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A3DE8),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

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

          if (_isFirstTime) {
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

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    if (!_isApiKeySet) {
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

      _chatHistory.add({
        'role': 'user',
        'content': prompt,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final modelName = _selectedModel;
      final url = '${_geminiApiBaseUrl}$modelName:generateContent?key=$_apiKey';

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
          'topP': 0.95,
          'topK': 40,
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final responseText =
              data['candidates'][0]['content']['parts'][0]['text'] ??
              'No response received';

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
          throw Exception('No response content found in API response');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error']['message'] ??
              'API request failed: ${response.statusCode}',
        );
      }

      _promptController.clear();

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

  Future<void> _pickPdfFile() async {
    if (!mounted) return;

    setState(() {
      _isPdfLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i('Opening file picker for PDF selection');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;

        if (file.path != null) {
          _logger.i('PDF selected: ${file.name}');

          final pdfFile = File(file.path!);

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

            await _uploadPdfToStorage(pdfFile, file.name);
          }

          _logger.i('PDF loaded successfully with $pageCount pages');
        } else if (file.bytes != null && mounted) {
          _logger.i('PDF selected (web): ${file.name}');

          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/${file.name}');
          await tempFile.writeAsBytes(file.bytes!);

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

  Future<void> _uploadPdfToStorage(File pdfFile, String fileName) async {
    if (!mounted) return;

    try {
      _logger.i('Uploading PDF to Firebase Storage');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final storageRef = _storage.ref().child(
        'pdfs/${currentUser.uid}/$fileName',
      );

      final uploadTask = storageRef.putFile(pdfFile);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        _logger.d('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      final snapshot = await uploadTask.whenComplete(() => null);

      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _pdfUrl = downloadUrl;
        });

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

  Future<String> _extractTextFromPdf() async {
    if (_pdfFile == null) {
      throw Exception('No PDF file selected');
    }

    setState(() {
      _isPdfProcessing = true;
    });

    try {
      _logger.i('Extracting text from PDF using SyncFusion');

      final bytes = await _pdfFile!.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);

      final startPage = _pageRange.start.toInt();
      final endPage = _pageRange.end.toInt();

      final extractor = PdfTextExtractor(document);

      String extractedText = '';
      for (int i = startPage; i <= endPage; i++) {
        final pageText = extractor.extractText(
          startPageIndex: i - 1,
          endPageIndex: i - 1,
        );
        extractedText += 'Page $i:\n$pageText\n\n';
      }

      document.dispose();

      setState(() {
        _extractedTextPreview =
            extractedText.length > 500
                ? '${extractedText.substring(0, 500)}...'
                : extractedText;
        _extractedFullText = extractedText;
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

  Future<void> _generateAssessmentQuestions() async {
    if (_pdfFile == null) {
      setState(() {
        _errorMessage = 'Please upload a PDF document first';
      });
      return;
    }

    if (!_isApiKeySet) {
      setState(() {
        _errorMessage = 'Please set your Gemini API key first';
      });
      _showApiKeyDialog();
      return;
    }

    _calculateTotalPoints();

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

      final difficulty = _difficultyController.text.trim().toLowerCase();

      final questionDistribution = <String, int>{};
      for (final type in _selectedQuestionTypes) {
        final countText = _questionTypeCounts[type]?.text ?? '0';
        final count = int.tryParse(countText) ?? 0;
        questionDistribution[type] = count;
      }

      final distributionInfo = questionDistribution.entries
          .map(
            (entry) =>
                "${entry.key}: ${entry.value} questions (${_questionTypePoints[entry.key]} points each)",
          )
          .join(', ');

      if (_extractedFullText == null || _extractedFullText!.isEmpty) {
        await _extractTextFromPdf();
      }

      if (_extractedFullText == null || _extractedFullText!.isEmpty) {
        throw Exception('No text could be extracted from the selected pages');
      }

      final prompt = '''
You are an expert education assessment creator. Create assessment questions based on the following text.

Text from PDF (pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()}):
${_extractedFullText}

Create a comprehensive assessment with the following specifications:
- Difficulty level: $difficulty
- Total points: $_totalPoints
- Question distribution: $distributionInfo

IMPORTANT: When creating mathematical or scientific notation in your response:
- For mathematical equations, use standard LaTeX notation with single dollar signs (e.g., \$\\\\sqrt{x^2 + y^2}\$)
- For chemical formulas, use correct subscripts and superscripts (e.g., H₂O, CH₃COOH)
- For physics equations, use proper notation (e.g., F = ma, 9.8 m/s²)
- For computer science, enclose code in triple backticks with the language name
- For language subjects, use appropriate Unicode characters
- For diagrams, provide clear text descriptions

Format the response as a JSON object with the following structure:
{
  "questions": [
    {
      "questionId": "unique-id",
      "questionType": "one of the types from the list above",
      "questionText": "the question text with proper formatting",
      "options": ["option1", "option2", etc.] (for multiple-choice or multiple-answer questions),
      "points": number of points for this question based on the question type
    }
  ],
  "answers": [
    {
      "answerId": "unique-id",
      "questionId": "matching question id",
      "answerType": "same as question type",
      "answerText": "the correct answer text or list of correct answers",
      "reasoning": "explanation of why this is the correct answer"
    }
  ],
  "tags": [
    {
      "tagId": "unique-id",
      "name": "tag name",
      "description": "tag description",
      "category": "tag category"
    }
  ]
}

For each question type, create exactly the number specified in the distribution.
For each question type, use exactly the point value specified.
Make sure all strings in the JSON are properly escaped, avoiding unnecessary escape sequences.
Only respond with valid, well-formed JSON. Do not include any other text.
''';

      final modelName = _selectedModel;
      final url = '${_geminiApiBaseUrl}$modelName:generateContent?key=$_apiKey';

      final payload = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 32768,
          'topP': 0.95,
          'topK': 40,
        },
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final responseText =
              data['candidates'][0]['content']['parts'][0]['text'] ?? '';

          String jsonStr = responseText.trim();

          if (jsonStr.startsWith('```json')) {
            jsonStr = jsonStr.substring(7);
          } else if (jsonStr.startsWith('```')) {
            jsonStr = jsonStr.substring(3);
          }
          if (jsonStr.endsWith('```')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 3);
          }

          jsonStr = _sanitizeJsonString(jsonStr);

          try {
            final generatedQuestions = jsonDecode(jsonStr);

            setState(() {
              _generatedQuestions = generatedQuestions;
            });

            _logger.i('Assessment questions generated successfully');

            _chatHistory.add({
              'role': 'user',
              'content':
                  'Generate assessment questions for pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()} with difficulty $difficulty and your specified question distribution',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });

            _chatHistory.add({
              'role': 'assistant',
              'content':
                  'I\'ve generated a set of assessment questions based on the content. There are ${_generatedQuestions!['questions'].length} questions with a total of $_totalPoints points. You can review all questions and answers below.',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'hasAttachment': true,
              'attachmentType': 'assessment',
            });

            _scrollToBottom();
          } catch (jsonError) {
            _logger.e('JSON parsing error', error: jsonError);
            throw Exception(
              'Failed to parse generated assessment JSON: $jsonError. This usually happens when the AI generates malformed JSON. Please try again or adjust the number of questions.',
            );
          }
        } else {
          throw Exception('No response content found in API response');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['error']['message'] ??
              'API request failed: ${response.statusCode}',
        );
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

  String _sanitizeJsonString(String input) {
    try {
      final RegExp latexPattern = RegExp(r'\\\\?\$(.*?)\\\\?\$');
      final matches = latexPattern.allMatches(input);

      var output = input;

      for (final match in matches) {
        final originalText = match.group(0) ?? '';
        final correctedText = originalText.replaceAll(r'\', r'\\');
        output = output.replaceAll(originalText, correctedText);
      }

      output = output.replaceAll(r'\n', '\\n');
      output = output.replaceAll(RegExp(r'(?<!\\)\n'), ' ');

      output = output.replaceAll(r'\r', '\\r');
      output = output.replaceAll(RegExp(r'(?<!\\)\r'), ' ');

      output = output.replaceAll(r'\t', '\\t');
      output = output.replaceAll(RegExp(r'(?<!\\)\t'), ' ');

      output = output.replaceAll(RegExp(r',\s*}'), '}');
      output = output.replaceAll(RegExp(r',\s*]'), ']');

      output = output.replaceAll(
        RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)(\s*:)'),
        r'$1"$2"$3',
      );

      return output;
    } catch (e) {
      print('Error sanitizing JSON: $e');
      return input;
    }
  }

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

      final assessmentId = _uuid.v4();
      final assessmentRef = _firestore
          .collection('assessments')
          .doc(assessmentId);

      await assessmentRef.set({
        'title': 'Assessment on $_pdfName',
        'creatorId': currentUser.uid,
        'sourceDocumentId': _pdfUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'description':
            'Generated from pages ${_pageRange.start.toInt()} to ${_pageRange.end.toInt()} of $_pdfName',
        'difficulty': _difficultyController.text,
        'isPublic': false,
        'totalPoints': _totalPoints,
        'tags':
            _generatedQuestions!['tags'] != null
                ? _generatedQuestions!['tags']
                    .map((tag) => tag['tagId'])
                    .toList()
                : [],
        'rating': 0,
        'madeByAI': true,
      });

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

      final answers = _generatedQuestions!['answers'] as List<dynamic>;
      for (final answer in answers) {
        await assessmentRef.collection('answers').doc(answer['answerId']).set({
          'questionId': answer['questionId'],
          'answerType': answer['answerType'],
          'answerText': answer['answerText'],
          'reasoning': answer['reasoning'],
        });
      }

      if (_generatedQuestions!['tags'] != null) {
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
      }

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
            'totalPoints': _totalPoints,
            'rating': 0,
            'sourceDocumentId': _pdfUrl,
            'madeByAI': true,
            'wasSharedWithUser': false,
            'wasSharedInGroup': false,
          });

      _logger.i('Assessment saved successfully with ID: $assessmentId');

      _chatHistory.add({
        'role': 'assistant',
        'content':
            'Assessment saved successfully! You can now find it in your assessments list.',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessment saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

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
              int calculateTotalPoints() {
                int total = 0;
                for (final type in _selectedQuestionTypes) {
                  final count =
                      int.tryParse(_questionTypeCounts[type]?.text ?? '0') ?? 0;
                  final pointsPerQuestion = _questionTypePoints[type] ?? 1;
                  total += count * pointsPerQuestion;
                }
                return total;
              }

              return Container(
                height: MediaQuery.of(context).size.height * 0.9,
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
                                fontFamily: 'Inter',
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

                    Expanded(
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            Container(
                              color: Colors.white,
                              child: TabBar(
                                labelColor: const Color(0xFF6A3DE8),
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: const Color(0xFF6A3DE8),
                                tabs: const [
                                  Tab(
                                    icon: Icon(Icons.book),
                                    text: "Content Selection",
                                  ),
                                  Tab(
                                    icon: Icon(Icons.question_answer),
                                    text: "Question Types",
                                  ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: TabBarView(
                                children: [
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Select Page Range',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF6A3DE8,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Page ${_pageRange.start.toInt()}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Inter',
                                                  color: Color(0xFF6A3DE8),
                                                ),
                                              ),
                                            ),

                                            const Text(
                                              'to',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontFamily: 'Inter',
                                              ),
                                            ),

                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF6A3DE8,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Page ${_pageRange.end.toInt()}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Inter',
                                                  color: Color(0xFF6A3DE8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        RangeSlider(
                                          values: _pageRange,
                                          min: 1,
                                          max: _pdfPageCount.toDouble(),
                                          divisions:
                                              _pdfPageCount > 1
                                                  ? _pdfPageCount - 1
                                                  : 1,
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

                                        const SizedBox(height: 24),

                                        const Text(
                                          'Difficulty Level',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        Row(
                                          children:
                                              _difficultyLevels.map((level) {
                                                final isSelected =
                                                    _difficultyController
                                                        .text ==
                                                    level;
                                                return Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setModalState(() {
                                                        _difficultyController
                                                            .text = level;
                                                      });
                                                    },
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            isSelected
                                                                ? const Color(
                                                                  0xFF6A3DE8,
                                                                )
                                                                : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              isSelected
                                                                  ? const Color(
                                                                    0xFF6A3DE8,
                                                                  )
                                                                  : Colors
                                                                      .grey[300]!,
                                                        ),
                                                        boxShadow:
                                                            isSelected
                                                                ? [
                                                                  BoxShadow(
                                                                    color: const Color(
                                                                      0xFF6A3DE8,
                                                                    ).withOpacity(
                                                                      0.2,
                                                                    ),
                                                                    blurRadius:
                                                                        4,
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          2,
                                                                        ),
                                                                  ),
                                                                ]
                                                                : null,
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          level
                                                                  .substring(
                                                                    0,
                                                                    1,
                                                                  )
                                                                  .toUpperCase() +
                                                              level.substring(
                                                                1,
                                                              ),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                isSelected
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .grey[700],
                                                            fontFamily: 'Inter',
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Column(
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.all(16),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF6A3DE8),
                                              Color(0xFF5E35B1),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF6A3DE8,
                                              ).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            const Text(
                                              'Total Assessment Points',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${calculateTotalPoints()}',
                                              style: const TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Adjust question counts below',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          itemCount: _questionTypes.length,
                                          itemBuilder: (context, index) {
                                            final type = _questionTypes[index];
                                            final isSelected =
                                                _selectedQuestionTypes.contains(
                                                  type,
                                                );
                                            final pointsPerQuestion =
                                                _questionTypePoints[type] ?? 1;

                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              margin: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color:
                                                      isSelected
                                                          ? const Color(
                                                            0xFF6A3DE8,
                                                          )
                                                          : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Theme(
                                                          data: ThemeData(
                                                            checkboxTheme:
                                                                CheckboxThemeData(
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                ),
                                                          ),
                                                          child: Checkbox(
                                                            value: isSelected,
                                                            activeColor:
                                                                const Color(
                                                                  0xFF6A3DE8,
                                                                ),
                                                            onChanged: (value) {
                                                              if (value ==
                                                                  true) {
                                                                if (!_selectedQuestionTypes
                                                                    .contains(
                                                                      type,
                                                                    )) {
                                                                  setModalState(
                                                                    () {
                                                                      _selectedQuestionTypes
                                                                          .add(
                                                                            type,
                                                                          );
                                                                    },
                                                                  );
                                                                }
                                                              } else {
                                                                if (_selectedQuestionTypes
                                                                        .length >
                                                                    1) {
                                                                  setModalState(() {
                                                                    _selectedQuestionTypes
                                                                        .remove(
                                                                          type,
                                                                        );
                                                                  });
                                                                }
                                                              }
                                                            },
                                                          ),
                                                        ),

                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                _formatQuestionType(
                                                                  type,
                                                                ),
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                  fontFamily:
                                                                      'Inter',
                                                                ),
                                                              ),
                                                              Text(
                                                                '$pointsPerQuestion points per question',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .grey[600],
                                                                  fontFamily:
                                                                      'Inter',
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),

                                                        if (isSelected)
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .help_outline,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                            onPressed: () {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (
                                                                      context,
                                                                    ) => AlertDialog(
                                                                      title: Text(
                                                                        'Example: ${_formatQuestionType(type)}',
                                                                      ),
                                                                      content:
                                                                          _buildQuestionTypeExample(
                                                                            type,
                                                                          ),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed:
                                                                              () => Navigator.pop(
                                                                                context,
                                                                              ),
                                                                          child: const Text(
                                                                            'Close',
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                              );
                                                            },
                                                          ),
                                                      ],
                                                    ),
                                                  ),

                                                  if (isSelected)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            16,
                                                            0,
                                                            16,
                                                            16,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            decoration: BoxDecoration(
                                                              border: Border.all(
                                                                color:
                                                                    Colors
                                                                        .grey[300]!,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                IconButton(
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .remove,
                                                                    size: 16,
                                                                  ),
                                                                  onPressed: () {
                                                                    final currentValue =
                                                                        int.tryParse(
                                                                          _questionTypeCounts[type]?.text ??
                                                                              '0',
                                                                        ) ??
                                                                        0;
                                                                    if (currentValue >
                                                                        0) {
                                                                      setModalState(() {
                                                                        _questionTypeCounts[type]?.text =
                                                                            (currentValue -
                                                                                    1)
                                                                                .toString();
                                                                      });
                                                                    }
                                                                  },
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        minWidth:
                                                                            36,
                                                                        minHeight:
                                                                            36,
                                                                      ),
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                ),

                                                                SizedBox(
                                                                  width: 40,
                                                                  child: TextField(
                                                                    controller:
                                                                        _questionTypeCounts[type],
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .number,
                                                                    decoration: const InputDecoration(
                                                                      border:
                                                                          InputBorder
                                                                              .none,
                                                                      contentPadding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                    ),
                                                                    inputFormatters: [
                                                                      FilteringTextInputFormatter
                                                                          .digitsOnly,
                                                                    ],
                                                                    onChanged: (
                                                                      _,
                                                                    ) {
                                                                      setModalState(
                                                                        () {},
                                                                      );
                                                                    },
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontFamily:
                                                                          'Inter',
                                                                    ),
                                                                  ),
                                                                ),

                                                                IconButton(
                                                                  icon:
                                                                      const Icon(
                                                                        Icons
                                                                            .add,
                                                                        size:
                                                                            16,
                                                                      ),
                                                                  onPressed: () {
                                                                    final currentValue =
                                                                        int.tryParse(
                                                                          _questionTypeCounts[type]?.text ??
                                                                              '0',
                                                                        ) ??
                                                                        0;
                                                                    setModalState(() {
                                                                      _questionTypeCounts[type]
                                                                              ?.text =
                                                                          (currentValue +
                                                                                  1)
                                                                              .toString();
                                                                    });
                                                                  },
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        minWidth:
                                                                            36,
                                                                        minHeight:
                                                                            36,
                                                                      ),
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                            width: 16,
                                                          ),

                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 8,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    Colors
                                                                        .grey[100],
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Text(
                                                                    'Subtotal:',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      color:
                                                                          Colors
                                                                              .grey[700],
                                                                      fontFamily:
                                                                          'Inter',
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '${(int.tryParse(_questionTypeCounts[type]?.text ?? '0') ?? 0) * pointsPerQuestion} points',
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Color(
                                                                        0xFF6A3DE8,
                                                                      ),
                                                                      fontFamily:
                                                                          'Inter',
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _generateAssessmentQuestions();
                              },
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text(
                                'Generate Assessment',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A3DE8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildQuestionTypeExample(String type) {
    switch (type) {
      case 'multiple-choice':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What is the capital of France?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            _buildExampleOption('Paris', true),
            _buildExampleOption('London', false),
            _buildExampleOption('Berlin', false),
            _buildExampleOption('Madrid', false),
          ],
        );
      case 'multiple-answer':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Which of the following are primary colors?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            _buildExampleOption('Red', true),
            _buildExampleOption('Green', false),
            _buildExampleOption('Blue', true),
            _buildExampleOption('Yellow', true),
          ],
        );
      case 'true-false':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Earth is flat.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            _buildExampleOption('True', false),
            _buildExampleOption('False', true),
          ],
        );
      case 'fill-in-the-blank':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The process of plants making food using sunlight is called ____________.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                'Answer: photosynthesis',
                style: TextStyle(color: Color(0xFF1976D2), fontFamily: 'Inter'),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                'Sample answer: Newton\'s Third Law states that for every action, there is an equal and opposite reaction. When one object exerts a force on a second object, the second object exerts an equal force in the opposite direction on the first object.',
                style: TextStyle(color: Color(0xFF1976D2), fontFamily: 'Inter'),
              ),
            ),
          ],
        );
      default:
        return const Text(
          'Example not available for this question type.',
          style: TextStyle(fontFamily: 'Inter'),
        );
    }
  }

  Widget _buildExampleOption(String text, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCorrect
                      ? const Color(0xFF6A3DE8).withOpacity(0.1)
                      : Colors.transparent,
              border: Border.all(
                color: isCorrect ? const Color(0xFF6A3DE8) : Colors.grey,
                width: 1.5,
              ),
            ),
            child:
                isCorrect
                    ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: Color(0xFF6A3DE8),
                      ),
                    )
                    : null,
          ),
          Text(
            text,
            style: TextStyle(
              color: isCorrect ? const Color(0xFF6A3DE8) : Colors.black87,
              fontFamily: 'Inter',
            ),
          ),
        ],
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
            _buildCustomAppBar(),

            Expanded(
              child:
                  _chatHistory.isEmpty
                      ? _buildWelcomeScreen()
                      : _buildChatMessages(),
            ),

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
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            splashRadius: 24,
          ),

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
                  value: 'gemini-2.5-pro-preview-03-25',
                  child: Text('Gemini 2.5 Pro'),
                ),
                DropdownMenuItem(
                  value: 'gemini-2.0-flash',
                  child: Text('Gemini 2.0 Flash'),
                ),
                DropdownMenuItem(
                  value: 'gemini-2.0-flash-lite',
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

          IconButton(
            icon: Icon(
              Icons.vpn_key,
              color: _isApiKeySet ? Colors.green : Colors.orange,
            ),
            onPressed: _showApiKeyDialog,
            tooltip: _isApiKeySet ? 'Update API Key' : 'Set API Key',
            splashRadius: 24,
          ),

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

  Widget _buildWelcomeScreen() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 32),

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

                if (!_isApiKeySet)
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
                              onPressed: _showApiKeyDialog,
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
                            onPressed:
                                _isApiKeySet
                                    ? _pickPdfFile
                                    : () {
                                      setState(() {
                                        _errorMessage =
                                            'Please set your API key first';
                                      });
                                      _showApiKeyDialog();
                                    },
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
                            onPressed:
                                _isApiKeySet
                                    ? () {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(FocusNode());
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        Future.delayed(
                                          const Duration(milliseconds: 100),
                                          () {
                                            _promptController.text =
                                                'Hello, I need help with creating an assessment.';
                                          },
                                        );
                                      });
                                    }
                                    : () {
                                      setState(() {
                                        _errorMessage =
                                            'Please set your API key first';
                                      });
                                      _showApiKeyDialog();
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

  Widget _buildChatMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final message = _chatHistory[index];
        final isUser = message['role'] == 'user';

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

                  _buildAssessmentStatistics(),
                  const SizedBox(height: 24),

                  const Text(
                    'All Questions & Answers:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ..._buildAllQuestions(),
                  const SizedBox(height: 16),

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

    return _buildChatMessageBubble(
      message['content'],
      false,
      timestamp: message['timestamp'],
    );
  }

  Widget _buildAssessmentStatistics() {
    if (_generatedQuestions == null) {
      return const SizedBox.shrink();
    }

    final questions = _generatedQuestions!['questions'] as List<dynamic>;
    final questionTypes = <String, int>{};
    int totalPoints = 0;

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

          const Text(
            'Question Types:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
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
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatQuestionType(entry.key),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'Inter',
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
      case 'code-snippet':
        return 'Code Snippet';
      case 'diagram-interpretation':
        return 'Diagram';
      case 'math-equation':
        return 'Math Equation';
      case 'chemical-formula':
        return 'Chemical Formula';
      case 'language-translation':
        return 'Translation';
      default:
        return type
            .split('-')
            .map(
              (word) => word.substring(0, 1).toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF6A3DE8), size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAllQuestions() {
    if (_generatedQuestions == null) {
      return [];
    }

    final questions = _generatedQuestions!['questions'] as List<dynamic>;
    final answers = _generatedQuestions!['answers'] as List<dynamic>;
    final allQuestions = <Widget>[];

    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final questionId = question['questionId'];

      final answer = answers.firstWhere(
        (a) => a['questionId'] == questionId,
        orElse: () => {'answerText': 'No answer available', 'reasoning': ''},
      );

      allQuestions.add(
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${i + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A3DE8),
                      fontFamily: 'Inter',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
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
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    '${question['points']} points',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[700],
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: _buildFormattedText(question['questionText']),
              ),
              const SizedBox(height: 16),

              if (question['options'] != null &&
                  (question['options'] as List).isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Options:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            (question['options'] as List).map((option) {
                              final isAnswer =
                                  question['questionType'] == 'multiple-choice'
                                      ? answer['answerText'] == option
                                      : question['questionType'] ==
                                              'multiple-answer' &&
                                          answer['answerText'] is List &&
                                          (answer['answerText'] as List)
                                              .contains(option);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      margin: const EdgeInsets.only(
                                        right: 8,
                                        top: 2,
                                      ),
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
                                      child: _buildFormattedText(
                                        option,
                                        textStyle: TextStyle(
                                          fontSize: 14,
                                          color:
                                              isAnswer
                                                  ? const Color(0xFF6A3DE8)
                                                  : Colors.black87,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),
              const Text(
                'Answer:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (answer['answerText'] is List)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Correct Answers:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1976D2),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...((answer['answerText'] as List)
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '• ',
                                        style: TextStyle(
                                          color: Color(0xFF1976D2),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildFormattedText(
                                          item.toString(),
                                          textStyle: const TextStyle(
                                            color: Color(0xFF1976D2),
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList()),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Correct Answer:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1976D2),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildFormattedText(
                            answer['answerText']?.toString() ?? 'Not available',
                            textStyle: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),

                    if (answer['reasoning'] != null &&
                        answer['reasoning'].toString().trim().isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Explanation:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1976D2),
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildFormattedText(
                            answer['reasoning'].toString(),
                            textStyle: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return allQuestions;
  }

  Widget _buildFormattedText(String text, {TextStyle? textStyle}) {
    final defaultStyle =
        textStyle ??
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        );

    final RegExp latexPattern = RegExp(r'\$(.*?)\$');
    final matches = latexPattern.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final List<InlineSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: defaultStyle,
          ),
        );
      }

      final latexContent = match.group(1) ?? '';

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            latexContent,
            textStyle: defaultStyle,
            mathStyle: MathStyle.text,
            onErrorFallback:
                (err) => Text(
                  '\$${err.message}\$',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: defaultStyle.fontSize,
                  ),
                ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: defaultStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.visible,
    );
  }

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
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed:
                  _isApiKeySet
                      ? _pickPdfFile
                      : () {
                        setState(() {
                          _errorMessage = 'Please set your API key first';
                        });
                        _showApiKeyDialog();
                      },
              tooltip: 'Upload PDF',
              color: const Color(0xFF6A3DE8),
              splashRadius: 24,
            ),

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

  Widget _buildOnboardingScreen() {
    return Scaffold(
      body: PageView(
        controller: _onboardingController,
        children: [
          _buildOnboardingPage(
            title: 'Welcome to Your AI Assistant',
            description:
                'Your intelligent companion for creating educational assessments, analyzing documents, and more.',
            icon: Icons.smart_toy,
            backgroundColor: const Color(0xFF6A3DE8),
            isFirstPage: true,
          ),

          _buildOnboardingPage(
            title: 'Set Up Your API Key',
            description:
                'You\'ll need a Gemini API key from Google AI Studio to use all features. Set it up once and you\'re ready to go.',
            icon: Icons.vpn_key,
            backgroundColor: Colors.orange,
          ),

          _buildOnboardingPage(
            title: 'Upload PDFs for Analysis',
            description:
                'Upload your educational content and select specific pages to process.',
            icon: Icons.description,
            backgroundColor: const Color(0xFF4CAF50),
          ),

          _buildOnboardingPage(
            title: 'Generate Assessments',
            description:
                'Create customized questions with adjustable difficulty, question types, and point values.',
            icon: Icons.assignment,
            backgroundColor: const Color(0xFFFFC107),
          ),

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

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 120, color: Colors.white.withOpacity(0.9)),
                  const SizedBox(height: 48),

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

            Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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

                  Row(
                    children: List.generate(5, (index) {
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
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
