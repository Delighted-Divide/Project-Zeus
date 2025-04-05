/// Model representing a question in an assessment
class Question {
  /// Unique identifier for the question
  final String questionId;

  /// Type of question (multiple-choice, short-answer, etc.)
  final String questionType;

  /// The question text
  final String questionText;

  /// List of answer options (for multiple-choice/answer questions)
  final List<String>? options;

  /// Points assigned to this question
  final int points;

  /// Constructor
  Question({
    required this.questionId,
    required this.questionType,
    required this.questionText,
    this.options,
    required this.points,
  });

  /// Create a question from a map
  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      questionId: map['questionId'] ?? '',
      questionType: map['questionType'] ?? '',
      questionText: map['questionText'] ?? '',
      options:
          map['options'] != null ? List<String>.from(map['options']) : null,
      points: map['points'] ?? 1,
    );
  }

  /// Convert question to a map
  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'questionType': questionType,
      'questionText': questionText,
      if (options != null) 'options': options,
      'points': points,
    };
  }
}

/// Model representing an answer to a question
class Answer {
  /// Unique identifier for the answer
  final String answerId;

  /// ID of the associated question
  final String questionId;

  /// Type of answer (matching the question type)
  final String answerType;

  /// The correct answer text or list of correct answers
  final dynamic answerText;

  /// Explanation of why this is the correct answer
  final String reasoning;

  /// Constructor
  Answer({
    required this.answerId,
    required this.questionId,
    required this.answerType,
    required this.answerText,
    required this.reasoning,
  });

  /// Create an answer from a map
  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      answerId: map['answerId'] ?? '',
      questionId: map['questionId'] ?? '',
      answerType: map['answerType'] ?? '',
      answerText: map['answerText'],
      reasoning: map['reasoning'] ?? '',
    );
  }

  /// Convert answer to a map
  Map<String, dynamic> toMap() {
    return {
      'answerId': answerId,
      'questionId': questionId,
      'answerType': answerType,
      'answerText': answerText,
      'reasoning': reasoning,
    };
  }
}
