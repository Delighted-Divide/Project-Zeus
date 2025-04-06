import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import '../utils/constants.dart';
import '../utils/text_formatter.dart';

/// Service for interacting with the Gemini AI API
class ApiService {
  final Logger _logger = Logger();
  final String _apiKey;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // For tracking API calls
  int _requestCounter = 0;

  /// Constructor
  ApiService(this._apiKey);

  /// Send a prompt to the Gemini API and get a response
  Future<String> sendPrompt(String prompt, String modelName) async {
    _logger.i('Sending prompt to Gemini API using model: $modelName');

    try {
      // Build the API URL
      final url =
          '${AppConstants.geminiApiBaseUrl}$modelName:generateContent?key=$_apiKey';

      // Prepare the request payload
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

      // Log the request
      await _logToCloud('request_${++_requestCounter}.txt', prompt);

      // Make the HTTP request
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

          // Log the response
          await _logToCloud('response_${_requestCounter}.txt', responseText);

          return responseText;
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
    } catch (e) {
      _logger.e('Error sending prompt to Gemini API', error: e);
      rethrow;
    }
  }

  /// Generate assessment questions from PDF text
  Future<Map<String, dynamic>> generateAssessmentQuestions({
    required String extractedText,
    required String difficulty,
    required Map<String, int> questionDistribution,
    required Map<String, int> questionTypePoints,
    required int totalPoints,
    required String modelName,
    required RangeValues pageRange,
  }) async {
    _logger.i('Generating assessment questions using model: $modelName');

    // Determine the language of the text
    final language = await _detectLanguage(extractedText);
    _logger.i('Detected language: $language');

    // Save the extracted text for debugging
    await _logToCloud('extracted_text.txt', extractedText);

    // Track required questions and generated questions
    final Map<String, int> requiredQuestions = Map.from(questionDistribution);
    final Map<String, int> generatedQuestions = {};
    questionDistribution.keys.forEach((key) => generatedQuestions[key] = 0);

    // Calculate total questions
    int totalQuestionCount = 0;
    requiredQuestions.forEach((_, count) => totalQuestionCount += count);

    // Initialize result maps for all questions, answers, and tags
    List<dynamic> allQuestions = [];
    List<dynamic> allAnswers = [];
    List<dynamic> allTags = [];

    // Set to track unique question IDs
    Set<String> usedQuestionIds = {};

    // Tracking attempt count to prevent infinite loops
    int attemptCount = 0;
    final int maxAttempts = 10; // Reasonable maximum number of attempts

    // Continue generating until we have all required questions or reach max attempts
    while (!_haveAllRequiredQuestions(requiredQuestions, generatedQuestions) &&
        attemptCount < maxAttempts) {
      attemptCount++;
      _logger.i('Generation attempt #$attemptCount');

      // Create a distribution for this attempt, focusing on missing questions
      final Map<String, int> currentDistribution =
          _getMissingQuestionDistribution(
            requiredQuestions,
            generatedQuestions,
            maxQuestionsPerChunk: 7,
          );

      if (currentDistribution.isEmpty) {
        _logger.i('No more questions needed, breaking the loop');
        break;
      }

      _logger.i('Generating questions for distribution: $currentDistribution');

      try {
        // Generate questions for the current distribution
        final result = await _generateQuestionsChunk(
          extractedText: extractedText,
          difficulty: difficulty,
          questionDistribution: currentDistribution,
          questionTypePoints: questionTypePoints,
          modelName: modelName,
          pageRange: pageRange,
          language: language,
          chunkIndex: attemptCount,
          usedIds: usedQuestionIds,
        );

        // Process the results
        if (result != null) {
          // Extract questions and update tracking
          final questions = result['questions'] as List;
          final answers = result['answers'] as List;
          final tags = result['tags'] as List? ?? [];

          _logger.i('Generated ${questions.length} questions in this chunk');

          // Add questions to our collection, ensuring unique IDs
          for (final question in questions) {
            if (question is Map &&
                question.containsKey('questionId') &&
                question.containsKey('questionType')) {
              final String questionId = question['questionId'];
              final String questionType = question['questionType'];

              // If this is a new question ID
              if (!usedQuestionIds.contains(questionId)) {
                usedQuestionIds.add(questionId);
                allQuestions.add(question);

                // Update our tracking counts
                generatedQuestions[questionType] =
                    (generatedQuestions[questionType] ?? 0) + 1;

                // Find and add the corresponding answer
                final answer = answers.firstWhere(
                  (a) =>
                      a is Map &&
                      a.containsKey('questionId') &&
                      a['questionId'] == questionId,
                  orElse: () => null,
                );

                if (answer != null) {
                  // Ensure answer type matches question type
                  answer['answerType'] = questionType;
                  allAnswers.add(answer);
                } else {
                  // Create a placeholder answer if none exists
                  allAnswers.add(
                    _createPlaceholderAnswer(question as Map<String, dynamic>),
                  );
                }
              }
            }
          }

          // Add new tags
          for (final tag in tags) {
            if (tag is Map && tag.containsKey('name')) {
              final String tagName = tag['name'].toLowerCase();

              // Check if this tag is already in our collection
              bool isDuplicate = allTags.any(
                (t) =>
                    t is Map &&
                    t.containsKey('name') &&
                    t['name'].toLowerCase() == tagName,
              );

              if (!isDuplicate) {
                allTags.add(tag);
              }
            }
          }

          // Log progress
          _logger.i(
            'Progress: ${_progressSummary(requiredQuestions, generatedQuestions)}',
          );
        }
      } catch (e) {
        _logger.e('Error in generation attempt #$attemptCount', error: e);
        await _logToCloud('error_attempt_$attemptCount.txt', e.toString());
        // Continue to next attempt despite errors
      }

      // Small delay between attempts
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Final result
    final resultMap = {
      'questions': allQuestions,
      'answers': allAnswers,
      'tags': allTags,
    };

    // Log final stats
    final stats = '''
Final Generation Statistics:
- Total questions requested: $totalQuestionCount
- Total questions generated: ${allQuestions.length}
- Question type breakdown:
${generatedQuestions.entries.map((e) => '  - ${e.key}: ${e.value}/${requiredQuestions[e.key] ?? 0}').join('\n')}
- Generation attempts: $attemptCount
''';

    _logger.i(stats);
    await _logToCloud('generation_stats.txt', stats);
    await _logToCloud(
      'final_result.json',
      JsonEncoder.withIndent('  ').convert(resultMap),
    );

    return resultMap;
  }

  /// Create a progress summary string
  String _progressSummary(
    Map<String, int> required,
    Map<String, int> generated,
  ) {
    return required.entries
        .map((entry) {
          final type = entry.key;
          final target = entry.value;
          final current = generated[type] ?? 0;
          return '$type: $current/$target';
        })
        .join(', ');
  }

  /// Check if we have all required questions
  bool _haveAllRequiredQuestions(
    Map<String, int> required,
    Map<String, int> generated,
  ) {
    for (final entry in required.entries) {
      final type = entry.key;
      final target = entry.value;
      final current = generated[type] ?? 0;

      if (current < target) {
        return false;
      }
    }
    return true;
  }

  /// Get distribution of missing questions for next generation attempt
  Map<String, int> _getMissingQuestionDistribution(
    Map<String, int> required,
    Map<String, int> generated, {
    int maxQuestionsPerChunk = 7,
  }) {
    final Map<String, int> missing = {};
    int totalMissing = 0;

    // First pass: determine how many of each type are missing
    for (final entry in required.entries) {
      final type = entry.key;
      final target = entry.value;
      final current = generated[type] ?? 0;

      if (current < target) {
        missing[type] = target - current;
        totalMissing += target - current;
      }
    }

    // If nothing is missing, return empty map
    if (totalMissing == 0) {
      return {};
    }

    // If total missing is less than or equal to our chunk size, return as is
    if (totalMissing <= maxQuestionsPerChunk) {
      return missing;
    }

    // Otherwise, proportionally limit each type to fit in one chunk
    final Map<String, int> limitedDistribution = {};
    double scale = maxQuestionsPerChunk / totalMissing;

    int allocatedTotal = 0;

    // First pass - allocate based on proportion with floor
    for (final entry in missing.entries) {
      final type = entry.key;
      final count = entry.value;

      // Allocate at least 1, up to scaled amount (floored)
      final allocation = max(1, (count * scale).floor());

      // Don't exceed what's actually missing
      final finalAllocation = min(allocation, count);

      limitedDistribution[type] = finalAllocation;
      allocatedTotal += finalAllocation;

      // Don't exceed our maximum
      if (allocatedTotal >= maxQuestionsPerChunk) {
        break;
      }
    }

    return limitedDistribution;
  }

  /// Create a placeholder answer for a question
  Map<String, dynamic> _createPlaceholderAnswer(Map<String, dynamic> question) {
    final String questionId = question['questionId'];
    final String questionType = question['questionType'];

    Map<String, dynamic> answer = {
      'answerId': 'auto_${questionId}',
      'questionId': questionId,
      'answerType': questionType,
      'reasoning': 'Auto-generated placeholder answer',
    };

    // Set appropriate answer text based on question type
    if (questionType == 'true-false') {
      answer['answerText'] = 'False';
    } else if (questionType == 'multiple-choice' &&
        question.containsKey('options') &&
        question['options'] is List &&
        (question['options'] as List).isNotEmpty) {
      answer['answerText'] = (question['options'] as List).first;
    } else if (questionType == 'multiple-answer' &&
        question.containsKey('options') &&
        question['options'] is List &&
        (question['options'] as List).isNotEmpty) {
      answer['answerText'] = [(question['options'] as List).first];
    } else if (questionType == 'fill-in-the-blank') {
      answer['answerText'] = '[Placeholder]';
    } else {
      answer['answerText'] = 'See answer key';
    }

    return answer;
  }

  /// Generate a single chunk of questions with a particular distribution
  Future<Map<String, dynamic>?> _generateQuestionsChunk({
    required String extractedText,
    required String difficulty,
    required Map<String, int> questionDistribution,
    required Map<String, int> questionTypePoints,
    required String modelName,
    required RangeValues pageRange,
    required String language,
    required int chunkIndex,
    required Set<String> usedIds,
  }) async {
    _logger.i(
      'Generating chunk #$chunkIndex with distribution: $questionDistribution',
    );

    // Create the distribution description
    final distributionInfo = questionDistribution.entries
        .map(
          (entry) =>
              "${entry.key}: ${entry.value} questions (${questionTypePoints[entry.key] ?? 1} points each)",
        )
        .join(', ');

    // Create a unique prefix for this chunk's question IDs
    final idPrefix = 'c${chunkIndex}_';

    // Create prompt with enhanced instructions
    final prompt = '''
You are an expert education assessment creator. Create assessment questions based on the following text.

Text from PDF (pages ${pageRange.start.toInt()} to ${pageRange.end.toInt()}):
$extractedText

Create a set of assessment questions with these specifications:
- Difficulty level: $difficulty
- Question distribution: $distributionInfo
- IMPORTANT: Generate all questions and answers in $language language

IMPORTANT GUIDELINES:
1. Each question MUST start with explanatory text that describes the problem clearly.
2. Each questionId MUST start with "$idPrefix" (e.g. "${idPrefix}q1", "${idPrefix}q2")
3. Always add descriptive text before any equations.
4. For math equations, use LaTeX notation with simple backslashes, like: \$\\sqrt{x}\$ 
5. Include domain-specific questions where appropriate (formulas, equations, etc.)
6. CRITICAL: Make sure that for EACH question type, the answerType field must match the questionType field EXACTLY
7. For true-false questions, ONLY use "True" or "False" as the answerText
8. Format your response as valid JSON with this structure:

{
  "questions": [
    {
      "questionId": "${idPrefix}q1",
      "questionType": "multiple-choice",
      "questionText": "What is the derivative of x²? \$\\frac{d}{dx}(x^2) = ?\$",
      "options": ["2x", "x²", "0", "1"],
      "points": 1
    }
  ],
  "answers": [
    {
      "answerId": "${idPrefix}a1",
      "questionId": "${idPrefix}q1",
      "answerType": "multiple-choice",
      "answerText": "2x",
      "reasoning": "The derivative of x² is 2x using the power rule."
    }
  ],
  "tags": []
}

You MUST generate EXACTLY the number of questions specified in the distribution. Each question MUST have a matching answer with the same ID pattern.

Only respond with valid JSON. Do not include markdown code blocks or any other text.
''';

    // Log the prompt
    await _logToCloud('chunk_${chunkIndex}_prompt.txt', prompt);

    try {
      // Call the Gemini API
      final result = await _callGeminiApi(prompt, modelName, chunkIndex);

      // Validate and fix the results
      if (result != null) {
        // Ensure all question IDs are unique and use the correct prefix
        final List<dynamic> questions = result['questions'] as List;
        final List<dynamic> answers = result['answers'] as List;

        // Check each question for ID uniqueness and prefix
        for (int i = 0; i < questions.length; i++) {
          if (questions[i] is Map && questions[i].containsKey('questionId')) {
            String questionId = questions[i]['questionId'];

            // If ID doesn't have the correct prefix, add it
            if (!questionId.startsWith(idPrefix)) {
              final newId = '$idPrefix$questionId';
              questions[i]['questionId'] = newId;

              // Find and update corresponding answer
              for (int j = 0; j < answers.length; j++) {
                if (answers[j] is Map &&
                    answers[j].containsKey('questionId') &&
                    answers[j]['questionId'] == questionId) {
                  answers[j]['questionId'] = newId;

                  // Update answer ID too if needed
                  if (answers[j].containsKey('answerId')) {
                    answers[j]['answerId'] = '${idPrefix}a${i + 1}';
                  }
                }
              }
            }

            // If ID is already used, generate a new one
            if (usedIds.contains(questions[i]['questionId'])) {
              final newId =
                  '${idPrefix}q${i + 1}_${DateTime.now().microsecondsSinceEpoch}';

              // Find and update corresponding answer
              for (int j = 0; j < answers.length; j++) {
                if (answers[j] is Map &&
                    answers[j].containsKey('questionId') &&
                    answers[j]['questionId'] == questions[i]['questionId']) {
                  answers[j]['questionId'] = newId;

                  // Update answer ID too
                  if (answers[j].containsKey('answerId')) {
                    answers[j]['answerId'] =
                        '${idPrefix}a${i + 1}_${DateTime.now().microsecondsSinceEpoch}';
                  }
                }
              }

              // Update question ID
              questions[i]['questionId'] = newId;
            }
          }
        }

        return {
          'questions': questions,
          'answers': answers,
          'tags': result.containsKey('tags') ? result['tags'] : [],
        };
      }

      return null;
    } catch (e) {
      _logger.e('Error generating questions chunk #$chunkIndex: $e');
      await _logToCloud('chunk_${chunkIndex}_error.txt', e.toString());
      return null;
    }
  }

  /// Detect the language of the text
  Future<String> _detectLanguage(String text) async {
    // Default to English
    String language = 'English';

    try {
      // Sample the text
      final sample = text.length > 500 ? text.substring(0, 500) : text;

      // Prepare a language detection prompt
      final prompt = '''
Analyze the following text and determine what language it is written in.
Only respond with the language name (e.g., "English", "Hindi", "Spanish", etc.).

Text sample:
$sample
''';

      // Call the API with minimal tokens
      final url =
          '${AppConstants.geminiApiBaseUrl}gemini-2.0-flash:generateContent?key=$_apiKey';
      final payload = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 10},
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          language =
              data['candidates'][0]['content']['parts'][0]['text'] ?? 'English';
          language = language.trim().replaceAll('"', '').replaceAll('.', '');
        }
      }
    } catch (e) {
      _logger.e('Error detecting language: $e');
      // Fall back to English
    }

    return language;
  }

  /// Call the Gemini API with detailed logging
  Future<Map<String, dynamic>?> _callGeminiApi(
    String prompt,
    String modelName,
    int chunkIndex,
  ) async {
    final requestId = ++_requestCounter;
    _logger.i(
      'API Request #$requestId (Chunk $chunkIndex) - Using model: $modelName',
    );

    final url =
        '${AppConstants.geminiApiBaseUrl}$modelName:generateContent?key=$_apiKey';

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

    // Create timestamp for this request
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final logPrefix = 'api_${timestamp}_req${requestId}_chunk${chunkIndex}';

    try {
      // Log the request
      await _logToCloud('${logPrefix}_request.txt', prompt);

      // Make the API call
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      _logger.i(
        'API Request #$requestId - Response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final responseText =
              data['candidates'][0]['content']['parts'][0]['text'] ?? '';

          // Log the response
          await _logToCloud('${logPrefix}_response.txt', responseText);

          // Extract JSON from response
          String jsonStr = responseText.trim();

          // Remove code block markers
          if (jsonStr.startsWith('```json')) {
            jsonStr = jsonStr.substring(7);
          } else if (jsonStr.startsWith('```')) {
            jsonStr = jsonStr.substring(3);
          }
          if (jsonStr.endsWith('```')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 3);
          }

          // Sanitize and parse JSON
          await _logToCloud('${logPrefix}_presanitized.json', jsonStr);

          jsonStr = TextFormatter.sanitizeJsonString(jsonStr);

          await _logToCloud('${logPrefix}_sanitized.json', jsonStr);

          try {
            final generatedQuestions =
                jsonDecode(jsonStr) as Map<String, dynamic>;

            // Validate structure
            if (!generatedQuestions.containsKey('questions') ||
                !generatedQuestions.containsKey('answers')) {
              throw Exception(
                'Invalid response format: missing questions or answers',
              );
            }

            // Ensure questions and answers are lists
            if (!(generatedQuestions['questions'] is List) ||
                !(generatedQuestions['answers'] is List)) {
              throw Exception(
                'Invalid response format: questions or answers are not lists',
              );
            }

            final questions = generatedQuestions['questions'] as List;
            final answers = generatedQuestions['answers'] as List;

            _logger.i(
              'Generated ${questions.length} questions and ${answers.length} answers',
            );

            await _logToCloud(
              '${logPrefix}_parsed.json',
              JsonEncoder.withIndent('  ').convert(generatedQuestions),
            );

            return generatedQuestions;
          } catch (jsonError) {
            _logger.e('JSON parsing error', error: jsonError);
            await _logToCloud(
              '${logPrefix}_parse_error.txt',
              jsonError.toString(),
            );
            return null;
          }
        } else {
          _logger.e('No content found in API response');
          return null;
        }
      } else {
        _logger.e('API request failed with status: ${response.statusCode}');
        await _logToCloud('${logPrefix}_error_response.txt', response.body);
        return null;
      }
    } catch (e) {
      _logger.e('Request failed with exception', error: e);
      await _logToCloud('${logPrefix}_exception.txt', e.toString());
      return null;
    }
  }

  /// Log content to Firebase Cloud Storage
  Future<void> _logToCloud(String filename, String content) async {
    try {
      // Create folder structure based on date
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      final ref = _storage.ref().child('gemini_logs/$date/$filename');

      // Upload content as a text file
      await ref.putString(content, format: PutStringFormat.raw);

      _logger.i('Logged to cloud storage: gemini_logs/$date/$filename');
    } catch (e) {
      _logger.e('Error logging to cloud storage: $e');
      // Fall back to console logging if cloud storage fails
      _logger.i(
        'Content preview: ${content.substring(0, min(100, content.length))}...',
      );
    }
  }
}
