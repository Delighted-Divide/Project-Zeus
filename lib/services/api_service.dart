import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import '../utils/constants.dart';
import '../utils/text_formatter.dart';

class ApiService {
  final Logger _logger = Logger();
  final String _apiKey;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  int _requestCounter = 0;

  ApiService(this._apiKey);

  Future<String> sendPrompt(String prompt, String modelName) async {
    _logger.i('Sending prompt to Gemini API using model: $modelName');

    try {
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
          'temperature': 0.7,
          'maxOutputTokens': 1024,
          'topP': 0.95,
          'topK': 40,
        },
      };

      await _logToCloud('request_${++_requestCounter}.txt', prompt);

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

    final language = await _detectLanguage(extractedText);
    _logger.i('Detected language: $language');

    await _logToCloud('extracted_text.txt', extractedText);

    final Map<String, int> requiredQuestions = Map.from(questionDistribution);
    final Map<String, int> generatedQuestions = {};
    questionDistribution.keys.forEach((key) => generatedQuestions[key] = 0);

    int totalQuestionCount = 0;
    requiredQuestions.forEach((_, count) => totalQuestionCount += count);

    List<dynamic> allQuestions = [];
    List<dynamic> allAnswers = [];
    List<dynamic> allTags = [];

    Set<String> usedQuestionIds = {};

    int attemptCount = 0;
    final int maxAttempts = 10;

    while (!_haveAllRequiredQuestions(requiredQuestions, generatedQuestions) &&
        attemptCount < maxAttempts) {
      attemptCount++;
      _logger.i('Generation attempt #$attemptCount');

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

        if (result != null) {
          final questions = result['questions'] as List;
          final answers = result['answers'] as List;
          final tags = result['tags'] as List? ?? [];

          _logger.i('Generated ${questions.length} questions in this chunk');

          for (final question in questions) {
            if (question is Map &&
                question.containsKey('questionId') &&
                question.containsKey('questionType')) {
              final String questionId = question['questionId'];
              final String questionType = question['questionType'];

              if (!usedQuestionIds.contains(questionId)) {
                usedQuestionIds.add(questionId);
                allQuestions.add(question);

                generatedQuestions[questionType] =
                    (generatedQuestions[questionType] ?? 0) + 1;

                final answer = answers.firstWhere(
                  (a) =>
                      a is Map &&
                      a.containsKey('questionId') &&
                      a['questionId'] == questionId,
                  orElse: () => null,
                );

                if (answer != null) {
                  answer['answerType'] = questionType;
                  allAnswers.add(answer);
                } else {
                  allAnswers.add(
                    _createPlaceholderAnswer(question as Map<String, dynamic>),
                  );
                }
              }
            }
          }

          for (final tag in tags) {
            if (tag is Map && tag.containsKey('name')) {
              final String tagName = tag['name'].toLowerCase();

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

          _logger.i(
            'Progress: ${_progressSummary(requiredQuestions, generatedQuestions)}',
          );
        }
      } catch (e) {
        _logger.e('Error in generation attempt #$attemptCount', error: e);
        await _logToCloud('error_attempt_$attemptCount.txt', e.toString());
      }

      await Future.delayed(Duration(milliseconds: 500));
    }

    final resultMap = {
      'questions': allQuestions,
      'answers': allAnswers,
      'tags': allTags,
    };

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

  Map<String, int> _getMissingQuestionDistribution(
    Map<String, int> required,
    Map<String, int> generated, {
    int maxQuestionsPerChunk = 7,
  }) {
    final Map<String, int> missing = {};
    int totalMissing = 0;

    for (final entry in required.entries) {
      final type = entry.key;
      final target = entry.value;
      final current = generated[type] ?? 0;

      if (current < target) {
        missing[type] = target - current;
        totalMissing += target - current;
      }
    }

    if (totalMissing == 0) {
      return {};
    }

    if (totalMissing <= maxQuestionsPerChunk) {
      return missing;
    }

    final Map<String, int> limitedDistribution = {};
    double scale = maxQuestionsPerChunk / totalMissing;

    int allocatedTotal = 0;

    for (final entry in missing.entries) {
      final type = entry.key;
      final count = entry.value;

      final allocation = max(1, (count * scale).floor());

      final finalAllocation = min(allocation, count);

      limitedDistribution[type] = finalAllocation;
      allocatedTotal += finalAllocation;

      if (allocatedTotal >= maxQuestionsPerChunk) {
        break;
      }
    }

    return limitedDistribution;
  }

  Map<String, dynamic> _createPlaceholderAnswer(Map<String, dynamic> question) {
    final String questionId = question['questionId'];
    final String questionType = question['questionType'];

    Map<String, dynamic> answer = {
      'answerId': 'auto_${questionId}',
      'questionId': questionId,
      'answerType': questionType,
      'reasoning': 'Auto-generated placeholder answer',
    };

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

    final distributionInfo = questionDistribution.entries
        .map(
          (entry) =>
              "${entry.key}: ${entry.value} questions (${questionTypePoints[entry.key] ?? 1} points each)",
        )
        .join(', ');

    final idPrefix = 'c${chunkIndex}_';

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

    await _logToCloud('chunk_${chunkIndex}_prompt.txt', prompt);

    try {
      final result = await _callGeminiApi(prompt, modelName, chunkIndex);

      if (result != null) {
        final List<dynamic> questions = result['questions'] as List;
        final List<dynamic> answers = result['answers'] as List;

        for (int i = 0; i < questions.length; i++) {
          if (questions[i] is Map && questions[i].containsKey('questionId')) {
            String questionId = questions[i]['questionId'];

            if (!questionId.startsWith(idPrefix)) {
              final newId = '$idPrefix$questionId';
              questions[i]['questionId'] = newId;

              for (int j = 0; j < answers.length; j++) {
                if (answers[j] is Map &&
                    answers[j].containsKey('questionId') &&
                    answers[j]['questionId'] == questionId) {
                  answers[j]['questionId'] = newId;

                  if (answers[j].containsKey('answerId')) {
                    answers[j]['answerId'] = '${idPrefix}a${i + 1}';
                  }
                }
              }
            }

            if (usedIds.contains(questions[i]['questionId'])) {
              final newId =
                  '${idPrefix}q${i + 1}_${DateTime.now().microsecondsSinceEpoch}';

              for (int j = 0; j < answers.length; j++) {
                if (answers[j] is Map &&
                    answers[j].containsKey('questionId') &&
                    answers[j]['questionId'] == questions[i]['questionId']) {
                  answers[j]['questionId'] = newId;

                  if (answers[j].containsKey('answerId')) {
                    answers[j]['answerId'] =
                        '${idPrefix}a${i + 1}_${DateTime.now().microsecondsSinceEpoch}';
                  }
                }
              }

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

  Future<String> _detectLanguage(String text) async {
    String language = 'English';

    try {
      final sample = text.length > 500 ? text.substring(0, 500) : text;

      final prompt = '''
Analyze the following text and determine what language it is written in.
Only respond with the language name (e.g., "English", "Hindi", "Spanish", etc.).

Text sample:
$sample
''';

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
    }

    return language;
  }

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

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final logPrefix = 'api_${timestamp}_req${requestId}_chunk${chunkIndex}';

    try {
      await _logToCloud('${logPrefix}_request.txt', prompt);

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

          await _logToCloud('${logPrefix}_response.txt', responseText);

          String jsonStr = responseText.trim();

          if (jsonStr.startsWith('```json')) {
            jsonStr = jsonStr.substring(7);
          } else if (jsonStr.startsWith('```')) {
            jsonStr = jsonStr.substring(3);
          }
          if (jsonStr.endsWith('```')) {
            jsonStr = jsonStr.substring(0, jsonStr.length - 3);
          }

          await _logToCloud('${logPrefix}_presanitized.json', jsonStr);

          jsonStr = TextFormatter.sanitizeJsonString(jsonStr);

          await _logToCloud('${logPrefix}_sanitized.json', jsonStr);

          try {
            final generatedQuestions =
                jsonDecode(jsonStr) as Map<String, dynamic>;

            if (!generatedQuestions.containsKey('questions') ||
                !generatedQuestions.containsKey('answers')) {
              throw Exception(
                'Invalid response format: missing questions or answers',
              );
            }

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

  Future<void> _logToCloud(String filename, String content) async {
    try {
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      final ref = _storage.ref().child('gemini_logs/$date/$filename');

      await ref.putString(content, format: PutStringFormat.raw);

      _logger.i('Logged to cloud storage: gemini_logs/$date/$filename');
    } catch (e) {
      _logger.e('Error logging to cloud storage: $e');
      _logger.i(
        'Content preview: ${content.substring(0, min(100, content.length))}...',
      );
    }
  }
}
