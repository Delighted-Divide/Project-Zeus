import 'question.dart';

/// Model representing an assessment with questions and answers
class Assessment {
  /// List of questions in the assessment
  final List<Question> questions;

  /// List of answers in the assessment
  final List<Answer> answers;

  /// List of tags associated with the assessment
  final List<Tag> tags;

  /// Difficulty level of the assessment
  final String difficulty;

  /// Total points in the assessment
  final int totalPoints;

  /// Source document URL
  final String? sourceDocumentUrl;

  /// Source document name
  final String? sourceDocumentName;

  /// Constructor
  Assessment({
    required this.questions,
    required this.answers,
    required this.tags,
    required this.difficulty,
    required this.totalPoints,
    this.sourceDocumentUrl,
    this.sourceDocumentName,
  });

  /// Create an assessment from a map
  factory Assessment.fromMap(Map<String, dynamic> map) {
    return Assessment(
      questions: List<Question>.from(
        (map['questions'] as List).map((q) => Question.fromMap(q)),
      ),
      answers: List<Answer>.from(
        (map['answers'] as List).map((a) => Answer.fromMap(a)),
      ),
      tags:
          map['tags'] != null
              ? List<Tag>.from((map['tags'] as List).map((t) => Tag.fromMap(t)))
              : [],
      difficulty: map['difficulty'] ?? 'medium',
      totalPoints: map['totalPoints'] ?? 0,
      sourceDocumentUrl: map['sourceDocumentUrl'],
      sourceDocumentName: map['sourceDocumentName'],
    );
  }

  /// Convert assessment to a map
  Map<String, dynamic> toMap() {
    return {
      'questions': questions.map((q) => q.toMap()).toList(),
      'answers': answers.map((a) => a.toMap()).toList(),
      'tags': tags.map((t) => t.toMap()).toList(),
      'difficulty': difficulty,
      'totalPoints': totalPoints,
      if (sourceDocumentUrl != null) 'sourceDocumentUrl': sourceDocumentUrl,
      if (sourceDocumentName != null) 'sourceDocumentName': sourceDocumentName,
    };
  }
}

/// Model representing a tag for categorizing assessments
class Tag {
  /// Unique identifier for the tag
  final String tagId;

  /// Name of the tag
  final String name;

  /// Description of the tag
  final String description;

  /// Category of the tag
  final String category;

  /// Constructor
  Tag({
    required this.tagId,
    required this.name,
    required this.description,
    required this.category,
  });

  /// Create a tag from a map
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      tagId: map['tagId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
    );
  }

  /// Convert tag to a map
  Map<String, dynamic> toMap() {
    return {
      'tagId': tagId,
      'name': name,
      'description': description,
      'category': category,
    };
  }
}
