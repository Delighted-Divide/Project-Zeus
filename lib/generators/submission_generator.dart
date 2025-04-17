import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/log_level.dart';
import '../models/static_data.dart';
import '../services/batch_manager.dart';
import '../utils/logging_utils.dart';

class SubmissionGenerator {
  final FirebaseFirestore _firestore;
  final LoggingUtils _logger = LoggingUtils();
  final Random _random = Random();

  SubmissionGenerator(this._firestore);

  Future<void> generateSubmissions(
    List<String> userIds,
    List<String> groupIds,
    List<String> assessmentIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log(
      "Starting submission generation with FIXED mirroring",
      level: LogLevel.INFO,
    );
    int submissionsCreated = 0;
    int answersCreated = 0;
    int groupSubmissionsMirrored = 0;
    int mirroringErrors = 0;

    final Map<String, Map<String, String>> groupChannelsCache = {};

    for (String groupId in groupIds) {
      try {
        final channelsSnapshot =
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('channels')
                .where('type', isEqualTo: 'assessment')
                .get();

        if (channelsSnapshot.docs.isNotEmpty) {
          if (!groupChannelsCache.containsKey(groupId)) {
            groupChannelsCache[groupId] = {};
          }

          for (final channelDoc in channelsSnapshot.docs) {
            groupChannelsCache[groupId]![channelDoc.id] = 'assessment';
          }

          _logger.log(
            "Cached ${channelsSnapshot.docs.length} assessment channels for group $groupId",
            level: LogLevel.DEBUG,
          );
        }
      } catch (e) {
        _logger.log(
          "ERROR caching channels for group $groupId: $e",
          level: LogLevel.ERROR,
        );
      }
    }

    _logger.log(
      "Prefetched assessment channels for ${groupChannelsCache.length} groups",
      level: LogLevel.INFO,
    );

    for (String userId in userIds) {
      _logger.log(
        "Processing submissions for user $userId",
        level: LogLevel.DEBUG,
      );

      final userAssessmentsSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('assessments')
              .get();

      if (userAssessmentsSnapshot.docs.isEmpty) {
        _logger.log(
          "No assessments found for user $userId, skipping",
          level: LogLevel.DEBUG,
        );
        continue;
      }

      for (final assessmentDoc in userAssessmentsSnapshot.docs) {
        final String assessmentId = assessmentDoc.id;
        final bool wasSharedInGroup =
            assessmentDoc.data()['wasSharedInGroup'] ?? false;
        final bool wasSharedWithUser =
            assessmentDoc.data()['wasSharedWithUser'] ?? false;

        if (!wasSharedWithUser && !wasSharedInGroup) {
          _logger.log(
            "Assessment $assessmentId was not shared (no flags set), skipping submission",
            level: LogLevel.DEBUG,
          );
          continue;
        }

        _logger.log(
          "Processing assessment $assessmentId for user $userId (wasSharedWithUser=$wasSharedWithUser, wasSharedInGroup=$wasSharedInGroup)",
          level: LogLevel.DEBUG,
        );

        final assessmentRef = _firestore
            .collection('assessments')
            .doc(assessmentId);
        final questionsSnapshot =
            await assessmentRef.collection('questions').get();

        if (questionsSnapshot.docs.isEmpty) {
          _logger.log(
            "No questions found for assessment $assessmentId, skipping",
            level: LogLevel.WARNING,
          );
          continue;
        }

        final List<Map<String, dynamic>> questions = _extractQuestionData(
          questionsSnapshot,
        );

        _logger.log(
          "Found ${questions.length} questions for assessment $assessmentId",
          level: LogLevel.DEBUG,
        );

        final int numberOfSubmissions = _random.nextInt(3) + 1;
        _logger.log(
          "Creating $numberOfSubmissions submissions for user $userId on assessment $assessmentId",
          level: LogLevel.DEBUG,
        );

        for (int i = 0; i < numberOfSubmissions; i++) {
          final String submissionId =
              'submission_${userId}_${assessmentId}_${i}_${_random.nextInt(10000)}';

          final submissionResult = await _createSubmission(
            userId,
            assessmentId,
            submissionId,
            questions,
            userData,
            batchManager,
          );

          submissionsCreated++;
          answersCreated += submissionResult['answers'] as int;

          if (wasSharedInGroup) {
            final mirrorResult = await _mirrorSubmissionToGroups(
              assessmentId,
              assessmentRef,
              userId,
              creatorId: submissionResult['creatorId'],
              submissionId: submissionId,
              submissionData: submissionResult['data'],
              answersData: submissionResult['answersData'],
              groupChannelsCache: groupChannelsCache,
              userData: userData,
              batchManager: batchManager,
            );

            if (mirrorResult > 0) {
              groupSubmissionsMirrored++;
              _logger.log(
                "Successfully mirrored submission to $mirrorResult groups",
                level: LogLevel.DEBUG,
              );
            } else {
              _logger.log(
                "WARNING: Failed to mirror submission to any groups despite wasSharedInGroup=true",
                level: LogLevel.WARNING,
              );
              mirroringErrors++;
            }
          }
        }
      }

      if (batchManager.operationCount > 200) {
        _logger.log(
          "Committing batch during submission generation to avoid size limits",
          level: LogLevel.INFO,
        );
        await batchManager.commitBatch();
      }
    }

    if (mirroringErrors > 0) {
      _logger.log(
        "Encountered $mirroringErrors errors during submission mirroring",
        level: LogLevel.ERROR,
      );
    }

    _logger.log(
      "Completed submission generation: created $submissionsCreated submissions with $answersCreated answers",
      level: LogLevel.INFO,
    );
    _logger.log(
      "Successfully mirrored $groupSubmissionsMirrored submissions to group channels",
      level: LogLevel.INFO,
    );
  }

  List<Map<String, dynamic>> _extractQuestionData(
    QuerySnapshot questionsSnapshot,
  ) {
    final List<Map<String, dynamic>> questions = [];

    for (final questionDoc in questionsSnapshot.docs) {
      final Map<String, dynamic> data =
          questionDoc.data() as Map<String, dynamic>;
      questions.add({
        'id': questionDoc.id,
        'type': data['questionType'] ?? 'short-answer',
        'points': data['points'] ?? 5,
        'options': data['options'],
      });
    }

    return questions;
  }

  Future<Map<String, dynamic>> _createSubmission(
    String userId,
    String assessmentId,
    String submissionId,
    List<Map<String, dynamic>> questions,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    final userAssessmentRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('assessments')
        .doc(assessmentId);

    final submissionRef = userAssessmentRef
        .collection('submissions')
        .doc(submissionId);

    final String status =
        ['in-progress', 'submitted', 'evaluated'][_random.nextInt(3)];
    int totalScore = 0;

    final Map<String, dynamic> submissionData = {
      'userId': userId,
      'userName': userData[userId]?['displayName'] ?? 'Unknown User',
      'startedAt': FieldValue.serverTimestamp(),
      'submittedAt':
          status == 'in-progress' ? null : FieldValue.serverTimestamp(),
      'status': status,
      'totalScore': 0,
      'overallFeedback':
          status == 'evaluated' ? 'Overall feedback for this submission' : null,
    };

    await batchManager.set(submissionRef, submissionData);
    _logger.log(
      "Created submission $submissionId with status=$status",
      level: LogLevel.DEBUG,
    );

    int questionsToAnswer = questions.length;
    if (status == 'in-progress') {
      questionsToAnswer = _random.nextInt(questions.length) + 1;
      _logger.log(
        "In-progress submission will answer $questionsToAnswer of ${questions.length} questions",
        level: LogLevel.DEBUG,
      );
    }

    final List<Map<String, dynamic>> answersData = [];
    final int answersCreated = await _createAnswers(
      submissionRef,
      submissionId,
      questionsToAnswer,
      questions,
      status,
      answersData,
      batchManager,
    );

    if (status == 'evaluated') {
      await batchManager.update(submissionRef, {'totalScore': totalScore});
      submissionData['totalScore'] = totalScore;
      _logger.log(
        "Updated total score to $totalScore for submission $submissionId",
        level: LogLevel.DEBUG,
      );
    }

    final assessmentDoc =
        await _firestore.collection('assessments').doc(assessmentId).get();
    final String creatorId = assessmentDoc.data()?['creatorId'] ?? '';

    return {
      'data': submissionData,
      'answersData': answersData,
      'answers': answersCreated,
      'creatorId': creatorId,
    };
  }

  Future<int> _createAnswers(
    DocumentReference submissionRef,
    String submissionId,
    int questionsToAnswer,
    List<Map<String, dynamic>> questions,
    String status,
    List<Map<String, dynamic>> answersData,
    BatchManager batchManager,
  ) async {
    int totalScore = 0;
    int answersCreated = 0;

    for (int q = 0; q < questionsToAnswer; q++) {
      final Map<String, dynamic> question = questions[q];
      final String questionId = question['id'];
      final String questionType = question['type'];
      final int maxPoints = question['points'];
      final List<dynamic>? options = question['options'];

      final String answerId =
          'answer_${submissionId}_${questionId}_${_random.nextInt(10000)}';
      final answerRef = submissionRef.collection('answers').doc(answerId);

      String userAnswer;
      if (questionType == 'multiple-choice' &&
          options != null &&
          options.isNotEmpty) {
        userAnswer = options[_random.nextInt(options.length)];
      } else if (questionType == 'true-false') {
        userAnswer = _random.nextBool() ? 'True' : 'False';
      } else {
        userAnswer = 'User answer for question ${q + 1}';
      }

      final Map<String, dynamic> answerData = {
        'questionId': questionId,
        'userAnswer': userAnswer,
        'answeredAt': FieldValue.serverTimestamp(),
      };

      if (status == 'evaluated') {
        final int score = _random.nextInt(maxPoints + 1);
        totalScore += score;

        answerData['score'] = score;
        answerData['feedback'] = 'Feedback for this answer';
        answerData['evaluatedAt'] = FieldValue.serverTimestamp();
        _logger.log(
          "Added evaluation for answer with score $score",
          level: LogLevel.DEBUG,
        );
      }

      answersData.add({'id': answerId, 'data': answerData});

      await batchManager.set(answerRef, answerData);
      answersCreated++;
    }

    return answersCreated;
  }

  Future<int> _mirrorSubmissionToGroups(
    String assessmentId,
    DocumentReference assessmentRef,
    String userId, {
    required String creatorId,
    required String submissionId,
    required Map<String, dynamic> submissionData,
    required List<Map<String, dynamic>> answersData,
    required Map<String, Map<String, String>> groupChannelsCache,
    required Map<String, Map<String, dynamic>> userData,
    required BatchManager batchManager,
  }) async {
    _logger.log(
      "Assessment was shared in a group, mirroring submission to group channels",
      level: LogLevel.DEBUG,
    );

    final sharedGroupsSnapshot =
        await assessmentRef.collection('sharedWithGroups').get();

    if (sharedGroupsSnapshot.docs.isEmpty) {
      _logger.log(
        "WARNING: Assessment $assessmentId has wasSharedInGroup=true but no entries in sharedWithGroups collection",
        level: LogLevel.WARNING,
      );
      return 0;
    }

    int successfulMirrors = 0;

    for (final groupDoc in sharedGroupsSnapshot.docs) {
      final String groupId = groupDoc.id;
      _logger.log(
        "Checking group $groupId for mirroring assessment $assessmentId",
        level: LogLevel.DEBUG,
      );

      final membershipSnapshot =
          await _firestore
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .doc(userId)
              .get();

      if (!membershipSnapshot.exists) {
        _logger.log(
          "User $userId is not a member of group $groupId, skipping",
          level: LogLevel.DEBUG,
        );
        continue;
      }

      String? channelId;
      if (groupChannelsCache.containsKey(groupId) &&
          groupChannelsCache[groupId]!.isNotEmpty) {
        channelId = groupChannelsCache[groupId]!.keys.first;
        _logger.log(
          "Using cached assessment channel $channelId for group $groupId",
          level: LogLevel.DEBUG,
        );
      } else {
        final channelsSnapshot =
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('channels')
                .where('type', isEqualTo: 'assessment')
                .limit(1)
                .get();

        if (channelsSnapshot.docs.isEmpty) {
          _logger.log(
            "WARNING: No assessment channel found for group $groupId",
            level: LogLevel.WARNING,
          );
          continue;
        }

        channelId = channelsSnapshot.docs.first.id;
        _logger.log(
          "Found assessment channel $channelId for group $groupId",
          level: LogLevel.DEBUG,
        );
      }

      final success = await _ensureAssessmentInChannel(
        groupId,
        channelId,
        assessmentId,
        assessmentRef,
        creatorId,
        userId,
        batchManager,
      );

      if (!success) continue;

      final channelAssessmentRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('channels')
          .doc(channelId)
          .collection('assessments')
          .doc(assessmentId);

      final groupSubmissionRef = channelAssessmentRef
          .collection('submissions')
          .doc(submissionId);

      await batchManager.set(groupSubmissionRef, submissionData);
      _logger.log(
        "Mirrored submission $submissionId to group $groupId channel $channelId",
        level: LogLevel.DEBUG,
      );

      int answersAddedToGroup = 0;
      for (final answerItem in answersData) {
        final groupAnswerRef = groupSubmissionRef
            .collection('answers')
            .doc(answerItem['id']);

        await batchManager.set(groupAnswerRef, answerItem['data']);
        answersAddedToGroup++;
      }

      _logger.log(
        "Copied $answersAddedToGroup answers to group submission",
        level: LogLevel.DEBUG,
      );
      successfulMirrors++;
    }

    return successfulMirrors;
  }

  Future<bool> _ensureAssessmentInChannel(
    String groupId,
    String channelId,
    String assessmentId,
    DocumentReference assessmentRef,
    String creatorId,
    String userId,
    BatchManager batchManager,
  ) async {
    final channelAssessmentRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('channels')
        .doc(channelId)
        .collection('assessments')
        .doc(assessmentId);

    final channelAssessmentDoc = await channelAssessmentRef.get();

    if (!channelAssessmentDoc.exists) {
      _logger.log(
        "ERROR: Assessment $assessmentId not found in channel $channelId, creating it now",
        level: LogLevel.ERROR,
      );

      final assessmentDoc = await assessmentRef.get();

      if (!assessmentDoc.exists) {
        _logger.log(
          "ERROR: Original assessment $assessmentId does not exist, cannot mirror",
          level: LogLevel.ERROR,
        );
        return false;
      }

      String assignerId = userId;

      final mentorsQuery =
          await _firestore
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .where('role', isEqualTo: 'mentor')
              .limit(1)
              .get();

      if (mentorsQuery.docs.isNotEmpty) {
        assignerId = mentorsQuery.docs.first.id;
      }

      final assessmentData =
          assessmentDoc.data() as Map<String, dynamic>? ?? {};
      await batchManager.set(channelAssessmentRef, {
        'title': assessmentData['title'] ?? 'Assessment',
        'description': assessmentData['description'] ?? '',
        'assignedBy': assignerId,
        'assignedAt': FieldValue.serverTimestamp(),
        'startTime': FieldValue.serverTimestamp(),
        'endTime': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 14)),
        ),
        'hasTimer': false,
        'timerDuration': 30,
        'madeByAI': assessmentData['madeByAI'] ?? false,
      });

      _logger.log(
        "Created missing assessment $assessmentId in channel $channelId",
        level: LogLevel.INFO,
      );
    }

    return true;
  }
}
