class Question {
  final String questionId;
  final String questionType;
  final String questionText;
  final List<String>? options;
  final int points;

  Question({
    required this.questionId,
    required this.questionType,
    required this.questionText,
    this.options,
    required this.points,
  });

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

class Answer {
  final String answerId;
  final String questionId;
  final String answerType;
  final dynamic answerText;
  final String reasoning;

  Answer({
    required this.answerId,
    required this.questionId,
    required this.answerType,
    required this.answerText,
    required this.reasoning,
  });

  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      answerId: map['answerId'] ?? '',
      questionId: map['questionId'] ?? '',
      answerType: map['answerType'] ?? '',
      answerText: map['answerText'],
      reasoning: map['reasoning'] ?? '',
    );
  }

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
