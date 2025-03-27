import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class DummyDataGenerator {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BuildContext context;
  final Random _random = Random();

  // List of asset placeholder images to use

  // Constructor
  DummyDataGenerator(this.context);

  // Main function to generate all dummy data
  Future<void> generateAllDummyData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('No user signed in. Please sign in first.', Colors.red);
        return;
      }

      _showSnackBar('Starting to generate dummy data...', Colors.blue);

      // Starting with a clean batch
      WriteBatch batch = _firestore.batch();
      int operationCount =
          0; // Track operations to avoid exceeding batch limits

      // Function to commit batch and start a new one when needed
      Future<void> commitBatchIfNeeded() async {
        if (operationCount >= 450) {
          // Firebase limit is 500, stay under it
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
          print('Committed batch and started a new one');
        }
      }

      // Generate data for each collection - store user data for reference
      final Map<String, Map<String, dynamic>> userData = {};
      final userIds = await _generateDummyUsers(
        currentUser,
        batch,
        userData,
        commitBatchIfNeeded,
      );
      await commitBatchIfNeeded();

      final tagIds = await _generateDummyTags(batch, commitBatchIfNeeded);
      await commitBatchIfNeeded();

      // Assign random favorite tags to users
      await _assignFavoriteTags(
        userIds,
        tagIds,
        userData,
        batch,
        commitBatchIfNeeded,
      );
      await commitBatchIfNeeded();

      final groupIds = await _generateDummyGroups(
        currentUser,
        userIds,
        tagIds,
        userData,
        batch,
        commitBatchIfNeeded,
      );
      await commitBatchIfNeeded();

      final assessmentIds = await _generateDummyAssessments(
        currentUser,
        userIds,
        tagIds,
        userData,
        batch,
        commitBatchIfNeeded,
      );
      await commitBatchIfNeeded();

      // Create relationships between entities
      await _createFriendships(
        currentUser,
        userIds,
        userData,
        batch,
        commitBatchIfNeeded,
      );
      await commitBatchIfNeeded();

      await _createGroupMemberships(
        currentUser,
        userIds,
        groupIds,
        userData,
        batch,
        commitBatchIfNeeded,
      );
      await commitBatchIfNeeded();

      await _shareAssessments(
        currentUser,
        userIds,
        groupIds,
        assessmentIds,
        userData,
        batch,
        commitBatchIfNeeded,
      );

      // Final commit
      await batch.commit();

      _showSnackBar(
        'Dummy data generation completed successfully!',
        Colors.green,
      );
    } catch (e) {
      print('Error generating dummy data: $e');
      _showSnackBar('Error generating dummy data: $e', Colors.red);
    }
  }

  // Show snackbar with message
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  // Generate dummy users
  Future<List<String>> _generateDummyUsers(
    User currentUser,
    WriteBatch batch,
    Map<String, Map<String, dynamic>> userData,
    Function commitBatchIfNeeded,
  ) async {
    final List<String> userIds = [currentUser.uid]; // Start with current user
    final int numberOfDummyUsers = 20; // Increased from 10 to 20 users
    int operationCount = 0;

    // Generate random user data
    final List<String> firstNames = [
      'Alex',
      'Jamie',
      'Taylor',
      'Jordan',
      'Casey',
      'Riley',
      'Morgan',
      'Avery',
      'Quinn',
      'Dakota',
      'Reese',
      'Skyler',
      'Cameron',
      'Logan',
      'Harper',
      'Kennedy',
      'Peyton',
      'Emerson',
      'Bailey',
      'Rowan',
      'Finley',
      'Blake',
      'Hayden',
      'Parker',
    ];
    final List<String> lastNames = [
      'Smith',
      'Johnson',
      'Williams',
      'Brown',
      'Jones',
      'Garcia',
      'Miller',
      'Davis',
      'Rodriguez',
      'Martinez',
      'Hernandez',
      'Lopez',
      'Wilson',
      'Anderson',
      'Thomas',
      'Taylor',
      'Moore',
      'Jackson',
      'Martin',
      'Lee',
      'Perez',
      'Thompson',
      'White',
      'Harris',
    ];

    // Get real data for current user
    final currentUserDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();

    // Current user document reference
    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    String currentUserDisplayName = currentUser.displayName ?? 'Current User';

    // Create or update the current user's document
    if (!currentUserDoc.exists) {
      batch.set(currentUserRef, {
        'displayName': currentUserDisplayName,
        'email': currentUser.email,
        'photoURL': currentUser.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'privacyLevel': 'public',
        'favTags': [],
        'settings': {'notificationsEnabled': true, 'theme': 'light'},
      });
      operationCount++;
    } else {
      // Get existing data for current user
      final existingData = currentUserDoc.data();
      if (existingData != null && existingData['displayName'] != null) {
        currentUserDisplayName = existingData['displayName'];
      }
    }

    // Store current user data in our reference map
    userData[currentUser.uid] = {
      'displayName': currentUserDisplayName,
      'email': currentUser.email,
      'photoURL': currentUser.photoURL,
    };

    // Create dummy users
    for (int i = 0; i < numberOfDummyUsers; i++) {
      await commitBatchIfNeeded();

      // Create deterministic but unique user IDs
      final String dummyUserId = 'dummy_user_${_random.nextInt(10000)}_$i';
      userIds.add(dummyUserId);

      // Generate a random name
      final String firstName = firstNames[_random.nextInt(firstNames.length)];
      final String lastName = lastNames[_random.nextInt(lastNames.length)];
      final String displayName = '$firstName $lastName';
      final String email =
          '${firstName.toLowerCase()}.${lastName.toLowerCase()}$i@example.com';

      // Generate and save a profile picture
      final String? photoURL = await _generateDummyProfileImage(dummyUserId);

      // Create the user document
      final userRef = _firestore.collection('users').doc(dummyUserId);

      Map<String, dynamic> userDocData = {
        'displayName': displayName,
        'email': email,
        'photoURL': photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'privacyLevel':
            ['public', 'friends-only', 'private'][_random.nextInt(3)],
        'favTags': [], // Will be filled later
        'settings': {
          'notificationsEnabled': _random.nextBool(),
          'theme': ['light', 'dark', 'system'][_random.nextInt(3)],
        },
      };

      batch.set(userRef, userDocData);
      operationCount++;

      // Store this user's data in our reference map
      userData[dummyUserId] = {
        'displayName': displayName,
        'email': email,
        'photoURL': photoURL,
      };
    }

    return userIds;
  }

  // Generate dummy tags
  Future<List<String>> _generateDummyTags(
    WriteBatch batch,
    Function commitBatchIfNeeded,
  ) async {
    final List<String> tagIds = [];
    int operationCount = 0;

    // Subject tags
    final List<Map<String, String>> subjectTags = [
      {
        'name': 'Mathematics',
        'category': 'Subject',
        'description': 'All topics related to mathematics',
      },
      {
        'name': 'Physics',
        'category': 'Subject',
        'description':
            'Study of matter, energy, and the interaction between them',
      },
      {
        'name': 'Chemistry',
        'category': 'Subject',
        'description': 'Study of substances and their interactions',
      },
      {
        'name': 'Biology',
        'category': 'Subject',
        'description': 'Study of living organisms',
      },
      {
        'name': 'Computer Science',
        'category': 'Subject',
        'description': 'Study of computation and information processing',
      },
      {
        'name': 'History',
        'category': 'Subject',
        'description': 'Study of past events',
      },
      {
        'name': 'Geography',
        'category': 'Subject',
        'description': 'Study of places and environments',
      },
      {
        'name': 'Literature',
        'category': 'Subject',
        'description': 'Study of written works',
      },
    ];

    // Topic tags
    final List<Map<String, String>> topicTags = [
      {
        'name': 'Algebra',
        'category': 'Topic',
        'description': 'Branch of mathematics dealing with symbols',
      },
      {
        'name': 'Calculus',
        'category': 'Topic',
        'description': 'Study of continuous change',
      },
      {
        'name': 'Mechanics',
        'category': 'Topic',
        'description': 'Study of motion and forces',
      },
      {
        'name': 'Organic Chemistry',
        'category': 'Topic',
        'description': 'Study of carbon compounds',
      },
      {
        'name': 'Genetics',
        'category': 'Topic',
        'description': 'Study of genes and heredity',
      },
      {
        'name': 'World War II',
        'category': 'Topic',
        'description': 'Global war from 1939 to 1945',
      },
      {
        'name': 'Shakespeare',
        'category': 'Topic',
        'description': 'Works of William Shakespeare',
      },
      {
        'name': 'Climate Change',
        'category': 'Topic',
        'description': 'Long-term changes in temperature and weather patterns',
      },
    ];

    // Skill tags
    final List<Map<String, String>> skillTags = [
      {
        'name': 'Problem Solving',
        'category': 'Skill',
        'description':
            'Ability to find solutions to difficult or complex issues',
      },
      {
        'name': 'Critical Thinking',
        'category': 'Skill',
        'description': 'Objective analysis and evaluation to form a judgment',
      },
      {
        'name': 'Data Analysis',
        'category': 'Skill',
        'description': 'Process of inspecting, transforming, and modeling data',
      },
      {
        'name': 'Laboratory Skills',
        'category': 'Skill',
        'description': 'Practical skills used in a laboratory setting',
      },
      {
        'name': 'Programming',
        'category': 'Skill',
        'description': 'Creating computer programs to accomplish tasks',
      },
      {
        'name': 'Essay Writing',
        'category': 'Skill',
        'description': 'Ability to compose formal essays',
      },
      {
        'name': 'Research',
        'category': 'Skill',
        'description': 'Systematic investigation into materials and sources',
      },
      {
        'name': 'Presentation',
        'category': 'Skill',
        'description': 'Ability to deliver effective presentations',
      },
    ];

    // Combine all tags
    final List<Map<String, String>> allTags = [
      ...subjectTags,
      ...topicTags,
      ...skillTags,
    ];

    // Create tag documents
    for (var tag in allTags) {
      await commitBatchIfNeeded();

      final String tagId =
          'tag_${tag['name']?.toLowerCase().replaceAll(' ', '_') ?? ''}';
      tagIds.add(tagId);

      final tagRef = _firestore.collection('tags').doc(tagId);
      batch.set(tagRef, {
        'name': tag['name'],
        'category': tag['category'],
        'description': tag['description'],
      });
      operationCount++;
    }

    return tagIds;
  }

  // Assign favorite tags to users
  Future<void> _assignFavoriteTags(
    List<String> userIds,
    List<String> tagIds,
    Map<String, Map<String, dynamic>> userData,
    WriteBatch batch,
    Function commitBatchIfNeeded,
  ) async {
    int operationCount = 0;

    for (String userId in userIds) {
      await commitBatchIfNeeded();

      // Decide how many favorite tags this user will have (0-5)
      final int numFavTags = _random.nextInt(6);
      final List<String> userFavTags = [];

      // Select random tags
      for (int i = 0; i < numFavTags; i++) {
        if (tagIds.isNotEmpty) {
          final String tagId = tagIds[_random.nextInt(tagIds.length)];
          if (!userFavTags.contains(tagId)) {
            userFavTags.add(tagId);
          }
        }
      }

      // Update user document with favorite tags
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {'favTags': userFavTags});
      operationCount++;
    }
  }

  // Generate dummy groups
  Future<List<String>> _generateDummyGroups(
    User currentUser,
    List<String> userIds,
    List<String> tagIds,
    Map<String, Map<String, dynamic>> userData,
    WriteBatch batch,
    Function commitBatchIfNeeded,
  ) async {
    final List<String> groupIds = [];
    final int numberOfGroups = 10; // Increased from 5 to 10 groups
    int operationCount = 0;

    // Group names and descriptions
    final List<Map<String, String>> groupData = [
      {
        'name': 'Math Study Group',
        'description':
            'A group for students studying mathematics at all levels',
      },
      {
        'name': 'Physics Lab Partners',
        'description': 'Collaboration group for physics laboratory experiments',
      },
      {
        'name': 'Chemistry Tutoring',
        'description': 'Group for chemistry tutoring and homework help',
      },
      {
        'name': 'Biology Research Team',
        'description': 'Team working on various biology research projects',
      },
      {
        'name': 'Computer Science Club',
        'description': 'Club for computer science enthusiasts and programmers',
      },
      {
        'name': 'Literature Discussion',
        'description': 'Group for discussing classic and modern literature',
      },
      {
        'name': 'History Buffs',
        'description': 'For those who are passionate about historical events',
      },
      {
        'name': 'Environmental Science',
        'description': 'Focus on environmental issues and sustainability',
      },
      {
        'name': 'Debate Team',
        'description':
            'Practice and develop argumentation and public speaking skills',
      },
      {
        'name': 'Research Methods',
        'description': 'Group focused on academic research methodologies',
      },
    ];

    // Create group documents
    for (int i = 0; i < min(numberOfGroups, groupData.length); i++) {
      await commitBatchIfNeeded();

      final String groupId =
          'group_${groupData[i]['name']?.toLowerCase().replaceAll(' ', '_') ?? ''}_${_random.nextInt(1000)}';
      groupIds.add(groupId);

      // Select a random creator (either current user or a dummy user)
      final String creatorId =
          _random.nextBool()
              ? currentUser.uid
              : userIds[_random.nextInt(userIds.length)];

      // Generate and save a group profile picture
      final String? photoURL = await _generateDummyProfileImage(
        'group_$groupId',
      );

      // Select random tags for this group (1-4 tags)
      final List<String> groupTags = [];
      final int numTags = _random.nextInt(4) + 1;
      for (int t = 0; t < numTags; t++) {
        if (tagIds.isNotEmpty) {
          final String tagId = tagIds[_random.nextInt(tagIds.length)];
          if (!groupTags.contains(tagId)) {
            groupTags.add(tagId);
          }
        }
      }

      // Create the group document
      final groupRef = _firestore.collection('groups').doc(groupId);
      batch.set(groupRef, {
        'name': groupData[i]['name'],
        'description': groupData[i]['description'],
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': creatorId,
        'photoURL': photoURL,
        'tags': groupTags,
        'settings': {
          'visibility': ['public', 'private'][_random.nextInt(2)],
          'joinApproval': _random.nextBool(),
        },
      });
      operationCount++;

      // Add creator as admin member
      final creatorMemberRef = groupRef.collection('members').doc(creatorId);
      batch.set(creatorMemberRef, {
        'displayName': userData[creatorId]?['displayName'] ?? 'Unknown User',
        'photoURL': userData[creatorId]?['photoURL'],
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      operationCount++;
    }

    return groupIds;
  }

  // Generate dummy assessments
  Future<List<String>> _generateDummyAssessments(
    User currentUser,
    List<String> userIds,
    List<String> tagIds,
    Map<String, Map<String, dynamic>> userData,
    WriteBatch batch,
    Function commitBatchIfNeeded,
  ) async {
    final List<String> assessmentIds = [];
    final int numberOfAssessments = 15; // Increased from 8 to 15 assessments
    int operationCount = 0;

    // Assessment titles and descriptions
    final List<Map<String, String>> assessmentData = [
      {
        'title': 'Algebra Basics Quiz',
        'description': 'Test your knowledge of basic algebraic concepts',
      },
      {
        'title': 'Advanced Calculus',
        'description': 'Comprehensive assessment on advanced calculus topics',
      },
      {
        'title': 'Physics Mechanics Test',
        'description': 'Assessment covering Newtonian mechanics',
      },
      {
        'title': 'Organic Chemistry Challenge',
        'description': 'Test on organic chemistry reactions and mechanisms',
      },
      {
        'title': 'Biology Cell Functions',
        'description': 'Quiz on cell structures and their functions',
      },
      {
        'title': 'Programming Fundamentals',
        'description': 'Basic programming concepts assessment',
      },
      {
        'title': 'Data Structures Exam',
        'description': 'Test your knowledge of common data structures',
      },
      {
        'title': 'Scientific Method Quiz',
        'description': 'Assessment on the steps of the scientific method',
      },
      {
        'title': 'World History Timeline',
        'description': 'Test your knowledge of major historical events',
      },
      {
        'title': 'Literary Analysis',
        'description': 'Analyze themes and characters in classic literature',
      },
      {
        'title': 'Environmental Science Quiz',
        'description': 'Test on ecological principles and environmental issues',
      },
      {
        'title': 'Geometry Basics',
        'description': 'Assessment on fundamental geometric concepts',
      },
      {
        'title': 'Statistics Fundamentals',
        'description': 'Test on basic statistical methods and probability',
      },
      {
        'title': 'Chemical Reactions',
        'description': 'Quiz on balancing equations and reaction types',
      },
      {
        'title': 'Computer Networks',
        'description': 'Assessment on networking concepts and protocols',
      },
    ];

    // Question types
    final List<String> questionTypes = [
      'multiple-choice',
      'short-answer',
      'true-false',
      'matching',
      'fill-in-blank',
    ];

    // Create assessment documents
    for (int i = 0; i < min(numberOfAssessments, assessmentData.length); i++) {
      await commitBatchIfNeeded();

      final String assessmentId = 'assessment_${i}_${_random.nextInt(10000)}';
      assessmentIds.add(assessmentId);

      // Select a random creator (either current user or a dummy user)
      final String creatorId =
          _random.nextBool()
              ? currentUser.uid
              : userIds[_random.nextInt(userIds.length)];

      // Select random tags (1-3 tags per assessment)
      final List<String> assessmentTags = [];
      final int numTags = _random.nextInt(3) + 1;
      for (int j = 0; j < numTags && j < tagIds.length; j++) {
        final String tagId = tagIds[_random.nextInt(tagIds.length)];
        if (!assessmentTags.contains(tagId)) {
          assessmentTags.add(tagId);
        }
      }

      // Create the assessment document
      final assessmentRef = _firestore
          .collection('assessments')
          .doc(assessmentId);
      batch.set(assessmentRef, {
        'title': assessmentData[i]['title'],
        'creatorId': creatorId,
        'sourceDocumentId': 'doc_${_random.nextInt(1000)}', // Dummy document ID
        'createdAt': FieldValue.serverTimestamp(),
        'description': assessmentData[i]['description'],
        'difficulty': ['easy', 'medium', 'hard'][_random.nextInt(3)],
        'isPublic': _random.nextBool(),
        'totalPoints':
            ((_random.nextInt(5) + 1) * 10), // 10, 20, 30, 40, or 50 points
        'tags': assessmentTags,
        'rating': _random.nextInt(5) + 1, // 1-5 rating
      });
      operationCount++;

      // Add questions to the assessment
      final int numberOfQuestions = _random.nextInt(5) + 3; // 3-7 questions
      for (int qIdx = 0; qIdx < numberOfQuestions; qIdx++) {
        await commitBatchIfNeeded();

        final String questionId = 'question_${qIdx}_${_random.nextInt(1000)}';
        final String questionType =
            questionTypes[_random.nextInt(questionTypes.length)];

        // Create question document
        final questionRef = assessmentRef
            .collection('questions')
            .doc(questionId);
        final Map<String, dynamic> questionData = {
          'questionType': questionType,
          'questionText':
              'Sample question ${qIdx + 1} for ${assessmentData[i]['title']}',
          'points': _random.nextInt(5) + 1, // 1-5 points
        };

        // Add options for multiple-choice questions
        if (questionType == 'multiple-choice') {
          questionData['options'] = [
            'Option A',
            'Option B',
            'Option C',
            'Option D',
          ];
        }

        batch.set(questionRef, questionData);
        operationCount++;

        // Create corresponding answer
        final answerRef = assessmentRef
            .collection('answers')
            .doc('answer_for_$questionId');
        final Map<String, dynamic> answerData = {
          'questionId': questionId,
          'answerType': questionType,
          'reasoning':
              'Explanation for the correct answer to question ${qIdx + 1}',
        };

        // Set answer text based on question type
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

        batch.set(answerRef, answerData);
        operationCount++;
      }
    }

    return assessmentIds;
  }

  // Create friend relationships between users
  Future<void> _createFriendships(
    User currentUser,
    List<String> userIds,
    Map<String, Map<String, dynamic>> userData,
    WriteBatch batch,
    Function commitBatchIfNeeded,
  ) async {
    int operationCount = 0;

    // For each user, establish friend relationships with some other users
    for (String userId in userIds) {
      await commitBatchIfNeeded();

      // Decide how many friends this user will have (3-8)
      // This is increased from previous 1-3 range
      final int numberOfFriends = _random.nextInt(6) + 3;

      // Create friends for this user
      final List<String> friendIds = [];
      int attempts = 0; // Prevent infinite loop
      while (friendIds.length < numberOfFriends &&
          friendIds.length < userIds.length - 1 &&
          attempts < 30) {
        attempts++;

        // Pick a random user that's not the current user and not already a friend
        final String potentialFriendId =
            userIds[_random.nextInt(userIds.length)];
        if (potentialFriendId != userId &&
            !friendIds.contains(potentialFriendId)) {
          friendIds.add(potentialFriendId);

          // Create bidirectional friendship between users
          final userRef = _firestore.collection('users').doc(userId);
          final friendRef = _firestore
              .collection('users')
              .doc(potentialFriendId);

          // Use the correct display names from our userData map
          String userDisplayName =
              userData[userId]?['displayName'] ?? 'Unknown User';
          String friendDisplayName =
              userData[potentialFriendId]?['displayName'] ?? 'Unknown User';

          // First user's friends collection
          final userFriendDoc = userRef
              .collection('friends')
              .doc(potentialFriendId);
          batch.set(userFriendDoc, {
            'status': 'active',
            'displayName': friendDisplayName,
            'photoURL': userData[potentialFriendId]?['photoURL'],
            'becameFriendsAt': FieldValue.serverTimestamp(),
          });
          operationCount++;

          // Friend's friends collection
          final friendUserDoc = friendRef.collection('friends').doc(userId);
          batch.set(friendUserDoc, {
            'status': 'active',
            'displayName': userDisplayName,
            'photoURL': userData[userId]?['photoURL'],
            'becameFriendsAt': FieldValue.serverTimestamp(),
          });
          operationCount++;
        }
      }

      // Create some pending friend requests (4-8 requests)
      // This is increased from previous range
      final int numberOfRequests = _random.nextInt(5) + 4;
      final List<String> requestUserIds = [];

      attempts = 0; // Reset attempts counter
      while (requestUserIds.length < numberOfRequests &&
          requestUserIds.length < userIds.length - friendIds.length - 1 &&
          attempts < 30) {
        attempts++;

        // Pick a random user that's not the current user, not already a friend, and not already requested
        final String requestUserId = userIds[_random.nextInt(userIds.length)];
        if (requestUserId != userId &&
            !friendIds.contains(requestUserId) &&
            !requestUserIds.contains(requestUserId)) {
          requestUserIds.add(requestUserId);

          // Determine direction of request (sent or received)
          final bool isSent = _random.nextBool();

          if (isSent) {
            await commitBatchIfNeeded();

            // User sent request to another user
            final userRef = _firestore.collection('users').doc(userId);
            final requestRef = userRef.collection('friendRequests').doc();
            batch.set(requestRef, {
              'userId': requestUserId,
              'displayName':
                  userData[requestUserId]?['displayName'] ?? 'Unknown User',
              'photoURL': userData[requestUserId]?['photoURL'],
              'type': 'sent',
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });
            operationCount++;

            // Create corresponding received request for the other user
            final otherUserRef = _firestore
                .collection('users')
                .doc(requestUserId);
            final otherRequestRef =
                otherUserRef.collection('friendRequests').doc();
            batch.set(otherRequestRef, {
              'userId': userId,
              'displayName': userData[userId]?['displayName'] ?? 'Unknown User',
              'photoURL': userData[userId]?['photoURL'],
              'type': 'received',
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });
            operationCount++;
          } else {
            await commitBatchIfNeeded();

            // User received request from another user
            final userRef = _firestore.collection('users').doc(userId);
            final requestRef = userRef.collection('friendRequests').doc();
            batch.set(requestRef, {
              'userId': requestUserId,
              'displayName':
                  userData[requestUserId]?['displayName'] ?? 'Unknown User',
              'photoURL': userData[requestUserId]?['photoURL'],
              'type': 'received',
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });
            operationCount++;

            // Create corresponding sent request for the other user
            final otherUserRef = _firestore
                .collection('users')
                .doc(requestUserId);
            final otherRequestRef =
                otherUserRef.collection('friendRequests').doc();
            batch.set(otherRequestRef, {
              'userId': userId,
              'displayName': userData[userId]?['displayName'] ?? 'Unknown User',
              'photoURL': userData[userId]?['photoURL'],
              'type': 'sent',
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });
            operationCount++;
          }
        }
      }
    }
  }

  // Create group memberships and invitations
  Future<void> _createGroupMemberships(
    User currentUser,
    List<String> userIds,
    List<String> groupIds,
    Map<String, Map<String, dynamic>> userData,
    WriteBatch batch,
    Function commitBatchIfNeeded,
  ) async {
    int operationCount = 0;

    // For each group, add some members and invitations
    for (String groupId in groupIds) {
      await commitBatchIfNeeded();

      // Get all users except the creator (who is already a member as admin)
      final groupRef = _firestore.collection('groups').doc(groupId);
      final groupSnapshot = await groupRef.get();
      final String creatorId =
          groupSnapshot.data()?['creatorId'] ?? currentUser.uid;

      final List<String> potentialMemberIds =
          userIds.where((id) => id != creatorId).toList();

      // Decide how many members this group will have (4-10)
      // Increased from previous 2-5 range
      final int numberOfMembers = min(
        _random.nextInt(7) + 4,
        potentialMemberIds.length,
      );

      // Add members to the group
      final List<String> memberIds = [];
      while (memberIds.length < numberOfMembers &&
          memberIds.length < potentialMemberIds.length) {
        // Pick a random user from potential members
        final int randomIndex = _random.nextInt(potentialMemberIds.length);
        final String memberId = potentialMemberIds[randomIndex];

        if (!memberIds.contains(memberId)) {
          await commitBatchIfNeeded();

          memberIds.add(memberId);
          potentialMemberIds.removeAt(
            randomIndex,
          ); // Remove from potential members

          // Add user as member to group
          final memberRef = groupRef.collection('members').doc(memberId);
          batch.set(memberRef, {
            'displayName': userData[memberId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[memberId]?['photoURL'],
            'role':
                _random.nextInt(10) < 2
                    ? 'admin'
                    : 'member', // 20% chance of being admin
            'joinedAt': FieldValue.serverTimestamp(),
          });
          operationCount++;

          // Add group to user's groups
          final userRef = _firestore.collection('users').doc(memberId);
          final userGroupRef = userRef.collection('groups').doc(groupId);
          batch.set(userGroupRef, {
            'name': groupSnapshot.data()?['name'] ?? 'Group $groupId',
            'photoURL': groupSnapshot.data()?['photoURL'],
            'role': _random.nextInt(10) < 2 ? 'admin' : 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });
          operationCount++;
        }
      }

      // Create more pending invites for this group (3-6 invites)
      // Increased from previous 1-3 range
      if (potentialMemberIds.isNotEmpty) {
        final int numberOfInvites = min(
          _random.nextInt(4) + 3,
          potentialMemberIds.length,
        );

        for (int i = 0; i < numberOfInvites; i++) {
          await commitBatchIfNeeded();

          // Pick a random user from remaining potential members
          final int randomIndex = _random.nextInt(potentialMemberIds.length);
          final String invitedUserId = potentialMemberIds[randomIndex];
          potentialMemberIds.removeAt(randomIndex);

          // Add to group's pendingInvites subcollection
          final pendingInviteRef = groupRef
              .collection('pendingInvites')
              .doc(invitedUserId);
          batch.set(pendingInviteRef, {
            'displayName':
                userData[invitedUserId]?['displayName'] ?? 'Unknown User',
            'invitedBy': creatorId,
            'invitedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
          operationCount++;

          // Add to user's groupInvites subcollection
          final userRef = _firestore.collection('users').doc(invitedUserId);
          final userInviteRef = userRef.collection('groupInvites').doc();
          batch.set(userInviteRef, {
            'groupId': groupId,
            'groupName': groupSnapshot.data()?['name'] ?? 'Group $groupId',
            'invitedBy': creatorId,
            'inviterName':
                userData[creatorId]?['displayName'] ?? 'Unknown User',
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
          operationCount++;
        }
      }

      // Create more join requests for this group (2-4 requests)
      // Increased from previous 1-2 range
      if (potentialMemberIds.isNotEmpty) {
        final int numberOfRequests = min(
          _random.nextInt(3) + 2,
          potentialMemberIds.length,
        );

        for (int i = 0; i < numberOfRequests; i++) {
          await commitBatchIfNeeded();

          // Pick a random user from remaining potential members
          final int randomIndex = _random.nextInt(potentialMemberIds.length);
          final String requestUserId = potentialMemberIds[randomIndex];
          potentialMemberIds.removeAt(randomIndex);

          // Add to group's joinRequests subcollection
          final joinRequestRef = groupRef
              .collection('joinRequests')
              .doc(requestUserId);
          batch.set(joinRequestRef, {
            'displayName':
                userData[requestUserId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[requestUserId]?['photoURL'],
            'requestedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
            'message': 'I would like to join this group',
          });
          operationCount++;

          // Add to user's sentGroupRequests subcollection
          final userRef = _firestore.collection('users').doc(requestUserId);
          final userRequestRef = userRef
              .collection('sentGroupRequests')
              .doc(groupId);
          batch.set(userRequestRef, {
            'groupName': groupSnapshot.data()?['name'] ?? 'Group $groupId',
            'photoURL': groupSnapshot.data()?['photoURL'],
            'requestedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
            'message': 'I would like to join this group',
          });
          operationCount++;

          // Add to group admin's receivedGroupRequests subcollection
          final adminRef = _firestore.collection('users').doc(creatorId);
          final adminRequestRef =
              adminRef.collection('receivedGroupRequests').doc();
          batch.set(adminRequestRef, {
            'userId': requestUserId,
            'groupId': groupId,
            'displayName':
                userData[requestUserId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[requestUserId]?['photoURL'],
            'requestedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
            'message': 'I would like to join this group',
          });
          operationCount++;
        }
      }

      // Create channels for this group (2-5 channels)
      // Increased from previous 1-3 range
      final channelTypes = ['discussion', 'assessment', 'resource'];
      final int numberOfChannels = _random.nextInt(4) + 2;

      for (int i = 0; i < numberOfChannels; i++) {
        await commitBatchIfNeeded();

        final String channelId = 'channel_${i}_${_random.nextInt(1000)}';
        final String channelType =
            channelTypes[_random.nextInt(channelTypes.length)];

        // Create channel document
        final channelRef = groupRef.collection('channels').doc(channelId);
        batch.set(channelRef, {
          'name': 'Channel ${i + 1}',
          'description': 'Description for channel ${i + 1}',
          'type': channelType,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': creatorId,
          'instructions': 'Instructions for using this channel',
        });
        operationCount++;
      }
    }
  }

  // Share assessments with users and groups
  Future<void> _shareAssessments(
    User currentUser,
    List<String> userIds,
    List<String> groupIds,
    List<String> assessmentIds,
    Map<String, Map<String, dynamic>> userData,
    WriteBatch batch,
    Function commitBatchIfNeeded,
  ) async {
    int operationCount = 0;

    // For each assessment, share with more users and groups
    for (String assessmentId in assessmentIds) {
      await commitBatchIfNeeded();

      // Get assessment details
      final assessmentRef = _firestore
          .collection('assessments')
          .doc(assessmentId);
      final assessmentSnapshot = await assessmentRef.get();
      final String creatorId =
          assessmentSnapshot.data()?['creatorId'] ?? currentUser.uid;

      // Share with the current user
      if (creatorId != currentUser.uid) {
        final sharedUserRef = assessmentRef
            .collection('sharedWithUsers')
            .doc(currentUser.uid);
        batch.set(sharedUserRef, {
          'userName':
              userData[currentUser.uid]?['displayName'] ?? 'Current User',
          'sharedBy': creatorId,
          'sharedAt': FieldValue.serverTimestamp(),
          'startTime': FieldValue.serverTimestamp(),
          'endTime': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 14)),
          ),
          'hasTimer': _random.nextBool(),
          'timerDuration': 30, // 30 minutes
          'attemptsAllowed': _random.nextInt(3) + 1, // 1-3 attempts
        });
        operationCount++;

        // Add to current user's submittedAssessments
        final currentUserRef = _firestore
            .collection('users')
            .doc(currentUser.uid);
        final submissionId = 'submission_${_random.nextInt(10000)}';
        final submissionRef = currentUserRef
            .collection('submittedAssessments')
            .doc(submissionId);
        batch.set(submissionRef, {
          'assessmentId': assessmentId,
          'assessmentTitle':
              assessmentSnapshot.data()?['title'] ?? 'Assessment $assessmentId',
          'creatorId': creatorId,
          'creatorName': userData[creatorId]?['displayName'] ?? 'Unknown User',
          'submittedAt': FieldValue.serverTimestamp(),
          'score': _random.nextInt(100),
          'maxScore': 100,
          'status': ['completed', 'evaluated', 'reviewed'][_random.nextInt(3)],
        });
        operationCount++;
      }

      // Share with more random users (5-10 users)
      // Increased from previous 1-3 range
      final potentialUserIds =
          userIds
              .where((id) => id != creatorId && id != currentUser.uid)
              .toList();
      if (potentialUserIds.isNotEmpty) {
        final int numUsersToShare = min(
          _random.nextInt(6) + 5,
          potentialUserIds.length,
        );

        for (int i = 0; i < numUsersToShare; i++) {
          await commitBatchIfNeeded();

          final int randomIndex = _random.nextInt(potentialUserIds.length);
          final String userId = potentialUserIds[randomIndex];
          potentialUserIds.removeAt(randomIndex);

          // Share with this user
          final sharedUserRef = assessmentRef
              .collection('sharedWithUsers')
              .doc(userId);
          batch.set(sharedUserRef, {
            'userName': userData[userId]?['displayName'] ?? 'Unknown User',
            'sharedBy': creatorId,
            'sharedAt': FieldValue.serverTimestamp(),
            'startTime': FieldValue.serverTimestamp(),
            'endTime': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 14)),
            ),
            'hasTimer': _random.nextBool(),
            'timerDuration': 30, // 30 minutes
            'attemptsAllowed': _random.nextInt(3) + 1, // 1-3 attempts
          });
          operationCount++;
        }
      }

      // Share with more groups (2-4 groups)
      // Increased from previous 1-2 range
      if (groupIds.isNotEmpty) {
        final int numGroupsToShare = min(
          _random.nextInt(3) + 2,
          groupIds.length,
        );
        final List<String> sharedGroupIds = [];

        for (int i = 0; i < numGroupsToShare; i++) {
          await commitBatchIfNeeded();

          String groupId;
          do {
            groupId = groupIds[_random.nextInt(groupIds.length)];
          } while (sharedGroupIds.contains(groupId));

          sharedGroupIds.add(groupId);

          // Get group details
          final groupRef = _firestore.collection('groups').doc(groupId);
          final groupSnapshot = await groupRef.get();

          // Share with this group
          final sharedGroupRef = assessmentRef
              .collection('sharedWithGroups')
              .doc(groupId);
          batch.set(sharedGroupRef, {
            'groupName': groupSnapshot.data()?['name'] ?? 'Group $groupId',
            'sharedBy': creatorId,
            'sharedAt': FieldValue.serverTimestamp(),
            'startTime': FieldValue.serverTimestamp(),
            'endTime': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 14)),
            ),
            'hasTimer': _random.nextBool(),
            'timerDuration': 30, // 30 minutes
            'attemptsAllowed': _random.nextInt(3) + 1, // 1-3 attempts
          });
          operationCount++;
        }
      }
    }
  }

  // Generate a dummy profile image and save it locally
  Future<String?> _generateDummyProfileImage(String userId) async {
    try {
      // Create a solid color dummy image instead of asset-based
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath =
          '${tempDir.path}/temp_profile_${_random.nextInt(1000)}.png';

      // Create a dummy file with some content
      // In a real app, you'd generate a real image file
      final File tempFile = File(tempPath);
      await tempFile.writeAsString('Placeholder image content');

      // Now save this to the app's document directory using the profile image format
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory profilePicsDir = Directory(
        '${appDocDir.path}/profile_pics/$userId',
      );

      // Create the directory if it doesn't exist
      if (!await profilePicsDir.exists()) {
        await profilePicsDir.create(recursive: true);
      }

      // Generate file name
      final String fileName = 'profile.png';
      final String localPath = '${profilePicsDir.path}/$fileName';

      // Copy the file to the new location
      await tempFile.copy(localPath);

      print('Generated dummy profile image at: $localPath');
      return localPath;
    } catch (e) {
      print('Error generating dummy profile image: $e');
      return null;
    }
  }
}
