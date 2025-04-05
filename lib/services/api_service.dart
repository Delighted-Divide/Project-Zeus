import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/text_formatter.dart';

/// Service for interacting with the Gemini AI API
class ApiService {
  final Logger _logger = Logger();
  final String _apiKey;

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

  /// Generate assessment questions from PDF text with retry mechanism
  // In api_service.dart - Add this chunking method

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

    // Calculate total questions
    int totalQuestionCount = 0;
    questionDistribution.forEach((_, count) => totalQuestionCount += count);

    // If total question count is large, use chunking approach
    if (totalQuestionCount > 10) {
      return _generateWithChunking(
        extractedText: extractedText,
        difficulty: difficulty,
        questionDistribution: questionDistribution,
        questionTypePoints: questionTypePoints,
        totalPoints: totalPoints,
        modelName: modelName,
        pageRange: pageRange,
      );
    } else {
      // Use standard approach for smaller question sets
      return _generateStandard(
        extractedText: extractedText,
        difficulty: difficulty,
        questionDistribution: questionDistribution,
        questionTypePoints: questionTypePoints,
        totalPoints: totalPoints,
        modelName: modelName,
        pageRange: pageRange,
      );
    }
  }

  /// Generate questions using chunking for large sets
  Future<Map<String, dynamic>> _generateWithChunking({
    required String extractedText,
    required String difficulty,
    required Map<String, int> questionDistribution,
    required Map<String, int> questionTypePoints,
    required int totalPoints,
    required String modelName,
    required RangeValues pageRange,
  }) async {
    _logger.i('Using chunked generation for large question set');

    // Split question distribution into chunks of 5 questions each
    List<Map<String, int>> chunks = [];
    Map<String, int> currentChunk = {};
    int currentTotal = 0;

    for (var entry in questionDistribution.entries) {
      String type = entry.key;
      int count = entry.value;
      int remaining = count;

      while (remaining > 0) {
        // How many can fit in current chunk (max 5 per chunk)
        int canAdd = min(remaining, 5 - currentTotal);

        if (canAdd > 0) {
          // Add to current chunk
          currentChunk[type] = (currentChunk[type] ?? 0) + canAdd;
          currentTotal += canAdd;
          remaining -= canAdd;
        }

        // If chunk is full or we can't add more, finalize it
        if (currentTotal >= 5 || canAdd == 0) {
          if (currentChunk.isNotEmpty) {
            chunks.add(Map<String, int>.from(currentChunk));
          }
          currentChunk = {};
          currentTotal = 0;

          // If we still have questions to add for this type, continue in next iteration
          if (remaining > 0) {
            continue;
          }
        }
      }
    }

    // Add final chunk if not empty
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    _logger.i('Split into ${chunks.length} chunks for processing');

    // Process each chunk
    List<Map<String, dynamic>> results = [];

    for (int i = 0; i < chunks.length; i++) {
      _logger.i('Processing chunk ${i + 1}/${chunks.length}');

      try {
        // Generate prompt for this chunk
        final chunkPrompt = '''
You are an expert education assessment creator. Create assessment questions based on the following text.

Text from PDF (pages ${pageRange.start.toInt()} to ${pageRange.end.toInt()}):
$extractedText

Create a set of assessment questions with these specifications:
- Difficulty level: $difficulty
- Question distribution: ${_formatDistribution(chunks[i], questionTypePoints)}

IMPORTANT: 
1. Each question MUST start with explanatory text that describes the problem clearly.
2. Always add descriptive text before any equations.
3. For math equations, use LaTeX notation with double-escaped backslashes, like: \$\\\\sqrt{x}\$ not \$\\sqrt{x}\$
4. Format your response as valid JSON with this structure:

{
  "questions": [
    {
      "questionId": "q${i + 1}_1",
      "questionType": "multiple-choice",
      "questionText": "What is the derivative of the function x²? \$\\\\frac{d}{dx}(x^2) = ?\$",
      "options": ["2x", "x²", "0", "1"],
      "points": 1
    }
  ],
  "answers": [
    {
      "answerId": "a${i + 1}_1",
      "questionId": "q${i + 1}_1",
      "answerType": "multiple-choice",
      "answerText": "2x",
      "reasoning": "The derivative of x² is 2x using the power rule."
    }
  ],
  "tags": []
}

Only respond with valid JSON. Do not include markdown code blocks or any other text.
''';

        // Make the API call for this chunk
        final response = await _callGeminiApi(chunkPrompt, modelName);
        results.add(response);

        // Add delay between chunks to avoid rate limiting
        if (i < chunks.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      } catch (e) {
        _logger.e('Error processing chunk ${i + 1}', error: e);
        // Continue with other chunks even if one fails
      }
    }

    // Combine all chunk results
    return _combineChunkResults(results);
  }

  /// Format distribution for prompt
  String _formatDistribution(
    Map<String, int> distribution,
    Map<String, int> pointsMap,
  ) {
    return distribution.entries
        .map(
          (e) =>
              "${e.key}: ${e.value} questions (${pointsMap[e.key] ?? 1} points each)",
        )
        .join(', ');
  }

  /// Combine results from multiple chunks
  /// Combine results from multiple chunks
  Map<String, dynamic> _combineChunkResults(
    List<Map<String, dynamic>> results,
  ) {
    List<dynamic> allQuestions = [];
    List<dynamic> allAnswers = [];
    List<dynamic> allTags = [];

    for (var result in results) {
      if (result.containsKey('questions') && result['questions'] is List) {
        allQuestions.addAll(result['questions'] as List);
      }

      if (result.containsKey('answers') && result['answers'] is List) {
        allAnswers.addAll(result['answers'] as List);
      }

      if (result.containsKey('tags') && result['tags'] is List) {
        // Add unique tags
        final existingTagNames =
            allTags
                .map(
                  (t) =>
                      t is Map && t.containsKey('name')
                          ? t['name'].toString().toLowerCase()
                          : '',
                )
                .toSet();

        for (var tag in result['tags'] as List) {
          if (tag is Map &&
              tag.containsKey('name') &&
              !existingTagNames.contains(
                tag['name'].toString().toLowerCase(),
              )) {
            allTags.add(tag);
            existingTagNames.add(tag['name'].toString().toLowerCase());
          }
        }
      }
    }

    return {'questions': allQuestions, 'answers': allAnswers, 'tags': allTags};
  }

  /// Standard generation approach for smaller question sets
  Future<Map<String, dynamic>> _generateStandard({
    required String extractedText,
    required String difficulty,
    required Map<String, int> questionDistribution,
    required Map<String, int> questionTypePoints,
    required int totalPoints,
    required String modelName,
    required RangeValues pageRange,
  }) async {
    // Create the distribution description
    final distributionInfo = questionDistribution.entries
        .map(
          (entry) =>
              "${entry.key}: ${entry.value} questions (${questionTypePoints[entry.key]} points each)",
        )
        .join(', ');

    // Create prompt with enhanced instructions
    final prompt = '''
You are an expert education assessment creator. Create assessment questions based on the following text.

Text from PDF (pages ${pageRange.start.toInt()} to ${pageRange.end.toInt()}):
$extractedText

Create a comprehensive assessment with the following specifications:
- Difficulty level: $difficulty
- Total points: $totalPoints
- Question distribution: $distributionInfo

IMPORTANT: 
1. Each question MUST start with explanatory text that describes the problem clearly.
2. Always add descriptive text before any equations.
3. For math equations, use LaTeX notation with double-escaped backslashes, like: \$\\\\sqrt{x}\$ not \$\\sqrt{x}\$
4. Format your response as valid JSON with this structure:

{
  "questions": [
    {
      "questionId": "q1",
      "questionType": "multiple-choice",
      "questionText": "What is the derivative of the function x²? \$\\\\frac{d}{dx}(x^2) = ?\$",
      "options": ["2x", "x²", "0", "1"],
      "points": 1
    }
  ],
  "answers": [
    {
      "answerId": "a1",
      "questionId": "q1",
      "answerType": "multiple-choice",
      "answerText": "2x",
      "reasoning": "The derivative of x² is 2x using the power rule."
    }
  ],
  "tags": []
}

Only respond with valid JSON. Do not include markdown code blocks or any other text.
''';

    // Call the API
    return await _callGeminiApi(prompt, modelName);
  }

  /// Call the Gemini API and process the response
  // services/api_service.dart - Updated _callGeminiApi method to include logging
  Future<Map<String, dynamic>> _callGeminiApi(
    String prompt,
    String modelName,
  ) async {
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

    _logger.i(
      'Sending request to Gemini API with prompt length: ${prompt.length}',
    );

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      _logger.i(
        'Received response from Gemini API (status: ${response.statusCode})',
      );

      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'] ?? '';

        // Log the first 500 characters of the response
        _logger.i(
          'Response preview: ${responseText.substring(0, responseText.length > 500 ? 500 : responseText.length)}...',
        );

        // Extract JSON from response
        String jsonStr = responseText.trim();

        // Remove code block markers if present
        if (jsonStr.startsWith('```json')) {
          jsonStr = jsonStr.substring(7);
        } else if (jsonStr.startsWith('```')) {
          jsonStr = jsonStr.substring(3);
        }
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }

        // Sanitize and parse JSON
        _logger.i('Sanitizing and parsing JSON response');
        jsonStr = TextFormatter.sanitizeJsonString(jsonStr);

        try {
          final generatedQuestions =
              jsonDecode(jsonStr) as Map<String, dynamic>;

          // Validate the structure of generated questions
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

          _logger.i(
            'Successfully parsed JSON with ${(generatedQuestions['questions'] as List).length} questions',
          );
          return generatedQuestions;
        } catch (jsonError) {
          _logger.e('JSON parsing error', error: jsonError);
          throw Exception('Failed to parse JSON response: $jsonError');
        }
      } else {
        _logger.e('No content found in API response');
        throw Exception('No response content found in API response');
      }
    } else {
      _logger.e('API request failed with status: ${response.statusCode}');
      // Log the error response
      _logger.e('Error response: ${response.body}');

      String errorMessage = 'API request failed: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData['error'] != null &&
            errorData['error']['message'] != null) {
          errorMessage = errorData['error']['message'];
        }
      } catch (e) {
        // If parsing fails, use the default error message
      }

      throw Exception(errorMessage);
    }
  }
}
