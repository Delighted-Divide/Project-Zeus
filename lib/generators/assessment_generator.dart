import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/log_level.dart';
import '../models/static_data.dart';
import '../services/batch_manager.dart';
import '../utils/logging_utils.dart';

class AssessmentGenerator {
  final FirebaseFirestore _firestore;
  final LoggingUtils _logger = LoggingUtils();
  final Random _random = Random();

  AssessmentGenerator(this._firestore);

  Future<List<String>> generateAssessments(
    List<String> userIds,
    List<String> tagIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting assessment generation", level: LogLevel.INFO);

    final List<String> assessmentIds = [];
    final assessmentData = StaticData.getAssessmentData();
    final questionTypes = StaticData.getQuestionTypes();

    final int numAssessments = min(
      StaticData.NUM_ASSESSMENTS,
      assessmentData.length,
    );
    _logger.log(
      "Will create $numAssessments assessments",
      level: LogLevel.INFO,
    );
    int totalQuestions = 0;

    for (int i = 0; i < numAssessments; i++) {
      final String assessmentTitle = assessmentData[i]['title'] ?? '';
      if (assessmentTitle.isEmpty) {
        _logger.log(
          "WARNING: Skipping assessment with empty title at index $i",
          level: LogLevel.WARNING,
        );
        continue;
      }

      final String assessmentId =
          'assessment_${i}_${assessmentTitle.toLowerCase().replaceAll(' ', '_')}_${_random.nextInt(10000)}';
      assessmentIds.add(assessmentId);
      _logger.log(
        "Creating assessment: $assessmentId - $assessmentTitle",
        level: LogLevel.DEBUG,
      );

      final String creatorId = userIds[_random.nextInt(userIds.length)];

      final List<String> assessmentTags = [];
      final int numTags = _random.nextInt(3) + 2;

      final List<String> availableTags = List.from(tagIds);
      availableTags.shuffle(_random);
      assessmentTags.addAll(availableTags.take(numTags));

      final assessmentRef = _firestore
          .collection('assessments')
          .doc(assessmentId);

      final int numberOfQuestions = _random.nextInt(5) + 3;
      final int totalPoints = numberOfQuestions * 5;

      await batchManager.set(assessmentRef, {
        'title': assessmentTitle,
        'creatorId': creatorId,
        'sourceDocumentId': 'doc_${_random.nextInt(1000)}',
        'createdAt': FieldValue.serverTimestamp(),
        'description': assessmentData[i]['description'],
        'difficulty': ['easy', 'medium', 'hard'][_random.nextInt(3)],
        'isPublic': _random.nextBool(),
        'totalPoints': totalPoints,
        'tags': assessmentTags,
        'rating': _random.nextInt(5) + 1,
        'madeByAI': _random.nextBool(),
      });

      final creatorRef = _firestore.collection('users').doc(creatorId);
      final creatorAssessmentRef = creatorRef
          .collection('assessments')
          .doc(assessmentId);
      await batchManager.set(creatorAssessmentRef, {
        'title': assessmentTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'description': assessmentData[i]['description'],
        'difficulty': ['easy', 'medium', 'hard'][_random.nextInt(3)],
        'totalPoints': totalPoints,
        'rating': _random.nextInt(5) + 1,
        'sourceDocumentId': 'doc_${_random.nextInt(1000)}',
        'madeByAI': _random.nextBool(),
        'wasSharedWithUser': false,
        'wasSharedInGroup': false,
      });

      for (int qIdx = 0; qIdx < numberOfQuestions; qIdx++) {
        final String questionId =
            'question_${assessmentId}_${qIdx}_${_random.nextInt(1000)}';
        final String questionType =
            questionTypes[_random.nextInt(questionTypes.length)];

        final questionRef = assessmentRef
            .collection('questions')
            .doc(questionId);
        final Map<String, dynamic> questionData = {
          'questionType': questionType,
          'questionText': 'Sample question ${qIdx + 1} for ${assessmentTitle}',
          'points': _random.nextInt(5) + 1,
        };

        if (questionType == 'multiple-choice') {
          questionData['options'] = [
            'Option A',
            'Option B',
            'Option C',
            'Option D',
          ];
        }

        await batchManager.set(questionRef, questionData);

        final answerRef = assessmentRef
            .collection('answers')
            .doc('answer_for_$questionId');
        final Map<String, dynamic> answerData = {
          'questionId': questionId,
          'answerType': questionType,
          'reasoning':
              'Explanation for the correct answer to question ${qIdx + 1}',
        };

        if (questionType == 'multiple-choice') {
          answerData['answerText'] =
              ['Option A', 'Option B', 'Option C', 'Option D'][_random.nextInt(
                4,
              )];
        } else if (questionType == 'true-false') {
          answerData['answerText'] = _random.nextBool() ? 'True' : 'False';
        } else {
          answerData['answerText'] = 'Sample answer for question ${qIdx + 1}';
        }

        await batchManager.set(answerRef, answerData);
        totalQuestions++;
      }
    }

    _logger.log(
      "Completed assessment generation. Created ${assessmentIds.length} assessments with $totalQuestions total questions",
      level: LogLevel.INFO,
    );
    return assessmentIds;
  }

  Future<void> shareAssessments(
    List<String> userIds,
    List<String> groupIds,
    List<String> assessmentIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log(
      "Starting assessment sharing with FIXED flag preservation",
      level: LogLevel.INFO,
    );
    int assessmentsSharedWithUsers = 0;
    int assessmentsSharedWithGroups = 0;
    int assessmentChannelsLinked = 0;

    final Map<String, Map<String, dynamic>> assessmentData = {};
    final List<Future<void>> assessmentDataFutures = [];

    for (String assessmentId in assessmentIds) {
      assessmentDataFutures.add(
        _firestore.collection('assessments').doc(assessmentId).get().then((
          snapshot,
        ) {
          if (snapshot.exists) {
            assessmentData[assessmentId] = snapshot.data() ?? {};
          }
        }),
      );
    }

    await Future.wait(assessmentDataFutures);
    _logger.log(
      "Retrieved data for ${assessmentData.length} assessments",
      level: LogLevel.INFO,
    );

    Map<String, List<String>> userFriends = {};
    final List<Future<void>> friendFutures = [];

    for (String userId in userIds) {
      friendFutures.add(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('friends')
            .get()
            .then((snapshot) {
              userFriends[userId] = snapshot.docs.map((doc) => doc.id).toList();
            }),
      );
    }

    await Future.wait(friendFutures);
    _logger.log(
      "Retrieved friend data for ${userFriends.length} users",
      level: LogLevel.INFO,
    );

    final Map<String, Map<String, dynamic>> groupDataCache = {};
    final Map<String, String> groupMentors = {};
    final Map<String, String> groupMentorNames = {};
    final Map<String, String> groupChannels = {};
    final List<Future<void>> groupDataFutures = [];

    for (String groupId in groupIds) {
      groupDataFutures.add(
        _firestore.collection('groups').doc(groupId).get().then((snapshot) {
          if (snapshot.exists) {
            groupDataCache[groupId] = snapshot.data() ?? {};
          }
        }),
      );
    }
    await Future.wait(groupDataFutures);
    _logger.log(
      "Retrieved basic data for ${groupDataCache.length} groups",
      level: LogLevel.INFO,
    );

    final List<Future<void>> groupDetailsFutures = [];
    for (String groupId in groupDataCache.keys) {
      groupDetailsFutures.add(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .where('role', isEqualTo: 'mentor')
            .limit(1)
            .get()
            .then((mentorSnapshot) {
              if (mentorSnapshot.docs.isNotEmpty) {
                groupMentors[groupId] = mentorSnapshot.docs.first.id;
                groupMentorNames[groupId] =
                    mentorSnapshot.docs.first.data()['displayName'] ??
                    'Group Mentor';
                _logger.log(
                  "Found mentor ${groupMentorNames[groupId]} for group $groupId",
                  level: LogLevel.DEBUG,
                );
              } else {
                _logger.log(
                  "WARNING: No mentor found for group $groupId",
                  level: LogLevel.WARNING,
                );
              }
            }),
      );

      groupDetailsFutures.add(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('channels')
            .where('type', isEqualTo: 'assessment')
            .limit(1)
            .get()
            .then((channelSnapshot) {
              if (channelSnapshot.docs.isNotEmpty) {
                groupChannels[groupId] = channelSnapshot.docs.first.id;
                _logger.log(
                  "Found assessment channel ${channelSnapshot.docs.first.id} for group $groupId",
                  level: LogLevel.DEBUG,
                );
              } else {
                _logger.log(
                  "WARNING: No assessment channel found for group $groupId",
                  level: LogLevel.WARNING,
                );
              }
            }),
      );
    }

    await Future.wait(groupDetailsFutures);
    _logger.log(
      "Found ${groupMentors.length} group mentors and ${groupChannels.length} assessment channels",
      level: LogLevel.INFO,
    );

    for (String assessmentId in assessmentIds) {
      if (!assessmentData.containsKey(assessmentId)) {
        _logger.log(
          "WARNING: Assessment $assessmentId data not found, skipping",
          level: LogLevel.WARNING,
        );
        continue;
      }

      final String creatorId = assessmentData[assessmentId]?['creatorId'] ?? '';
      if (creatorId.isEmpty) {
        _logger.log(
          "WARNING: Assessment $assessmentId has no creator ID, skipping",
          level: LogLevel.WARNING,
        );
        continue;
      }

      final String assessmentTitle =
          assessmentData[assessmentId]?['title'] ?? 'Assessment $assessmentId';
      final int totalPoints =
          assessmentData[assessmentId]?['totalPoints'] ?? 100;

      _logger.log(
        "Processing sharing for assessment: $assessmentTitle ($assessmentId)",
        level: LogLevel.INFO,
      );

      final Map<String, Map<String, String>> existingSharedUsers = {};
      final Set<String> existingSharedGroups = {};

      final sharedUsersSnapshot =
          await _firestore
              .collection('assessments')
              .doc(assessmentId)
              .collection('sharedWithUsers')
              .get();

      for (final doc in sharedUsersSnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data.containsKey('userMap') && data['userMap'] is Map) {
          existingSharedUsers[doc.id] = Map<String, String>.from(
            data['userMap'],
          );
        } else {
          existingSharedUsers[doc.id] = {};
        }
        _logger.log(
          "Found existing shared user ${doc.id} with ${existingSharedUsers[doc.id]?.length} sharers",
          level: LogLevel.DEBUG,
        );
      }

      final sharedGroupsSnapshot =
          await _firestore
              .collection('assessments')
              .doc(assessmentId)
              .collection('sharedWithGroups')
              .get();

      for (final doc in sharedGroupsSnapshot.docs) {
        existingSharedGroups.add(doc.id);
        _logger.log(
          "Found existing shared group ${doc.id}",
          level: LogLevel.DEBUG,
        );
      }

      assessmentsSharedWithUsers += await _shareWithFriends(
        assessmentId,
        creatorId,
        userFriends,
        existingSharedUsers,
        userData,
        assessmentData,
        totalPoints,
        assessmentTitle,
        batchManager,
      );

      final results = await _shareWithGroups(
        assessmentId,
        creatorId,
        groupIds,
        groupDataCache,
        groupMentors,
        groupMentorNames,
        groupChannels,
        existingSharedGroups,
        existingSharedUsers,
        userData,
        assessmentData,
        totalPoints,
        assessmentTitle,
        batchManager,
      );

      assessmentsSharedWithGroups += results['groups'] as int;
      assessmentChannelsLinked += results['channels'] as int;

      if (batchManager.operationCount > 200) {
        _logger.log(
          "Committing batch during assessment sharing to avoid size limits",
          level: LogLevel.INFO,
        );
        await batchManager.commitBatch();
      }
    }

    _logger.log(
      "Completed assessment sharing: shared with $assessmentsSharedWithUsers users and $assessmentsSharedWithGroups groups",
      level: LogLevel.INFO,
    );
    _logger.log(
      "Linked assessments to $assessmentChannelsLinked group channels",
      level: LogLevel.INFO,
    );
  }

  Future<int> _shareWithFriends(
    String assessmentId,
    String creatorId,
    Map<String, List<String>> userFriends,
    Map<String, Map<String, String>> existingSharedUsers,
    Map<String, Map<String, dynamic>> userData,
    Map<String, Map<String, dynamic>> assessmentData,
    int totalPoints,
    String assessmentTitle,
    BatchManager batchManager,
  ) async {
    int sharedWithUsersCount = 0;

    final List<String> creatorFriends = userFriends[creatorId] ?? [];
    final int numFriendsToShare = min(
      StaticData.MIN_SHARED_USERS,
      creatorFriends.length,
    );

    if (creatorFriends.isNotEmpty) {
      creatorFriends.shuffle(_random);
      final List<String> selectedFriends =
          creatorFriends.take(numFriendsToShare).toList();

      final String creatorName =
          userData[creatorId]?['displayName'] ?? 'Assessment Creator';

      for (String friendId in selectedFriends) {
        _logger.log(
          "Sharing assessment $assessmentId with user $friendId",
          level: LogLevel.DEBUG,
        );

        final sharedUserRef = _firestore
            .collection('assessments')
            .doc(assessmentId)
            .collection('sharedWithUsers')
            .doc(friendId);

        if (existingSharedUsers.containsKey(friendId)) {
          Map<String, String> updatedUserMap = Map<String, String>.from(
            existingSharedUsers[friendId]!,
          );
          updatedUserMap[creatorId] = creatorName;

          await batchManager.set(sharedUserRef, {
            'userMap': updatedUserMap,
            'sharedAt': FieldValue.serverTimestamp(),
          });

          _logger.log(
            "Updated userMap for existing shared user $friendId, added $creatorId",
            level: LogLevel.DEBUG,
          );
        } else {
          await batchManager.set(sharedUserRef, {
            'userMap': {creatorId: creatorName},
            'sharedAt': FieldValue.serverTimestamp(),
          });

          _logger.log(
            "Created new sharedWithUsers entry for $friendId",
            level: LogLevel.DEBUG,
          );
        }

        final friendRef = _firestore.collection('users').doc(friendId);
        final friendAssessmentRef = friendRef
            .collection('assessments')
            .doc(assessmentId);
        final friendAssessmentDoc = await friendAssessmentRef.get();

        if (friendAssessmentDoc.exists) {
          final bool existingWasSharedWithUser =
              friendAssessmentDoc.data()?['wasSharedWithUser'] ?? false;
          final bool existingWasSharedInGroup =
              friendAssessmentDoc.data()?['wasSharedInGroup'] ?? false;

          final Map<String, dynamic> updatedData = Map<String, dynamic>.from(
            friendAssessmentDoc.data() ?? {},
          );

          updatedData['title'] = assessmentTitle;
          updatedData['createdAt'] = FieldValue.serverTimestamp();
          updatedData['description'] =
              assessmentData[assessmentId]?['description'] ?? '';
          updatedData['difficulty'] =
              assessmentData[assessmentId]?['difficulty'] ?? 'medium';
          updatedData['totalPoints'] = totalPoints;
          updatedData['rating'] = assessmentData[assessmentId]?['rating'] ?? 3;
          updatedData['sourceDocumentId'] =
              assessmentData[assessmentId]?['sourceDocumentId'] ?? '';
          updatedData['madeByAI'] =
              assessmentData[assessmentId]?['madeByAI'] ?? false;

          updatedData['wasSharedWithUser'] = true;
          updatedData['wasSharedInGroup'] = existingWasSharedInGroup;

          await batchManager.set(friendAssessmentRef, updatedData);

          _logger.log(
            "Updated assessment for user $friendId, wasSharedWithUser=true, wasSharedInGroup=$existingWasSharedInGroup",
            level: LogLevel.DEBUG,
          );
        } else {
          await batchManager.set(friendAssessmentRef, {
            'title': assessmentTitle,
            'createdAt': FieldValue.serverTimestamp(),
            'description': assessmentData[assessmentId]?['description'] ?? '',
            'difficulty':
                assessmentData[assessmentId]?['difficulty'] ?? 'medium',
            'totalPoints': totalPoints,
            'rating': assessmentData[assessmentId]?['rating'] ?? 3,
            'sourceDocumentId':
                assessmentData[assessmentId]?['sourceDocumentId'] ?? '',
            'madeByAI': assessmentData[assessmentId]?['madeByAI'] ?? false,
            'wasSharedWithUser': true,
            'wasSharedInGroup': false,
          });

          _logger.log(
            "Created new assessment document for user $friendId",
            level: LogLevel.DEBUG,
          );
        }

        sharedWithUsersCount++;
      }
    }

    return sharedWithUsersCount;
  }

  Future<Map<String, int>> _shareWithGroups(
    String assessmentId,
    String creatorId,
    List<String> groupIds,
    Map<String, Map<String, dynamic>> groupDataCache,
    Map<String, String> groupMentors,
    Map<String, String> groupMentorNames,
    Map<String, String> groupChannels,
    Set<String> existingSharedGroups,
    Map<String, Map<String, String>> existingSharedUsers,
    Map<String, Map<String, dynamic>> userData,
    Map<String, Map<String, dynamic>> assessmentData,
    int totalPoints,
    String assessmentTitle,
    BatchManager batchManager,
  ) async {
    int sharedWithGroupsCount = 0;
    int channelsLinkedCount = 0;

    final assessmentRef = _firestore
        .collection('assessments')
        .doc(assessmentId);

    final int numGroupsToShare = min(
      StaticData.MIN_SHARED_GROUPS,
      groupIds.length,
    );

    if (groupIds.isNotEmpty) {
      final List<String> eligibleGroups =
          groupIds
              .where(
                (groupId) =>
                    groupMentors.containsKey(groupId) &&
                    groupChannels.containsKey(groupId),
              )
              .toList();

      if (eligibleGroups.isEmpty) {
        _logger.log(
          "WARNING: No eligible groups found for sharing assessment $assessmentId",
          level: LogLevel.WARNING,
        );
        return {'groups': 0, 'channels': 0};
      }

      eligibleGroups.shuffle(_random);
      final List<String> selectedGroups =
          eligibleGroups.take(numGroupsToShare).toList();

      for (String groupId in selectedGroups) {
        _logger.log(
          "Sharing assessment $assessmentId with group $groupId",
          level: LogLevel.DEBUG,
        );

        final String mentorId = groupMentors[groupId]!;
        final String mentorName = groupMentorNames[groupId]!;
        final String channelId = groupChannels[groupId]!;
        final String groupName =
            groupDataCache[groupId]?['name'] ?? 'Group $groupId';

        if (existingSharedGroups.contains(groupId)) {
          _logger.log(
            "Assessment $assessmentId already shared with group $groupId, skipping",
            level: LogLevel.DEBUG,
          );
          continue;
        }

        final sharedGroupRef = assessmentRef
            .collection('sharedWithGroups')
            .doc(groupId);

        await batchManager.set(sharedGroupRef, {
          'groupName': groupName,
          'sharedBy': mentorId,
          'sharedAt': FieldValue.serverTimestamp(),
          'startTime': FieldValue.serverTimestamp(),
          'endTime': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 14)),
          ),
          'hasTimer': _random.nextBool(),
          'timerDuration': 30,
          'attemptsAllowed': _random.nextInt(3) + 1,
        });

        _logger.log(
          "Added group $groupId to assessment $assessmentId sharedWithGroups collection",
          level: LogLevel.DEBUG,
        );

        final channelRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('channels')
            .doc(channelId);

        final channelAssessmentRef = channelRef
            .collection('assessments')
            .doc(assessmentId);

        final channelAssessmentDoc = await channelAssessmentRef.get();
        if (!channelAssessmentDoc.exists) {
          await batchManager.set(channelAssessmentRef, {
            'title': assessmentTitle,
            'description': assessmentData[assessmentId]?['description'] ?? '',
            'assignedBy': mentorId,
            'assignedAt': FieldValue.serverTimestamp(),
            'startTime': FieldValue.serverTimestamp(),
            'endTime': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 14)),
            ),
            'hasTimer': _random.nextBool(),
            'timerDuration': 30,
            'madeByAI': assessmentData[assessmentId]?['madeByAI'] ?? false,
          });

          _logger.log(
            "Linked assessment $assessmentId to channel $channelId in group $groupId",
            level: LogLevel.INFO,
          );
          channelsLinkedCount++;
        } else {
          _logger.log(
            "Assessment $assessmentId already exists in channel $channelId",
            level: LogLevel.DEBUG,
          );
        }

        final membersSnapshot =
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('members')
                .get();

        _logger.log(
          "Processing ${membersSnapshot.docs.length} members for group $groupId",
          level: LogLevel.DEBUG,
        );

        for (final memberDoc in membersSnapshot.docs) {
          final String memberId = memberDoc.id;

          if (memberId == creatorId) {
            _logger.log(
              "Skipping creator $creatorId as member",
              level: LogLevel.DEBUG,
            );
            continue;
          }

          final sharedUserRef = assessmentRef
              .collection('sharedWithUsers')
              .doc(memberId);

          if (existingSharedUsers.containsKey(memberId)) {
            Map<String, String> updatedUserMap = Map<String, String>.from(
              existingSharedUsers[memberId]!,
            );
            updatedUserMap[mentorId] = mentorName;

            await batchManager.set(sharedUserRef, {
              'userMap': updatedUserMap,
              'sharedAt': FieldValue.serverTimestamp(),
            });

            _logger.log(
              "Updated userMap for member $memberId, added $mentorId",
              level: LogLevel.DEBUG,
            );
          } else {
            await batchManager.set(sharedUserRef, {
              'userMap': {mentorId: mentorName},
              'sharedAt': FieldValue.serverTimestamp(),
            });

            _logger.log(
              "Created new sharedWithUsers entry for member $memberId",
              level: LogLevel.DEBUG,
            );
          }

          final memberRef = _firestore.collection('users').doc(memberId);
          final memberAssessmentRef = memberRef
              .collection('assessments')
              .doc(assessmentId);
          final memberAssessmentDoc = await memberAssessmentRef.get();

          if (memberAssessmentDoc.exists) {
            final bool existingWasSharedWithUser =
                memberAssessmentDoc.data()?['wasSharedWithUser'] ?? false;
            final bool existingWasSharedInGroup =
                memberAssessmentDoc.data()?['wasSharedInGroup'] ?? false;

            final Map<String, dynamic> updatedData = Map<String, dynamic>.from(
              memberAssessmentDoc.data() ?? {},
            );

            updatedData['title'] = assessmentTitle;
            updatedData['description'] =
                assessmentData[assessmentId]?['description'] ?? '';
            updatedData['difficulty'] =
                assessmentData[assessmentId]?['difficulty'] ?? 'medium';
            updatedData['totalPoints'] = totalPoints;
            updatedData['rating'] =
                assessmentData[assessmentId]?['rating'] ?? 3;
            updatedData['sourceDocumentId'] =
                assessmentData[assessmentId]?['sourceDocumentId'] ?? '';
            updatedData['madeByAI'] =
                assessmentData[assessmentId]?['madeByAI'] ?? false;

            updatedData['wasSharedWithUser'] = existingWasSharedWithUser;
            updatedData['wasSharedInGroup'] = true;

            await batchManager.set(memberAssessmentRef, updatedData);

            _logger.log(
              "Updated assessment for member $memberId, wasSharedWithUser=$existingWasSharedWithUser, wasSharedInGroup=true",
              level: LogLevel.DEBUG,
            );
          } else {
            await batchManager.set(memberAssessmentRef, {
              'title': assessmentTitle,
              'createdAt': FieldValue.serverTimestamp(),
              'description': assessmentData[assessmentId]?['description'] ?? '',
              'difficulty':
                  assessmentData[assessmentId]?['difficulty'] ?? 'medium',
              'totalPoints': totalPoints,
              'rating': assessmentData[assessmentId]?['rating'] ?? 3,
              'sourceDocumentId':
                  assessmentData[assessmentId]?['sourceDocumentId'] ?? '',
              'madeByAI': assessmentData[assessmentId]?['madeByAI'] ?? false,
              'wasSharedWithUser': false,
              'wasSharedInGroup': true,
            });

            _logger.log(
              "Created new assessment document for member $memberId",
              level: LogLevel.DEBUG,
            );
          }
        }

        sharedWithGroupsCount++;
      }
    }

    return {'groups': sharedWithGroupsCount, 'channels': channelsLinkedCount};
  }
}
