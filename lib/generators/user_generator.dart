import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/log_level.dart';
import '../models/static_data.dart';
import '../services/batch_manager.dart';
import '../utils/file_utils.dart';
import '../utils/logging_utils.dart';

/// A class dedicated to generating user data
class UserGenerator {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final LoggingUtils _logger = LoggingUtils();
  final FileUtils _fileUtils = FileUtils();
  final Random _random = Random();

  UserGenerator(this._auth, this._firestore);

  /// Generate authenticated users with proper profiles
  /// Returns a map of userId to user data (displayName, email, photoURL)
  Future<Map<String, Map<String, dynamic>>> generateUsers(
    User currentUser,
  ) async {
    final Map<String, Map<String, dynamic>> userData = {};
    final Map<String, List<String>> staticData =
        StaticData.getPreGeneratedData();

    // Add current user to our userMap first
    _logger.log(
      "Getting data for current user: ${currentUser.uid}",
      level: LogLevel.INFO,
    );
    final currentUserDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    String currentUserDisplayName = currentUser.displayName ?? 'Current User';

    if (!currentUserDoc.exists) {
      _logger.log("Creating document for current user", level: LogLevel.INFO);
      // Create user document for current user
      await _createUserDocument(currentUser.uid, {
        'displayName': currentUserDisplayName,
        'email': currentUser.email,
        'photoURL': currentUser.photoURL ?? '',
        'status': 'Active',
        'isActive': true,
        'privacyLevel': 'public',
      });
    } else {
      // Get existing display name
      currentUserDisplayName =
          currentUserDoc.data()?['displayName'] ?? currentUserDisplayName;
      _logger.log(
        "Current user document exists with name: $currentUserDisplayName",
        level: LogLevel.INFO,
      );
    }

    // Store current user data
    userData[currentUser.uid] = {
      'displayName': currentUserDisplayName,
      'email': currentUser.email,
      'photoURL': currentUser.photoURL,
    };

    _logger.log("Current user added to userData map", level: LogLevel.DEBUG);

    // Get static data
    final List<String> firstNames = staticData['firstNames']!;
    final List<String> lastNames = staticData['lastNames']!;
    final List<String> statusOptions = staticData['statusOptions']!;
    final List<String> bioTemplates = staticData['bioTemplates']!;

    // Password for test users
    const String testPassword = 'Test123!';

    // Create NUM_USERS authenticated users
    _logger.log(
      "Creating ${StaticData.NUM_USERS} authenticated users",
      level: LogLevel.INFO,
    );

    int createdUsers = 0;
    int failedAttempts = 0;
    final int maxFailedAttempts = StaticData.NUM_USERS * 2;

    // Batch for user documents
    final BatchManager batchManager = BatchManager(_firestore, verbose: true);

    // Create all users with parallel generation of profile images
    final List<Future<void>> userCreationTasks = [];

    while (createdUsers < StaticData.NUM_USERS &&
        failedAttempts < maxFailedAttempts) {
      try {
        // Generate user info
        final String firstName = firstNames[_random.nextInt(firstNames.length)];
        final String lastName = lastNames[_random.nextInt(lastNames.length)];
        final String displayName = '$firstName $lastName';

        // Add unique timestamp identifier to email to ensure uniqueness
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final String email =
            '${firstName.toLowerCase()}.${lastName.toLowerCase()}.$timestamp@${StaticData.TEST_EMAIL_DOMAIN}';

        _logger.log("Attempting to create user: $email", level: LogLevel.DEBUG);

        // Create Firebase Auth user - this must be done sequentially
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: email,
              password: testPassword,
            );

        final User user = userCredential.user!;
        final String userId = user.uid;
        _logger.log(
          "Created auth user with ID: $userId",
          level: LogLevel.DEBUG,
        );

        // Update profile in parallel
        userCreationTasks.add(user.updateProfile(displayName: displayName));

        // Generate profile image in parallel
        final Future<String?> photoURLFuture = _fileUtils
            .generateDummyProfileImage(userId);

        // Generate bio
        final String bio = _generateBio(bioTemplates, staticData['interests']!);

        // Add task to wait for photo generation and create Firestore document
        userCreationTasks.add(
          photoURLFuture.then((photoURL) async {
            final userRef = _firestore.collection('users').doc(userId);
            await batchManager.set(userRef, {
              'displayName': displayName,
              'email': email,
              'photoURL': photoURL ?? '',
              'status': statusOptions[_random.nextInt(statusOptions.length)],
              'bio': bio,
              'isActive': false,
              'privacyLevel':
                  ['public', 'friends-only', 'private'][_random.nextInt(3)],
              'createdAt': FieldValue.serverTimestamp(),
              'favTags': [],
              'settings': {
                'notificationsEnabled': _random.nextBool(),
                'theme': ['light', 'dark', 'system'][_random.nextInt(3)],
              },
            });

            // Add to userData map
            userData[userId] = {
              'displayName': displayName,
              'email': email,
              'photoURL': photoURL,
            };

            _logger.log(
              "Added user data for: $displayName ($userId)",
              level: LogLevel.DEBUG,
            );
          }),
        );

        createdUsers++;
        _logger.log(
          "Initiated creation of user $createdUsers of ${StaticData.NUM_USERS}: $displayName ($userId)",
          level: LogLevel.INFO,
        );
      } catch (e) {
        failedAttempts++;
        _logger.log(
          "ERROR creating user: $e (Attempt $failedAttempts of $maxFailedAttempts)",
          level: LogLevel.ERROR,
        );

        // If we hit a rate limit, wait a bit
        if (e.toString().contains('too-many-requests')) {
          _logger.log(
            "Rate limit detected, waiting 30 seconds before retrying",
            level: LogLevel.WARNING,
          );
          await Future.delayed(Duration(seconds: 30));
        }
      }
    }

    // Wait for all user creation tasks to complete
    _logger.log(
      "Waiting for ${userCreationTasks.length} user tasks to complete",
      level: LogLevel.INFO,
    );
    await Future.wait(userCreationTasks);

    // Commit the batch for user documents
    await batchManager.commit();

    _logger.log(
      "Completed user generation with ${userData.length} users",
      level: LogLevel.INFO,
    );
    if (createdUsers < StaticData.NUM_USERS) {
      _logger.log(
        "WARNING: Only created $createdUsers of ${StaticData.NUM_USERS} requested users",
        level: LogLevel.WARNING,
      );
    }

    return userData;
  }

  /// Create user goals
  Future<void> createUserGoals(
    List<String> userIds,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting creating user goals", level: LogLevel.INFO);

    // Goal description templates
    final List<String> goalDescriptions = StaticData.getGoalDescriptions();
    int totalGoalsCreated = 0;

    for (String userId in userIds) {
      // Every user gets at least 1 goal, up to 3 goals (1-3)
      final int numGoals = _random.nextInt(3) + 1;
      _logger.log(
        "Creating $numGoals goals for user $userId",
        level: LogLevel.DEBUG,
      );

      for (int i = 0; i < numGoals; i++) {
        final String goalId = 'goal_${userId}_${_random.nextInt(10000)}_$i';

        final userGoalRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('goals')
            .doc(goalId);

        // Generate random progress values
        final int lessonsLearnt = _random.nextInt(20);
        final int assessmentsCompleted = _random.nextInt(10);
        final int assessmentsCreated = _random.nextInt(5);

        // Set target date between 1-6 months from now
        final targetDate = DateTime.now().add(
          Duration(days: _random.nextInt(180) + 30),
        );

        await batchManager.set(userGoalRef, {
          'lessonsLearnt': lessonsLearnt,
          'assessmentsCompleted': assessmentsCompleted,
          'assessmentsCreated': assessmentsCreated,
          'targetDate': Timestamp.fromDate(targetDate),
          'description':
              goalDescriptions[_random.nextInt(goalDescriptions.length)],
          'isCompleted':
              _random.nextDouble() < 0.3, // 30% chance of being completed
          'createdAt': FieldValue.serverTimestamp(),
        });

        totalGoalsCreated++;
      }
    }

    _logger.log(
      "Created $totalGoalsCreated goals for ${userIds.length} users",
      level: LogLevel.INFO,
    );
  }

  /// Create a user document in Firestore
  Future<void> _createUserDocument(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final userRef = _firestore.collection('users').doc(userId);

    // Add default fields
    final Map<String, dynamic> userDoc = {
      ...userData,
      'createdAt': FieldValue.serverTimestamp(),
      'favTags': [],
      'settings': {
        'notificationsEnabled': _random.nextBool(),
        'theme': ['light', 'dark', 'system'][_random.nextInt(3)],
      },
    };

    await userRef.set(userDoc);
    _logger.log(
      "Created Firestore document for user $userId",
      level: LogLevel.DEBUG,
    );
  }

  /// Generate a random bio
  String _generateBio(List<String> bioTemplates, List<String> interests) {
    final bioTemplate = bioTemplates[_random.nextInt(bioTemplates.length)];

    final interest1 = interests[_random.nextInt(interests.length)];
    String interest2;
    do {
      interest2 = interests[_random.nextInt(interests.length)];
    } while (interest2 == interest1);

    return bioTemplate
        .replaceFirst('%s', interest1)
        .replaceFirst('%s', interest2);
  }
}
