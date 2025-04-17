import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'assessment_conditions_page.dart';

class QuizPage extends StatefulWidget {
  final String assessmentId;
  final String? groupName;
  final int? timerDuration;

  const QuizPage({
    Key? key,
    required this.assessmentId,
    this.groupName,
    this.timerDuration,
  }) : super(key: key);

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  String assessmentTitle = '';
  String assessmentDescription = '';
  int totalPoints = 0;
  List<Map<String, dynamic>> questions = [];
  Map<String, dynamic> userAnswers = {};

  String submissionId = '';
  bool isLoading = true;
  bool isSubmitting = false;
  int currentQuestionIndex = 0;
  String assessmentStatus = 'in-progress';
  bool showQuestionListDrawer = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  Timer? _timer;
  int _remainingSeconds = 0;
  DateTime? startTime;

  final Color _primaryColor = const Color(0xFF6C63FF);
  final Color _secondaryColor = const Color(0xFFFF5A8E);
  final Color _backgroundColor = const Color(0xFFF8F9FE);
  final Color _cardColor = Colors.white;
  final Color _accentGreen = const Color(0xFF4CAF50);
  final Color _accentYellow = const Color(0xFFFFC107);
  final Color _textPrimary = const Color(0xFF2D3142);
  final Color _textSecondary = const Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    _initializeAssessment();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();

    if (assessmentStatus == 'in-progress' && _remainingSeconds > 0) {
      _saveRemainingTime();
    }
    super.dispose();
  }

  Future<void> _initializeAssessment() async {
    try {
      final assessmentDoc =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (!assessmentDoc.exists) {
        _showError('Assessment not found');
        return;
      }

      final assessmentData = assessmentDoc.data()!;
      assessmentTitle = assessmentData['title'] ?? 'Quiz';
      assessmentDescription = assessmentData['description'] ?? '';
      totalPoints = assessmentData['totalPoints'] ?? 0;

      final questionsSnapshot =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .collection('questions')
              .get();

      questions =
          questionsSnapshot.docs
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList();

      await _createOrLoadSubmission();

      if (widget.timerDuration != null) {
        _initializeTimer();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      _showError('Error loading quiz: ${e.toString()}');
    }
  }

  Future<void> _createOrLoadSubmission() async {
    if (currentUser == null) {
      _showError('User not authenticated');
      return;
    }

    final existingSubmissions =
        await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('assessments')
            .doc(widget.assessmentId)
            .collection('submissions')
            .where('status', isEqualTo: 'in-progress')
            .limit(1)
            .get();

    if (existingSubmissions.docs.isNotEmpty) {
      final existingSubmission = existingSubmissions.docs.first;
      submissionId = existingSubmission.id;

      final answersSnapshot =
          await existingSubmission.reference.collection('answers').get();

      for (var answerDoc in answersSnapshot.docs) {
        final answerData = answerDoc.data();
        userAnswers[answerData['questionId']] = answerData['userAnswer'];
      }

      if (widget.timerDuration != null) {
        final submissionData = existingSubmission.data();
        startTime = (submissionData['startedAt'] as Timestamp).toDate();

        final elapsed = DateTime.now().difference(startTime!).inSeconds;
        final totalSeconds = widget.timerDuration! * 60;
        _remainingSeconds = totalSeconds - elapsed;

        if (_remainingSeconds <= 0) {
          _submitAssessment(isTimerExpired: true);
        }
      }
    } else {
      await _createNewSubmission();
    }
  }

  Future<void> _createNewSubmission() async {
    startTime = DateTime.now();

    final userSubmissionRef = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('assessments')
        .doc(widget.assessmentId)
        .collection('submissions')
        .add({
          'userId': currentUser!.uid,
          'userName': currentUser!.displayName ?? 'Anonymous',
          'startedAt': Timestamp.fromDate(startTime!),
          'status': 'in-progress',
          'totalScore': 0,
        });

    submissionId = userSubmissionRef.id;

    if (widget.groupName != null) {
      final groupSnapshot =
          await _firestore
              .collection('groups')
              .where('name', isEqualTo: widget.groupName)
              .limit(1)
              .get();

      if (groupSnapshot.docs.isNotEmpty) {
        final groupId = groupSnapshot.docs.first.id;

        final sharedWithGroupDoc =
            await _firestore
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('sharedWithGroups')
                .doc(groupId)
                .get();

        if (sharedWithGroupDoc.exists) {
          await _firestore
              .collection('groups')
              .doc(groupId)
              .collection('assessments')
              .doc(widget.assessmentId)
              .collection('submissions')
              .doc(submissionId)
              .set({
                'userId': currentUser!.uid,
                'userName': currentUser!.displayName ?? 'Anonymous',
                'startedAt': Timestamp.fromDate(startTime!),
                'status': 'in-progress',
                'totalScore': 0,
              });
        }
      }
    }

    if (widget.timerDuration != null) {
      _remainingSeconds = widget.timerDuration! * 60;
    }
  }

  Future<void> _restartQuiz() async {
    final shouldRestart =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Restart Quiz?'),
                content: const Text(
                  'All your current answers will be deleted. Are you sure you want to restart?',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Restart'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!shouldRestart) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (context) => AssessmentConditionsPage(
              assessmentId: widget.assessmentId,
              groupName: widget.groupName,
            ),
      ),
    );
  }

  void _initializeTimer() {
    if (startTime != null) {
      final totalSeconds = widget.timerDuration! * 60;
      final elapsed = DateTime.now().difference(startTime!).inSeconds;
      _remainingSeconds = totalSeconds - elapsed;

      if (_remainingSeconds <= 0) {
        _submitAssessment(isTimerExpired: true);
        return;
      }
    } else {
      _remainingSeconds = widget.timerDuration! * 60;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer!.cancel();
          _submitAssessment(isTimerExpired: true);
        }
      });
    });
  }

  Future<void> _saveRemainingTime() async {
    if (submissionId.isEmpty) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('assessments')
          .doc(widget.assessmentId)
          .collection('submissions')
          .doc(submissionId)
          .update({
            'remainingTimeInSeconds': _remainingSeconds,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });

      if (widget.groupName != null) {
        final groupSnapshot =
            await _firestore
                .collection('groups')
                .where('name', isEqualTo: widget.groupName)
                .limit(1)
                .get();

        if (groupSnapshot.docs.isNotEmpty) {
          final groupId = groupSnapshot.docs.first.id;

          final sharedWithGroupDoc =
              await _firestore
                  .collection('assessments')
                  .doc(widget.assessmentId)
                  .collection('sharedWithGroups')
                  .doc(groupId)
                  .get();

          if (sharedWithGroupDoc.exists) {
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('submissions')
                .doc(submissionId)
                .update({
                  'remainingTimeInSeconds': _remainingSeconds,
                  'lastUpdatedAt': FieldValue.serverTimestamp(),
                });
          }
        }
      }
    } catch (e) {
      print('Error saving remaining time: ${e.toString()}');
    }
  }

  Future<void> _updateAnswer(String questionId, dynamic answer) async {
    if (submissionId.isEmpty || assessmentStatus != 'in-progress') return;

    setState(() {
      userAnswers[questionId] = answer;
    });

    try {
      final answersRef = _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('assessments')
          .doc(widget.assessmentId)
          .collection('submissions')
          .doc(submissionId)
          .collection('answers');

      final existingAnswers =
          await answersRef
              .where('questionId', isEqualTo: questionId)
              .limit(1)
              .get();

      if (existingAnswers.docs.isNotEmpty) {
        await answersRef.doc(existingAnswers.docs.first.id).update({
          'userAnswer': answer,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await answersRef.add({
          'questionId': questionId,
          'userAnswer': answer,
          'createdAt': FieldValue.serverTimestamp(),
          'score': 0,
          'feedback': '',
        });
      }

      if (widget.groupName != null) {
        final groupSnapshot =
            await _firestore
                .collection('groups')
                .where('name', isEqualTo: widget.groupName)
                .limit(1)
                .get();

        if (groupSnapshot.docs.isNotEmpty) {
          final groupId = groupSnapshot.docs.first.id;

          final sharedWithGroupDoc =
              await _firestore
                  .collection('assessments')
                  .doc(widget.assessmentId)
                  .collection('sharedWithGroups')
                  .doc(groupId)
                  .get();

          if (sharedWithGroupDoc.exists) {
            final groupAnswersRef = _firestore
                .collection('groups')
                .doc(groupId)
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('submissions')
                .doc(submissionId)
                .collection('answers');

            final existingGroupAnswers =
                await groupAnswersRef
                    .where('questionId', isEqualTo: questionId)
                    .limit(1)
                    .get();

            if (existingGroupAnswers.docs.isNotEmpty) {
              await groupAnswersRef
                  .doc(existingGroupAnswers.docs.first.id)
                  .update({
                    'userAnswer': answer,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
            } else {
              await groupAnswersRef.add({
                'questionId': questionId,
                'userAnswer': answer,
                'createdAt': FieldValue.serverTimestamp(),
                'score': 0,
                'feedback': '',
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error updating answer: ${e.toString()}');
    }
  }

  Future<void> _submitAssessment({bool isTimerExpired = false}) async {
    if (submissionId.isEmpty) return;

    setState(() {
      isSubmitting = true;
      assessmentStatus = 'submitted';
    });

    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('assessments')
          .doc(widget.assessmentId)
          .collection('submissions')
          .doc(submissionId)
          .update({
            'status': 'submitted',
            'submittedAt': FieldValue.serverTimestamp(),
          });

      if (widget.groupName != null) {
        final groupSnapshot =
            await _firestore
                .collection('groups')
                .where('name', isEqualTo: widget.groupName)
                .limit(1)
                .get();

        if (groupSnapshot.docs.isNotEmpty) {
          final groupId = groupSnapshot.docs.first.id;

          final sharedWithGroupDoc =
              await _firestore
                  .collection('assessments')
                  .doc(widget.assessmentId)
                  .collection('sharedWithGroups')
                  .doc(groupId)
                  .get();

          if (sharedWithGroupDoc.exists) {
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('submissions')
                .doc(submissionId)
                .update({
                  'status': 'submitted',
                  'submittedAt': FieldValue.serverTimestamp(),
                });
          }
        }
      }

      if (mounted) {
        if (isTimerExpired) {
          _showTimerExpiredDialog();
        } else {
          _showCompletionDialog();
        }
      }
    } catch (e) {
      _showError('Error submitting quiz: ${e.toString()}');
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  void _navigateToQuestion(int index) {
    if (index >= 0 && index < questions.length) {
      _animationController.reverse().then((_) {
        setState(() {
          currentQuestionIndex = index;
          showQuestionListDrawer = false;
        });
        _animationController.forward();
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showTimerExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.timer_off, color: Colors.red),
                SizedBox(width: 8),
                Text('Time Expired'),
              ],
            ),
            content: const Text(
              'Your time has run out. Your quiz has been submitted automatically.',
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 2,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showCompletionDialog() {
    final percentComplete =
        questions.isEmpty ? 0 : userAnswers.length / questions.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: _accentGreen),
                SizedBox(width: 8),
                Text('Quiz Submitted'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your quiz has been submitted successfully.'),
                const SizedBox(height: 20),
                CircularPercentIndicator(
                  radius: 60.0,
                  lineWidth: 10.0,
                  percent: percentComplete.toDouble(),
                  center: Text(
                    '${(percentComplete * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0,
                    ),
                  ),
                  progressColor: _accentGreen,
                  backgroundColor: Colors.grey.shade200,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
                const SizedBox(height: 20),
                Text(
                  'You answered ${userAnswers.length} out of ${questions.length} questions',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 2,
                ),
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final questionId = question['id'];
    final questionType = question['questionType'];
    final questionText = question['questionText'];
    final points = question['points'] ?? 1;
    final isAnswered = userAnswers.containsKey(questionId);

    return FadeTransition(
      opacity: _animation,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _getQuestionTypeIcon(questionType),
                      const SizedBox(width: 8),
                      Text(
                        _formatQuestionType(questionType),
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 14, color: _secondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${points} pts',
                          style: TextStyle(
                            color: _secondaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuestionContent(questionType, questionId, question),
                ],
              ),
            ),
            if (isAnswered)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _accentGreen.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: _accentGreen, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Answer saved',
                      style: TextStyle(
                        color: _accentGreen,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
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

  Widget _getQuestionTypeIcon(String questionType) {
    IconData iconData;

    switch (questionType) {
      case 'multiple-choice':
        iconData = Icons.radio_button_checked;
        break;
      case 'fill-in-the-blank':
        iconData = Icons.short_text;
        break;
      case 'true-false':
        iconData = Icons.rule;
        break;
      case 'multiple-answer':
        iconData = Icons.check_box;
        break;
      case 'short-answer':
        iconData = Icons.text_fields;
        break;
      default:
        iconData = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 16, color: _primaryColor),
    );
  }

  String _formatQuestionType(String type) {
    switch (type) {
      case 'multiple-choice':
        return 'Multiple Choice';
      case 'fill-in-the-blank':
        return 'Fill in the Blank';
      case 'true-false':
        return 'True/False';
      case 'multiple-answer':
        return 'Multiple Answer';
      case 'short-answer':
        return 'Short Answer';
      default:
        return type;
    }
  }

  Widget _buildQuestionContent(
    String questionType,
    String questionId,
    Map<String, dynamic> question,
  ) {
    switch (questionType) {
      case 'multiple-choice':
        return _buildMultipleChoiceQuestion(questionId, question['options']);
      case 'fill-in-the-blank':
        return _buildFillInTheBlankQuestion(questionId);
      case 'true-false':
        return _buildTrueFalseQuestion(questionId);
      case 'multiple-answer':
        return _buildMultipleAnswerQuestion(questionId, question['options']);
      case 'short-answer':
        return _buildShortAnswerQuestion(questionId);
      default:
        return Text('Unsupported question type: $questionType');
    }
  }

  Widget _buildMultipleChoiceQuestion(
    String questionId,
    List<dynamic> options,
  ) {
    final selectedOption = userAnswers[questionId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          options.map((option) {
            final isSelected = selectedOption == option;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _updateAnswer(questionId, option);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? _primaryColor.withOpacity(0.1)
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? _primaryColor : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? _primaryColor : Colors.white,
                          border: Border.all(
                            color:
                                isSelected ? _primaryColor : Colors.grey[400]!,
                            width: 1.5,
                          ),
                        ),
                        child:
                            isSelected
                                ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                            color: isSelected ? _primaryColor : _textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildFillInTheBlankQuestion(String questionId) {
    final answer = userAnswers[questionId] ?? '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Enter your answer',
          hintStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
        style: TextStyle(fontSize: 15, color: _textPrimary),
        onChanged: (value) {
          _updateAnswer(questionId, value);
        },
        controller: TextEditingController(text: answer),
      ),
    );
  }

  Widget _buildTrueFalseQuestion(String questionId) {
    final selectedOption = userAnswers[questionId];

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              _updateAnswer(questionId, 'true');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color:
                    selectedOption == 'true'
                        ? _accentGreen.withOpacity(0.1)
                        : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      selectedOption == 'true'
                          ? _accentGreen
                          : Colors.grey[300]!,
                  width: 1.5,
                ),
                boxShadow:
                    selectedOption == 'true'
                        ? [
                          BoxShadow(
                            color: _accentGreen.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color:
                        selectedOption == 'true'
                            ? _accentGreen
                            : Colors.grey[500],
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'True',
                    style: TextStyle(
                      color:
                          selectedOption == 'true'
                              ? _accentGreen
                              : _textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () {
              _updateAnswer(questionId, 'false');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color:
                    selectedOption == 'false'
                        ? Colors.red.withOpacity(0.1)
                        : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      selectedOption == 'false'
                          ? Colors.red
                          : Colors.grey[300]!,
                  width: 1.5,
                ),
                boxShadow:
                    selectedOption == 'false'
                        ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color:
                        selectedOption == 'false'
                            ? Colors.red
                            : Colors.grey[500],
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'False',
                    style: TextStyle(
                      color:
                          selectedOption == 'false' ? Colors.red : _textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleAnswerQuestion(
    String questionId,
    List<dynamic> options,
  ) {
    final selectedOptions = (userAnswers[questionId] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          options.map((option) {
            final isSelected = selectedOptions.contains(option);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  List<dynamic> updatedSelection = List.from(selectedOptions);
                  if (isSelected) {
                    updatedSelection.remove(option);
                  } else {
                    updatedSelection.add(option);
                  }
                  _updateAnswer(questionId, updatedSelection);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? _primaryColor.withOpacity(0.1)
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? _primaryColor : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isSelected ? _primaryColor : Colors.white,
                          border: Border.all(
                            color:
                                isSelected ? _primaryColor : Colors.grey[400]!,
                            width: 1.5,
                          ),
                        ),
                        child:
                            isSelected
                                ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                                : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                            color: isSelected ? _primaryColor : _textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildShortAnswerQuestion(String questionId) {
    final answer = userAnswers[questionId] ?? '';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Write your answer here...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
        style: TextStyle(fontSize: 15, color: _textPrimary),
        maxLines: 4,
        onChanged: (value) {
          _updateAnswer(questionId, value);
        },
        controller: TextEditingController(text: answer),
      ),
    );
  }

  Widget _buildQuestionListItem(int index, Map<String, dynamic> question) {
    final isAnswered = userAnswers.containsKey(question['id']);
    final isCurrent = index == currentQuestionIndex;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          _navigateToQuestion(index);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isCurrent ? _primaryColor.withOpacity(0.1) : Colors.white,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isAnswered
                    ? _accentGreen
                    : (isCurrent ? _primaryColor : Colors.grey[300]),
            boxShadow: [
              BoxShadow(
                color: (isAnswered
                        ? _accentGreen
                        : (isCurrent ? _primaryColor : Colors.grey[300])!)
                    .withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child:
                isAnswered
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : _textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ),
        title: Text(
          question['questionText'],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: _textPrimary,
          ),
        ),
        subtitle: Text(
          _formatQuestionType(question['questionType']),
          style: TextStyle(fontSize: 12, color: _textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${question['points'] ?? 1} pts',
            style: TextStyle(
              color: _secondaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answeredCount = userAnswers.length;
    final totalQuestions = questions.length;
    final progressPercent =
        totalQuestions > 0 ? answeredCount / totalQuestions : 0.0;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        title: Text(
          assessmentTitle,
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: _textPrimary),
        actions: [
          if (widget.timerDuration != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:
                    _remainingSeconds < 60
                        ? Colors.red.withOpacity(0.1)
                        : (_remainingSeconds < 300
                            ? _accentYellow.withOpacity(0.1)
                            : _primaryColor.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (_remainingSeconds < 60
                            ? Colors.red
                            : (_remainingSeconds < 300
                                ? _accentYellow
                                : _primaryColor))
                        .withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color:
                        _remainingSeconds < 60
                            ? Colors.red
                            : (_remainingSeconds < 300
                                ? _accentYellow
                                : _primaryColor),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          _remainingSeconds < 60
                              ? Colors.red
                              : (_remainingSeconds < 300
                                  ? _accentYellow
                                  : _primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    showQuestionListDrawer
                        ? _primaryColor.withOpacity(0.1)
                        : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                showQuestionListDrawer ? Icons.close : Icons.menu,
                color: _primaryColor,
              ),
            ),
            onPressed: () {
              setState(() {
                showQuestionListDrawer = !showQuestionListDrawer;
              });
            },
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: _primaryColor,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading quiz...',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    color: _cardColor,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${currentQuestionIndex + 1}',
                                      style: TextStyle(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Question ',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '${currentQuestionIndex + 1}',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' of $totalQuestions',
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _accentGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: _accentGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$answeredCount answered',
                                    style: TextStyle(
                                      color: _accentGreen,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: LinearPercentIndicator(
                            padding: EdgeInsets.zero,
                            lineHeight: 8.0,
                            percent: progressPercent,
                            backgroundColor: Colors.grey[200],
                            progressColor: _accentGreen,
                            barRadius: const Radius.circular(4),
                            animation: true,
                            animationDuration: 300,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child:
                              !showQuestionListDrawer
                                  ? questions.isEmpty
                                      ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Icon(
                                                Icons.help_outline,
                                                size: 60,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Text(
                                              'No questions available',
                                              style: TextStyle(
                                                color: _textSecondary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      : SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: _buildQuestionCard(
                                          questions[currentQuestionIndex],
                                        ),
                                      )
                                  : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: questions.length,
                                    itemBuilder: (context, index) {
                                      return _buildQuestionListItem(
                                        index,
                                        questions[index],
                                      );
                                    },
                                  ),
                        ),
                        if (!showQuestionListDrawer &&
                            !isLoading &&
                            questions.isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 24,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap:
                                              isSubmitting
                                                  ? null
                                                  : () => _submitAssessment(),
                                          splashColor: _accentGreen.withOpacity(
                                            0.1,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            width: double.infinity,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: _accentGreen,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  isSubmitting
                                                      ? 'Submitting...'
                                                      : 'Submit Quiz',
                                                  style: TextStyle(
                                                    color: _accentGreen,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (currentQuestionIndex > 0)
                                        _buildNavButton(
                                          Icons.arrow_back_ios_new,
                                          'Previous',
                                          () => _navigateToQuestion(
                                            currentQuestionIndex - 1,
                                          ),
                                          isLeft: true,
                                        ),
                                      if (currentQuestionIndex > 0 &&
                                          currentQuestionIndex <
                                              questions.length - 1)
                                        const SizedBox(width: 16),
                                      if (currentQuestionIndex <
                                          questions.length - 1)
                                        _buildNavButton(
                                          Icons.arrow_forward_ios,
                                          'Next',
                                          () => _navigateToQuestion(
                                            currentQuestionIndex + 1,
                                          ),
                                          isLeft: false,
                                        ),
                                    ],
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
      floatingActionButton:
          isLoading || showQuestionListDrawer
              ? null
              : FloatingActionButton(
                onPressed: _restartQuiz,
                backgroundColor: _secondaryColor,
                elevation: 4,
                child: const Icon(Icons.refresh),
              ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNavButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    required bool isLeft,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                if (isLeft) Icon(icon, color: Colors.white, size: 16),
                if (isLeft) const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isLeft) const SizedBox(width: 8),
                if (!isLeft) Icon(icon, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
