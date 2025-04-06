import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/text_formatter.dart';

/// Widget to display generated assessment questions
class AssessmentView extends StatelessWidget {
  /// Generated questions data
  final Map<String, dynamic> generatedQuestions;

  /// Function to handle save action
  final VoidCallback onSave;

  /// Loading state
  final bool isLoading;

  /// Source document name
  final String documentName;

  /// Page range of the document
  final RangeValues pageRange;

  /// Total points of the assessment
  final int totalPoints;

  /// Difficulty level
  final String difficulty;

  /// Constructor
  const AssessmentView({
    Key? key,
    required this.generatedQuestions,
    required this.onSave,
    required this.isLoading,
    required this.documentName,
    required this.pageRange,
    required this.totalPoints,
    required this.difficulty,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final questions = generatedQuestions['questions'] as List<dynamic>;
    final answers = generatedQuestions['answers'] as List<dynamic>;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: AppConstants.primaryColor),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Generated Assessment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I\'ve generated a set of assessment questions based on the content. There are ${questions.length} questions with a total of $totalPoints points. You can review all questions and answers below.',
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Statistics
                _buildAssessmentStatistics(questions),
                const SizedBox(height: 24),

                // All questions and answers
                const Text(
                  'All Questions & Answers:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // All questions
                ..._buildAllQuestions(questions, answers),
                const SizedBox(height: 16),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSave,
                    icon:
                        isLoading
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
                      isLoading ? 'Saving...' : 'Save Assessment',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
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

  /// Build the assessment statistics
  Widget _buildAssessmentStatistics(List<dynamic> questions) {
    final questionTypes = <String, int>{};
    int totalPoints = 0;

    // Calculate statistics
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
          // Summary statistics
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
                difficulty.substring(0, 1).toUpperCase() +
                    difficulty.substring(1),
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Question types breakdown
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
                              color: AppConstants.primaryColor,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            TextFormatter.formatQuestionType(entry.key),
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

  /// Build a stat item
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 20),
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

  /// Build all questions and answers for display
  List<Widget> _buildAllQuestions(
    List<dynamic> questions,
    List<dynamic> answers,
  ) {
    final allQuestions = <Widget>[];

    // Iterate through all questions
    for (int i = 0; i < questions.length; i++) {
      final question = questions[i];
      final questionId = question['questionId'];

      // Find matching answer
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
              // Question number and type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${i + 1}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      TextFormatter.formatQuestionType(
                        question['questionType'],
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppConstants.primaryColor,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Points
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

              // Question text (with LaTeX support)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextFormatter.renderTextWithEquations(
                  question['questionText']?.toString() ??
                      'No question text available',
                ),
              ),
              const SizedBox(height: 16),

              // Options if applicable
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
                                                  ? AppConstants.primaryColor
                                                  : Colors.grey[400]!,
                                          width: 1.5,
                                        ),
                                        color:
                                            isAnswer
                                                ? AppConstants.primaryColor
                                                    .withOpacity(0.1)
                                                : Colors.transparent,
                                      ),
                                      child:
                                          isAnswer
                                              ? const Center(
                                                child: Icon(
                                                  Icons.check,
                                                  size: 12,
                                                  color:
                                                      AppConstants.primaryColor,
                                                ),
                                              )
                                              : null,
                                    ),
                                    Expanded(
                                      child: TextFormatter.buildFormattedText(
                                        option.toString(),
                                        textStyle: TextStyle(
                                          fontSize: 14,
                                          color:
                                              isAnswer
                                                  ? AppConstants.primaryColor
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

              // Answer
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
                                        child: TextFormatter.buildFormattedText(
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
                          TextFormatter.buildFormattedText(
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
                          TextFormatter.buildFormattedText(
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
}
