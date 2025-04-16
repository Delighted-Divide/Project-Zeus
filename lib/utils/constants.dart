import 'package:flutter/material.dart';

/// Constants used throughout the app
class AppConstants {
  // API constants
  static const String geminiApiBaseUrl =
      'https://generativelanguage.googleapis.com/v1/models/';

  // Theme colors
  static const Color primaryColor = Color(0xFF6A3DE8);
  static const Color secondaryColor = Color(0xFF5E35B1);
  static const Color backgroundColor = Colors.white;
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;

  // Question types and difficulties
  static const List<String> difficultyLevels = [
    'easy',
    'medium',
    'hard',
    'expert',
  ];
  static const List<String> questionTypes = [
    'multiple-choice',
    'multiple-answer',
    'true-false',
    'fill-in-the-blank',
    'short-answer',
  ];

  // Points for each question type
  static const Map<String, int> questionTypePoints = {
    'multiple-choice': 1,
    'multiple-answer': 2,
    'true-false': 1,
    'fill-in-the-blank': 2,
    'short-answer': 3,
  };

  // Default question counts
  static Map<String, String> defaultQuestionCounts = {
    'multiple-choice': '5',
    'multiple-answer': '3',
    'true-false': '4',
    'fill-in-the-blank': '3',
    'short-answer': '2',
  };

  // API model options
  static const List<Map<String, String>> availableModels = [
    {'value': 'gemini-2.5-pro-preview-03-25', 'label': 'Gemini 2.5 Pro'},
    {'value': 'gemini-2.0-flash', 'label': 'Gemini 2.0 Flash'},
    {'value': 'gemini-2.0-flash-lite', 'label': 'Gemini 2.0 Lite'},
  ];

  static const String defaultModel = 'gemini-2.0-flash';
  // Secure storage keys
  static const String apiKeyStorageKey = 'gemini_api_key';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String assessmentsCollection = 'assessments';
  static const String questionsCollection = 'questions';
  static const String answersCollection = 'answers';
  static const String tagsCollection = 'tags';
}
