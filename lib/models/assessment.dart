import 'question.dart';

class Assessment {
  final List<Question> questions;
  final List<Answer> answers;
  final List<Tag> tags;
  final String difficulty;
  final int totalPoints;
  final String? sourceDocumentUrl;
  final String? sourceDocumentName;

  Assessment({
    required this.questions,
    required this.answers,
    required this.tags,
    required this.difficulty,
    required this.totalPoints,
    this.sourceDocumentUrl,
    this.sourceDocumentName,
  });

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

class Tag {
  final String tagId;
  final String name;
  final String description;
  final String category;

  Tag({
    required this.tagId,
    required this.name,
    required this.description,
    required this.category,
  });

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      tagId: map['tagId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tagId': tagId,
      'name': name,
      'description': description,
      'category': category,
    };
  }
}
