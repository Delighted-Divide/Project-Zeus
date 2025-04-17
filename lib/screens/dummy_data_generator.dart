import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:attempt1/models/static_data.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'package:flutter/services.dart';

class Logger {
  final bool _verbose;
  final StringBuffer _logBuffer = StringBuffer();
  int _logLines = 0;
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  static const int LOG_BUFFER_FLUSH_THRESHOLD = 50;

  final Map<String, String> _logLevelColors = {
    'DEBUG': '\x1B[37m',
    'INFO': '\x1B[34m',
    'WARNING': '\x1B[33m',
    'ERROR': '\x1B[31m',
    'SUCCESS': '\x1B[32m',
  };

  static const String _resetColor = '\x1B[0m';

  Logger({bool verbose = true}) : _verbose = verbose;

  void log(String message, {String level = 'DEBUG'}) {
    if (level == 'DEBUG' && !_verbose) return;

    final timestamp = _dateFormatter.format(DateTime.now());

    final String formattedMessage = '$timestamp [$level] $message';

    final String colorCode = _logLevelColors[level] ?? '';
    print('$colorCode$formattedMessage$_resetColor');

    _logBuffer.writeln(formattedMessage);
    _logLines++;

    if (_verbose && _logLines >= LOG_BUFFER_FLUSH_THRESHOLD) {
      saveLogsToFile();
      _logLines = 0;
    }
  }

  Future<void> saveLogsToFile() async {
    try {
      if (_logBuffer.isEmpty) return;

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory logsDir = Directory('${appDocDir.path}/dummy_data_logs');

      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final String fileName =
          'dummy_data_gen_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.log';
      final File logFile = File('${logsDir.path}/$fileName');

      await logFile.writeAsString(_logBuffer.toString(), mode: FileMode.append);
      _logBuffer.clear();

      print('Logs saved to ${logFile.path}');
    } catch (e) {
      print('Error saving logs: $e');
    }
  }
}

class BatchManager {
  final FirebaseFirestore _firestore;
  WriteBatch _currentBatch;
  int _operationCount = 0;
  final int _maxBatchSize;
  final bool _verbose;
  final Logger _logger;

  int _totalOperations = 0;
  int _totalCommits = 0;
  Stopwatch _batchStopwatch = Stopwatch()..start();

  BatchManager(
    this._firestore,
    this._logger, {
    int maxBatchSize = 450,
    bool verbose = false,
  }) : _maxBatchSize = maxBatchSize,
       _verbose = verbose,
       _currentBatch = _firestore.batch();

  int get operationCount => _operationCount;
  int get totalOperations => _totalOperations;
  int get totalCommits => _totalCommits;

  Future<void> set(DocumentReference docRef, Map<String, dynamic> data) async {
    await _checkBatchSize();
    _currentBatch.set(docRef, data);
    _operationCount++;
    _totalOperations++;
  }

  Future<void> setWithOptions(
    DocumentReference docRef,
    Map<String, dynamic> data,
    SetOptions options,
  ) async {
    await _checkBatchSize();
    _currentBatch.set(docRef, data, options);
    _operationCount++;
    _totalOperations++;
  }

  Future<void> update(
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) async {
    await _checkBatchSize();
    _currentBatch.update(docRef, data);
    _operationCount++;
    _totalOperations++;
  }

  Future<void> delete(DocumentReference docRef) async {
    await _checkBatchSize();
    _currentBatch.delete(docRef);
    _operationCount++;
    _totalOperations++;
  }

  Future<void> _checkBatchSize() async {
    if (_operationCount >= _maxBatchSize) {
      await commitBatch();
    }
  }

  Future<void> commitBatch() async {
    if (_operationCount > 0) {
      if (_verbose) {
        _logger.log(
          'Committing batch with $_operationCount operations',
          level: 'INFO',
        );
      }

      final stopwatch = Stopwatch()..start();
      await _currentBatch.commit();
      final elapsed = stopwatch.elapsedMilliseconds;

      _totalCommits++;
      if (_verbose) {
        _logger.log('Batch committed in ${elapsed}ms', level: 'INFO');
      }

      _currentBatch = _firestore.batch();
      _operationCount = 0;
    }
  }

  Future<void> commit() async {
    await commitBatch();
    final totalTime = _batchStopwatch.elapsedMilliseconds;

    if (_verbose) {
      _logger.log('BatchManager stats:', level: 'INFO');
      _logger.log('- Total operations: $_totalOperations', level: 'INFO');
      _logger.log('- Total commits: $_totalCommits', level: 'INFO');
      _logger.log('- Total time: ${totalTime}ms', level: 'INFO');
      _logger.log(
        '- Avg operations per second: ${(_totalOperations * 1000 / totalTime).toStringAsFixed(1)}',
        level: 'INFO',
      );
    }
  }
}

class DummyDataGenerator {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BuildContext context;
  final Random _random = Random();

  static const int NUM_USERS = 30;
  static const int MIN_FRIENDS = 3;
  static const int MAX_FRIENDS = 10;
  static const int MIN_FRIEND_REQUESTS = 3;
  static const int MAX_FRIEND_REQUESTS = 8;
  static const int NUM_GROUPS = 10;
  static const int MIN_GROUP_MEMBERS = 8;
  static const int MAX_GROUP_MEMBERS = 20;
  static const int NUM_ASSESSMENTS = 30;
  static const int MIN_SHARED_USERS = 4;
  static const int MIN_SHARED_GROUPS = 3;

  static const String TEST_EMAIL_DOMAIN = "example.com";

  final bool _verbose;
  final Logger _logger;
  Stopwatch _totalStopwatch = Stopwatch();
  final Map<String, Stopwatch> _stepTimers = {};

  DummyDataGenerator(this.context, {bool verbose = true})
    : _verbose = verbose,
      _logger = Logger(verbose: verbose);

  Future<void> generateAllDummyData() async {
    _totalStopwatch.start();
    _startStepTimer('total');
    try {
      _logger.log(
        "====== STARTING DUMMY DATA GENERATION PROCESS ======",
        level: "INFO",
      );

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('No user signed in. Please sign in first.', Colors.red);
        _logger.log("Error: No user signed in", level: "ERROR");
        return;
      }

      _logger.log(
        "Current user: ${currentUser.uid} (${currentUser.email})",
        level: "INFO",
      );

      final String originalUid = currentUser.uid;

      _showSnackBar('Starting to generate dummy data...', Colors.blue);

      final batchManager = BatchManager(_firestore, _logger, verbose: _verbose);

      _logger.log("Pre-generating static reference data", level: "INFO");
      final Map<String, List<String>> staticData = _preGenerateStaticData();

      await _executeDataGenerationSteps(currentUser, batchManager, staticData);

      _logGenerationSummary();

      _showSnackBar(
        'Dummy data generation completed successfully!',
        Colors.green,
      );
      _logger.log(
        "====== DUMMY DATA GENERATION COMPLETED SUCCESSFULLY ======",
        level: "SUCCESS",
      );
    } catch (e, stackTrace) {
      _logger.log("ERROR generating dummy data: $e", level: "ERROR");
      _logger.log("Stack trace: $stackTrace", level: "ERROR");
      _showSnackBar('Error generating dummy data: $e', Colors.red);
    } finally {
      _stopStepTimer('total');
      _totalStopwatch.stop();
      if (_verbose) {
        await _logger.saveLogsToFile();
      }
    }
  }

  Map<String, List<String>> _preGenerateStaticData() {
    final Map<String, List<String>> data = {};

    data['firstNames'] = [
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
      'Charlie',
      'Addison',
      'Sage',
      'Jean',
      'Ariel',
      'Robin',
    ];

    data['lastNames'] = [
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
      'Sanchez',
    ];

    data['statusOptions'] = [
      'Learning new concepts',
      'Preparing for exam',
      'Looking for study group',
      'Taking a break',
      'Open to tutoring',
      'Need help with homework',
      'Researching',
      'Working on project',
      'Available for discussion',
      'Focusing on studies',
    ];

    data['bioTemplates'] = [
      'Student interested in %s and %s.',
      'Passionate about learning %s. Also enjoys %s in free time.',
      'Studying %s with focus on %s applications.',
      'Exploring the world of %s. Fascinated by %s.',
      '%s enthusiast with background in %s.',
      'Curious mind delving into %s and %s.',
      'Dedicated to mastering %s. Side interest in %s.',
      'Academic focus: %s. Personal interest: %s.',
      'Researcher in %s with practical experience in %s.',
      'Lifelong learner with special interest in %s and %s.',
    ];

    data['interests'] = [
      'mathematics',
      'physics',
      'chemistry',
      'biology',
      'history',
      'literature',
      'art',
      'music',
      'programming',
      'economics',
      'psychology',
      'philosophy',
      'linguistics',
      'engineering',
      'architecture',
      'medicine',
      'law',
      'business',
      'sociology',
    ];

    return data;
  }

  Future<void> _executeDataGenerationSteps(
    User currentUser,
    BatchManager batchManager,
    Map<String, List<String>> staticData,
  ) async {
    _startStepTimer('generateTags');
    _logger.log("STEP 1: Generating tags", level: "INFO");
    final tagIds = await _generateTags(batchManager);
    await batchManager.commit();
    _stopStepTimer('generateTags');
    _logger.log(
      "Tags generated and committed: ${tagIds.length} tags",
      level: "SUCCESS",
    );

    _startStepTimer('generateUsers');
    _logger.log("STEP 2: Generating users", level: "INFO");
    final userData = await _generateUsers(currentUser, staticData);
    final userIds = userData.keys.toList();
    _stopStepTimer('generateUsers');
    _logger.log("Users generated: ${userIds.length} users", level: "SUCCESS");

    _startStepTimer('assignTags');
    _logger.log("STEP 3: Assigning favorite tags", level: "INFO");
    await _assignFavoriteTags(userIds, tagIds, batchManager);
    await batchManager.commit();
    _stopStepTimer('assignTags');
    _logger.log("Favorite tags assigned and committed", level: "SUCCESS");

    _startStepTimer('createGoals');
    _logger.log("STEP 4: Creating user goals", level: "INFO");
    await _createUserGoals(userIds, batchManager);
    await batchManager.commit();
    _stopStepTimer('createGoals');
    _logger.log("User goals created and committed", level: "SUCCESS");

    _startStepTimer('createFriendships');
    _logger.log("STEP 5: Creating friendships", level: "INFO");
    await _createFriendships(userIds, userData, batchManager);
    await batchManager.commit();
    _stopStepTimer('createFriendships');
    _logger.log("Friendships created and committed", level: "SUCCESS");

    _startStepTimer('generateGroups');
    _logger.log("STEP 6: Generating groups", level: "INFO");
    final groupIds = await _generateGroups(
      userIds,
      tagIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('generateGroups');
    _logger.log(
      "Groups generated and committed: ${groupIds.length} groups",
      level: "SUCCESS",
    );

    _startStepTimer('createMemberships');
    _logger.log("STEP 7: Creating group memberships", level: "INFO");
    await _createGroupMemberships(userIds, groupIds, userData, batchManager);
    await batchManager.commit();
    _stopStepTimer('createMemberships');
    _logger.log("Group memberships created and committed", level: "SUCCESS");

    _startStepTimer('generateAssessments');
    _logger.log("STEP 8: Generating assessments", level: "INFO");
    final assessmentIds = await _generateAssessments(
      userIds,
      tagIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('generateAssessments');
    _logger.log(
      "Assessments generated and committed: ${assessmentIds.length} assessments",
      level: "SUCCESS",
    );

    _startStepTimer('shareAssessments');
    _logger.log("STEP 9: Sharing assessments", level: "INFO");
    await _shareAssessments(
      userIds,
      groupIds,
      assessmentIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('shareAssessments');
    _logger.log("Assessment sharing completed and committed", level: "SUCCESS");

    _startStepTimer('generateSubmissions');
    _logger.log("STEP 10: Generating submissions", level: "INFO");
    await _generateSubmissions(
      userIds,
      groupIds,
      assessmentIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('generateSubmissions');
    _logger.log("Submissions generated and committed", level: "SUCCESS");
  }

  Future<List<String>> _generateTags(BatchManager batchManager) async {
    final List<String> tagIds = [];
    _logger.log("Starting tag generation", level: "INFO");

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
      {
        'name': 'Art',
        'category': 'Subject',
        'description': 'Visual and performing arts studies',
      },
      {
        'name': 'Economics',
        'category': 'Subject',
        'description':
            'Study of production, distribution, and consumption of goods and services',
      },
    ];

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
      {
        'name': 'Neural Networks',
        'category': 'Topic',
        'description':
            'Computing systems inspired by biological neural networks',
      },
      {
        'name': 'Renaissance Art',
        'category': 'Topic',
        'description': 'European artistic movement from 14th to 17th century',
      },
    ];

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
      {
        'name': 'Team Collaboration',
        'category': 'Skill',
        'description': 'Working effectively with others to achieve goals',
      },
      {
        'name': 'Time Management',
        'category': 'Skill',
        'description': 'Planning and controlling time to increase efficiency',
      },
    ];

    final List<Map<String, String>> allTags = [
      ...subjectTags,
      ...topicTags,
      ...skillTags,
    ];

    for (var tag in allTags) {
      final String tagName = tag['name'] ?? '';
      if (tagName.isEmpty) {
        _logger.log("WARNING: Skipping tag with empty name", level: "WARNING");
        continue;
      }

      final String tagId = 'tag_${tagName.toLowerCase().replaceAll(' ', '_')}';
      tagIds.add(tagId);

      _logger.log(
        "Creating tag: $tagId - ${tag['name']} (${tag['category']})",
        level: "DEBUG",
      );

      final tagRef = _firestore.collection('tags').doc(tagId);
      await batchManager.set(tagRef, {
        'name': tag['name'],
        'category': tag['category'],
        'description': tag['description'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _logger.log("Created ${tagIds.length} tags", level: "INFO");
    return tagIds;
  }

  Future<Map<String, Map<String, dynamic>>> _generateUsers(
    User currentUser,
    Map<String, List<String>> staticData,
  ) async {
    final Map<String, Map<String, dynamic>> userData = {};

    _logger.log(
      "Getting data for current user: ${currentUser.uid}",
      level: "INFO",
    );
    final currentUserDoc =
        await _firestore.collection('users').doc(currentUser.uid).get();
    String currentUserDisplayName = currentUser.displayName ?? 'Current User';

    if (!currentUserDoc.exists) {
      _logger.log("Creating document for current user", level: "INFO");
      await _createUserDocument(currentUser.uid, {
        'displayName': currentUserDisplayName,
        'email': currentUser.email,
        'photoURL': currentUser.photoURL ?? '',
        'status': 'Active',
        'isActive': true,
        'privacyLevel': 'public',
      });
    } else {
      currentUserDisplayName =
          currentUserDoc.data()?['displayName'] ?? currentUserDisplayName;
      _logger.log(
        "Current user document exists with name: $currentUserDisplayName",
        level: "INFO",
      );
    }

    userData[currentUser.uid] = {
      'displayName': currentUserDisplayName,
      'email': currentUser.email,
      'photoURL': currentUser.photoURL,
    };

    _logger.log("Current user added to userData map", level: "DEBUG");

    final List<String> firstNames = staticData['firstNames']!;
    final List<String> lastNames = staticData['lastNames']!;
    final List<String> statusOptions = staticData['statusOptions']!;
    final List<String> bioTemplates = staticData['bioTemplates']!;

    const String testPassword = 'Test123!';

    _logger.log("Creating $NUM_USERS authenticated users", level: "INFO");

    int createdUsers = 0;
    int failedAttempts = 0;
    final int maxFailedAttempts = NUM_USERS * 2;

    final BatchManager batchManager = BatchManager(
      _firestore,
      _logger,
      verbose: _verbose,
    );

    try {
      final List<String> availableProfilePics = await _listAssetProfilePics();
      _logger.log(
        "Found ${availableProfilePics.length} profile images in assets folder",
        level: "INFO",
      );

      if (availableProfilePics.isEmpty) {
        _logger.log(
          "No profile images found in assets folder",
          level: "WARNING",
        );
      }

      final List<Future<void>> userCreationTasks = [];

      while (createdUsers < NUM_USERS && failedAttempts < maxFailedAttempts) {
        try {
          final String firstName =
              firstNames[_random.nextInt(firstNames.length)];
          final String lastName = lastNames[_random.nextInt(lastNames.length)];
          final String displayName = '$firstName $lastName';

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final String email =
              '${firstName.toLowerCase()}.${lastName.toLowerCase()}.$timestamp@${TEST_EMAIL_DOMAIN}';

          _logger.log("Attempting to create user: $email", level: "DEBUG");

          final UserCredential userCredential = await _auth
              .createUserWithEmailAndPassword(
                email: email,
                password: testPassword,
              );

          final User user = userCredential.user!;
          final String userId = user.uid;
          _logger.log("Created auth user with ID: $userId", level: "DEBUG");

          userCreationTasks.add(user.updateProfile(displayName: displayName));

          String? photoURL;
          if (availableProfilePics.isNotEmpty) {
            final String profileImage =
                availableProfilePics[_random.nextInt(
                  availableProfilePics.length,
                )];
            photoURL = await _uploadProfileImageToStorage(userId, profileImage);
          }

          final String bio = _generateBio(
            bioTemplates,
            staticData['interests']!,
          );

          userCreationTasks.add(() async {
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

            userData[userId] = {
              'displayName': displayName,
              'email': email,
              'photoURL': photoURL,
            };

            _logger.log(
              "Added user data for: $displayName ($userId)",
              level: "DEBUG",
            );
          }());

          createdUsers++;
          _logger.log(
            "Initiated creation of user $createdUsers of $NUM_USERS: $displayName ($userId)",
            level: "INFO",
          );
        } catch (e) {
          failedAttempts++;
          _logger.log(
            "ERROR creating user: $e (Attempt $failedAttempts of $maxFailedAttempts)",
            level: "ERROR",
          );

          if (e.toString().contains('too-many-requests')) {
            _logger.log(
              "Rate limit detected, waiting 30 seconds before retrying",
              level: "WARNING",
            );
            await Future.delayed(Duration(seconds: 30));
          }
        }
      }

      _logger.log(
        "Waiting for ${userCreationTasks.length} user tasks to complete",
        level: "INFO",
      );
      await Future.wait(userCreationTasks);

      await batchManager.commit();

      _logger.log(
        "Completed user generation with ${userData.length} users",
        level: "INFO",
      );
      if (createdUsers < NUM_USERS) {
        _logger.log(
          "WARNING: Only created $createdUsers of $NUM_USERS requested users",
          level: "WARNING",
        );
      }
    } catch (e) {
      _logger.log("Error during user generation: $e", level: "ERROR");
    }

    return userData;
  }

  Future<List<String>> _listAssetProfilePics() async {
    try {
      return [
        'assets/profile_pics/703ac7d86b7096a375f0fbae22924ead.jpg',
        'assets/profile_pics/820df70027be9050db115184161218f4.jpg',
        'assets/profile_pics/673e03c23d70d17d58fc69dd6fa64b69.jpg',
        'assets/profile_pics/817c2ca163aa3fc69628c907a71ea1fb.jpg',
        'assets/profile_pics/703c19efd02ee452925c1ca0a3ff46d67.jpg',
        'assets/profile_pics/803df0f77df7bd2f1f39a6492cda12ab.jpg',
        'assets/profile_pics/827a99adc547ba0a7ab372c544bc2aae.jpg',
        'assets/profile_pics/781da40a3c392c9ff036325756e78fd.jpg',
        'assets/profile_pics/00716 (736x736).png',
        'assets/profile_pics/00722 (1129x1132).png',
        'assets/profile_pics/00757 (920x1624).jpg',
        'assets/profile_pics/00825 (567x1017).jpg',
        'assets/profile_pics/00767 (1618x1560).jpg',
        'assets/profile_pics/00771 (481x680).jpg',
        'assets/profile_pics/00779 (481x680).jpg',
        'assets/profile_pics/00783 (1450x2048).jpg',
        'assets/profile_pics/00791 (736x971).jpg',
        'assets/profile_pics/00795 (1000x1415).jpg',
        'assets/profile_pics/00799 (736x736).jpg',
        'assets/profile_pics/00805 (1364x2048).jpg',
        'assets/profile_pics/00811 (1080x1511).jpg',
        'assets/profile_pics/00691 (1255x1606).jpg',
        'assets/profile_pics/00699 (1000x1346).jpg',
        'assets/profile_pics/00643 (1080x1642).jpg',
        'assets/profile_pics/00647 (674x900).jpg',
        'assets/profile_pics/00651 (720x720).jpg',
        'assets/profile_pics/00657 (360x360).jpg',
        'assets/profile_pics/00663 (956x1200).jpg',
        'assets/profile_pics/00671 (1191x1684).jpg',
        'assets/profile_pics/00677 (1843x2048).jpg',
        'assets/profile_pics/00681 (736x981).jpg',
        'assets/profile_pics/00685 (340x661).jpg',
        'assets/profile_pics/00703 (675x1200).jpg',
        'assets/profile_pics/00707 (749x1024).jpg',
        'assets/profile_pics/00711 (576x827).jpg',
        'assets/profile_pics/00721 (664x750).jpg',
        'assets/profile_pics/00727 (888x894).jpg',
        'assets/profile_pics/00731 (612x792).jpg',
        'assets/profile_pics/00735 (1082x749).jpg',
      ];
    } catch (e) {
      _logger.log("Error listing asset profile pics: $e", level: "ERROR");

      return [];
    }
  }

  Future<String?> _uploadProfileImageToStorage(
    String userId,
    String assetPath,
  ) async {
    try {
      final Reference storageRef = _storage.ref().child(
        'profile_images/$userId.png',
      );

      ByteData data = await rootBundle.load(assetPath);
      List<int> bytes = data.buffer.asUint8List();

      final UploadTask uploadTask = storageRef.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'image/png'),
      );

      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      _logger.log(
        "Uploaded profile image for user $userId to Firebase Storage",
        level: "DEBUG",
      );

      return downloadUrl;
    } catch (e) {
      _logger.log(
        "Error uploading profile image to storage: $e",
        level: "ERROR",
      );
      return null;
    }
  }

  Future<void> _createUserDocument(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final userRef = _firestore.collection('users').doc(userId);

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
    _logger.log("Created Firestore document for user $userId", level: "DEBUG");
  }

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

  Future<void> _assignFavoriteTags(
    List<String> userIds,
    List<String> tagIds,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting assigning favorite tags to users", level: "INFO");

    for (String userId in userIds) {
      final int numFavTags = _random.nextInt(5) + 2;
      _logger.log(
        "Assigning $numFavTags favorite tags to user $userId",
        level: "DEBUG",
      );

      final List<String> userFavTags = [];

      final List<String> availableTags = List.from(tagIds);
      availableTags.shuffle(_random);

      userFavTags.addAll(availableTags.take(numFavTags));

      final userRef = _firestore.collection('users').doc(userId);
      await batchManager.update(userRef, {'favTags': userFavTags});

      _logger.log(
        "Added ${userFavTags.length} tags to user $userId",
        level: "DEBUG",
      );
    }

    _logger.log("Completed assigning favorite tags", level: "INFO");
  }

  Future<void> _createUserGoals(
    List<String> userIds,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting creating user goals", level: "INFO");

    final List<String> goalDescriptions = [
      'Complete 10 assessments in mathematics',
      'Master the fundamentals of organic chemistry',
      'Improve problem-solving skills in physics',
      'Create 5 programming projects',
      'Read and analyze 3 classic literature works',
      'Develop proficiency in data analysis',
      'Understand advanced calculus concepts',
      'Complete a research project in biology',
      'Learn the basics of machine learning',
      'Improve essay writing skills',
      'Pass the final exam with distinction',
      'Complete all assignments before deadline',
      'Develop better note-taking techniques',
      'Join a study group for collaborative learning',
      'Improve presentation skills',
    ];

    int totalGoalsCreated = 0;

    for (String userId in userIds) {
      final int numGoals = _random.nextInt(3) + 1;
      _logger.log("Creating $numGoals goals for user $userId", level: "DEBUG");

      for (int i = 0; i < numGoals; i++) {
        final String goalId = 'goal_${userId}_${_random.nextInt(10000)}_$i';

        final userGoalRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('goals')
            .doc(goalId);

        final int lessonsLearnt = _random.nextInt(20);
        final int assessmentsCompleted = _random.nextInt(10);
        final int assessmentsCreated = _random.nextInt(5);

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
          'isCompleted': _random.nextDouble() < 0.3,
          'createdAt': FieldValue.serverTimestamp(),
        });

        totalGoalsCreated++;
      }
    }

    _logger.log(
      "Created $totalGoalsCreated goals for ${userIds.length} users",
      level: "INFO",
    );
  }

  Future<void> _createFriendships(
    List<String> userIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting creating friend relationships", level: "INFO");
    int friendshipsCreated = 0;
    int requestsCreated = 0;

    for (String userId in userIds) {
      final int numberOfFriends =
          _random.nextInt(MAX_FRIENDS - MIN_FRIENDS + 1) + MIN_FRIENDS;
      _logger.log(
        "Creating $numberOfFriends friendships for user $userId",
        level: "DEBUG",
      );

      final List<String> friendIds = [];
      final List<String> potentialFriends = List.from(userIds)..remove(userId);
      potentialFriends.shuffle(_random);

      final selectedFriends = potentialFriends.take(numberOfFriends).toList();

      for (final String friendId in selectedFriends) {
        friendIds.add(friendId);
        _logger.log(
          "Adding friendship between $userId and $friendId",
          level: "DEBUG",
        );

        String userDisplayName =
            userData[userId]?['displayName'] ?? 'Unknown User';
        String friendDisplayName =
            userData[friendId]?['displayName'] ?? 'Unknown User';

        final userFriendDoc = _firestore
            .collection('users')
            .doc(userId)
            .collection('friends')
            .doc(friendId);

        await batchManager.set(userFriendDoc, {
          'displayName': friendDisplayName,
          'photoURL': userData[friendId]?['photoURL'],
          'becameFriendsAt': FieldValue.serverTimestamp(),
        });

        final friendUserDoc = _firestore
            .collection('users')
            .doc(friendId)
            .collection('friends')
            .doc(userId);

        await batchManager.set(friendUserDoc, {
          'displayName': userDisplayName,
          'photoURL': userData[userId]?['photoURL'],
          'becameFriendsAt': FieldValue.serverTimestamp(),
        });

        friendshipsCreated++;
      }

      final int numberOfRequests =
          _random.nextInt(MAX_FRIEND_REQUESTS - MIN_FRIEND_REQUESTS + 1) +
          MIN_FRIEND_REQUESTS;
      _logger.log(
        "Creating $numberOfRequests friend requests for user $userId",
        level: "DEBUG",
      );

      final List<String> remainingUsers =
          potentialFriends.where((id) => !friendIds.contains(id)).toList();
      remainingUsers.shuffle(_random);

      final requestUsers = remainingUsers.take(numberOfRequests).toList();

      for (final String requestUserId in requestUsers) {
        _logger.log(
          "Creating friend request between $userId and $requestUserId",
          level: "DEBUG",
        );

        final bool isSent = _random.nextBool();

        if (isSent) {
          final userRef = _firestore.collection('users').doc(userId);
          final String sentRequestId =
              'sent_${userId}_${requestUserId}_${_random.nextInt(10000)}';
          final requestRef = userRef
              .collection('friendRequests')
              .doc(sentRequestId);

          await batchManager.set(requestRef, {
            'userId': requestUserId,
            'displayName':
                userData[requestUserId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[requestUserId]?['photoURL'],
            'type': 'sent',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

          final otherUserRef = _firestore
              .collection('users')
              .doc(requestUserId);
          final String receivedRequestId =
              'received_${requestUserId}_${userId}_${_random.nextInt(10000)}';
          final otherRequestRef = otherUserRef
              .collection('friendRequests')
              .doc(receivedRequestId);

          await batchManager.set(otherRequestRef, {
            'userId': userId,
            'displayName': userData[userId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[userId]?['photoURL'],
            'type': 'received',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          final userRef = _firestore.collection('users').doc(userId);
          final String receivedRequestId =
              'received_${userId}_${requestUserId}_${_random.nextInt(10000)}';
          final requestRef = userRef
              .collection('friendRequests')
              .doc(receivedRequestId);

          await batchManager.set(requestRef, {
            'userId': requestUserId,
            'displayName':
                userData[requestUserId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[requestUserId]?['photoURL'],
            'type': 'received',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

          final otherUserRef = _firestore
              .collection('users')
              .doc(requestUserId);
          final String sentRequestId =
              'sent_${requestUserId}_${userId}_${_random.nextInt(10000)}';
          final otherRequestRef = otherUserRef
              .collection('friendRequests')
              .doc(sentRequestId);

          await batchManager.set(otherRequestRef, {
            'userId': userId,
            'displayName': userData[userId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[userId]?['photoURL'],
            'type': 'sent',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        requestsCreated += 2;
      }
    }

    _logger.log(
      "Completed creating friend relationships: $friendshipsCreated friendships and $requestsCreated requests",
      level: "INFO",
    );
  }

  Future<List<String>> _generateGroups(
    List<String> userIds,
    List<String> tagIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting group generation", level: "INFO");

    final List<String> groupIds = [];

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
      {
        'name': 'Calculus Masters',
        'description':
            'Advanced calculus study group for serious math students',
      },
      {
        'name': 'Programming Workshop',
        'description': 'Hands-on coding sessions for all skill levels',
      },
      {
        'name': 'Organic Chemistry Lab',
        'description': 'Focus on organic chemistry laboratory techniques',
      },
      {
        'name': 'Data Science Explorers',
        'description':
            'Group exploring statistics and data science applications',
      },
      {
        'name': 'Physics Theory Group',
        'description':
            'Discussion of theoretical physics concepts and applications',
      },
    ];

    final Map<String, Future<String?>> groupImageFutures = {};

    for (int i = 0; i < min(NUM_GROUPS, groupData.length); i++) {
      final String groupName = groupData[i]['name'] ?? '';
      if (groupName.isEmpty) continue;

      final String groupId =
          'group_${groupName.toLowerCase().replaceAll(' ', '_')}_${_random.nextInt(1000)}';
      groupImageFutures[groupId] = _uploadGroupImageToStorage(groupId);
    }

    _logger.log(
      "Pre-generating ${groupImageFutures.length} group profile images",
      level: "INFO",
    );

    final Map<String, String?> groupImages = {};
    await Future.wait(
      groupImageFutures.entries.map((entry) async {
        groupImages[entry.key] = await entry.value;
      }),
    );

    for (int i = 0; i < min(NUM_GROUPS, groupData.length); i++) {
      final String groupName = groupData[i]['name'] ?? '';
      if (groupName.isEmpty) {
        _logger.log(
          "WARNING: Skipping group with empty name at index $i",
          level: "WARNING",
        );
        continue;
      }

      final String groupId =
          'group_${groupName.toLowerCase().replaceAll(' ', '_')}_${_random.nextInt(1000)}';
      groupIds.add(groupId);
      _logger.log(
        "Creating group: $groupId - ${groupData[i]['name']}",
        level: "DEBUG",
      );

      final String creatorId = userIds[_random.nextInt(userIds.length)];
      _logger.log("Selected creator: $creatorId", level: "DEBUG");

      final String? photoURL = groupImages[groupId];
      _logger.log(
        "Group profile image: ${photoURL != null ? 'Available' : 'Failed'}",
        level: "DEBUG",
      );

      final List<String> groupTags = [];
      final int numTags = _random.nextInt(4) + 2;

      final List<String> availableTags = List.from(tagIds);
      availableTags.shuffle(_random);
      groupTags.addAll(availableTags.take(numTags));

      final groupRef = _firestore.collection('groups').doc(groupId);

      final bool requiresApproval = _random.nextBool();

      await batchManager.set(groupRef, {
        'name': groupData[i]['name'],
        'description': groupData[i]['description'],
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': creatorId,
        'photoURL': photoURL,
        'tags': groupTags,
        'settings': {
          'visibility': ['public', 'private'][_random.nextInt(2)],
          'joinApproval': requiresApproval,
        },
      });

      final creatorMemberRef = groupRef.collection('members').doc(creatorId);
      await batchManager.set(creatorMemberRef, {
        'displayName': userData[creatorId]?['displayName'] ?? 'Unknown User',
        'photoURL': userData[creatorId]?['photoURL'],
        'role': 'mentor',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      final creatorRef = _firestore.collection('users').doc(creatorId);
      final creatorGroupRef = creatorRef.collection('groups').doc(groupId);
      await batchManager.set(creatorGroupRef, {
        'name': groupData[i]['name'],
        'photoURL': photoURL,
        'role': 'mentor',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      final discussionChannelId =
          'channel_discussion_${groupId}_${_random.nextInt(1000)}';
      final discussionChannelRef = groupRef
          .collection('channels')
          .doc(discussionChannelId);
      await batchManager.set(discussionChannelRef, {
        'name': 'General Discussion',
        'description': 'Channel for general discussion and announcements',
        'type': 'discussion',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': creatorId,
        'instructions':
            'Use this channel for general communication and announcements.',
      });

      final assessmentChannelId =
          'channel_assessment_${groupId}_${_random.nextInt(1000)}';
      final assessmentChannelRef = groupRef
          .collection('channels')
          .doc(assessmentChannelId);
      await batchManager.set(assessmentChannelRef, {
        'name': 'Assessments',
        'description': 'Channel for group assessments and quizzes',
        'type': 'assessment',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': creatorId,
        'instructions':
            'Use this channel to access and complete shared assessments.',
      });

      final resourceChannelId =
          'channel_resource_${groupId}_${_random.nextInt(1000)}';
      final resourceChannelRef = groupRef
          .collection('channels')
          .doc(resourceChannelId);
      await batchManager.set(resourceChannelRef, {
        'name': 'Resources',
        'description': 'Channel for sharing educational resources',
        'type': 'resource',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': creatorId,
        'instructions':
            'Share and access helpful learning resources in this channel.',
      });

      for (String tagId in groupTags) {
        final tagGroupRef = _firestore
            .collection('tags')
            .doc(tagId)
            .collection('groups')
            .doc(groupId);

        await batchManager.set(tagGroupRef, {
          'name': groupData[i]['name'],
          'photoURL': photoURL,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    _logger.log(
      "Completed group generation. Created ${groupIds.length} groups",
      level: "INFO",
    );
    return groupIds;
  }

  Future<String?> _uploadGroupImageToStorage(String groupId) async {
    try {
      final Reference storageRef = _storage.ref().child(
        'group_images/$groupId.png',
      );

      final List<String> availableProfilePics = await _listAssetProfilePics();

      if (availableProfilePics.isNotEmpty) {
        final String groupImage =
            availableProfilePics[_random.nextInt(availableProfilePics.length)];

        ByteData data = await rootBundle.load(groupImage);
        List<int> bytes = data.buffer.asUint8List();

        final UploadTask uploadTask = storageRef.putData(
          Uint8List.fromList(bytes),
          SettableMetadata(contentType: 'image/png'),
        );

        final TaskSnapshot taskSnapshot = await uploadTask;
        final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

        _logger.log(
          "Uploaded group image for group $groupId to Firebase Storage",
          level: "DEBUG",
        );

        return downloadUrl;
      } else {
        _logger.log("No group images available in assets", level: "WARNING");
        return null;
      }
    } catch (e) {
      _logger.log("Error uploading group image to storage: $e", level: "ERROR");
      return null;
    }
  }

  Future<void> _createGroupMemberships(
    List<String> userIds,
    List<String> groupIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting group membership creation", level: "INFO");
    int membershipsCreated = 0;
    int invitesCreated = 0;
    int requestsCreated = 0;

    final Map<String, Map<String, dynamic>> groupData = {};
    final List<Future<void>> groupDataFutures = [];

    for (String groupId in groupIds) {
      groupDataFutures.add(
        _firestore.collection('groups').doc(groupId).get().then((snapshot) {
          if (snapshot.exists) {
            groupData[groupId] = snapshot.data() ?? {};
          }
        }),
      );
    }

    await Future.wait(groupDataFutures);
    _logger.log("Retrieved data for ${groupData.length} groups", level: "INFO");

    for (String groupId in groupIds) {
      if (!groupData.containsKey(groupId)) {
        _logger.log(
          "WARNING: Group $groupId data not found, skipping",
          level: "WARNING",
        );
        continue;
      }

      final String creatorId = groupData[groupId]?['creatorId'] ?? '';
      if (creatorId.isEmpty) {
        _logger.log(
          "WARNING: Group $groupId has no creator ID, skipping",
          level: "WARNING",
        );
        continue;
      }

      final bool requiresApproval =
          groupData[groupId]?['settings']?['joinApproval'] ?? false;
      final String groupName = groupData[groupId]?['name'] ?? 'Group $groupId';
      final String? groupPhotoURL = groupData[groupId]?['photoURL'];

      final List<String> potentialMemberIds =
          userIds.where((id) => id != creatorId).toList();

      final int numberOfMembers = min(
        _random.nextInt(MAX_GROUP_MEMBERS - MIN_GROUP_MEMBERS + 1) +
            MIN_GROUP_MEMBERS,
        potentialMemberIds.length,
      );
      _logger.log(
        "Adding $numberOfMembers members to group $groupId",
        level: "DEBUG",
      );

      potentialMemberIds.shuffle(_random);

      final List<String> memberIds =
          potentialMemberIds.take(numberOfMembers).toList();
      final List<String> remainingUsers =
          potentialMemberIds.skip(numberOfMembers).toList();

      final groupRef = _firestore.collection('groups').doc(groupId);

      for (String memberId in memberIds) {
        final memberRef = groupRef.collection('members').doc(memberId);
        await batchManager.set(memberRef, {
          'displayName': userData[memberId]?['displayName'] ?? 'Unknown User',
          'photoURL': userData[memberId]?['photoURL'],
          'role': 'student',
          'joinedAt': FieldValue.serverTimestamp(),
        });

        final userRef = _firestore.collection('users').doc(memberId);
        final userGroupRef = userRef.collection('groups').doc(groupId);
        await batchManager.set(userGroupRef, {
          'name': groupName,
          'photoURL': groupPhotoURL,
          'role': 'student',
          'joinedAt': FieldValue.serverTimestamp(),
        });

        membershipsCreated++;
      }

      if (remainingUsers.isNotEmpty) {
        final int numberOfInvites = min(
          _random.nextInt(4) + 3,
          remainingUsers.length,
        );

        remainingUsers.shuffle(_random);
        final invitedUsers = remainingUsers.take(numberOfInvites).toList();
        remainingUsers.removeWhere((id) => invitedUsers.contains(id));

        for (String invitedUserId in invitedUsers) {
          final pendingInviteRef = groupRef
              .collection('pendingInvites')
              .doc(invitedUserId);
          await batchManager.set(pendingInviteRef, {
            'displayName':
                userData[invitedUserId]?['displayName'] ?? 'Unknown User',
            'invitedBy': creatorId,
            'invitedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

          final userRef = _firestore.collection('users').doc(invitedUserId);
          final userInviteRef = userRef
              .collection('groupInvites')
              .doc(
                'invite_${groupId}_${invitedUserId}_${_random.nextInt(10000)}',
              );
          await batchManager.set(userInviteRef, {
            'groupId': groupId,
            'groupName': groupName,
            'invitedBy': creatorId,
            'inviterName':
                userData[creatorId]?['displayName'] ?? 'Unknown User',
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending',
          });

          invitesCreated++;
        }
      }

      if (requiresApproval && remainingUsers.isNotEmpty) {
        final int numberOfRequests = min(
          _random.nextInt(3) + 2,
          remainingUsers.length,
        );

        remainingUsers.shuffle(_random);
        final requestUsers = remainingUsers.take(numberOfRequests).toList();

        for (String requestUserId in requestUsers) {
          final joinRequestRef = groupRef
              .collection('joinRequests')
              .doc(requestUserId);
          await batchManager.set(joinRequestRef, {
            'displayName':
                userData[requestUserId]?['displayName'] ?? 'Unknown User',
            'photoURL': userData[requestUserId]?['photoURL'],
            'requestedAt': FieldValue.serverTimestamp(),
            'status': 'pending',
            'message': 'I would like to join this group',
          });

          requestsCreated++;
        }
      }
    }

    _logger.log(
      "Completed group membership creation: $membershipsCreated memberships, $invitesCreated invites, $requestsCreated requests",
      level: "INFO",
    );
  }

  Future<List<String>> _generateAssessments(
    List<String> userIds,
    List<String> tagIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log("Starting assessment generation", level: "INFO");

    final List<String> assessmentIds = [];

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
      {
        'title': 'Linear Algebra Review',
        'description': 'Comprehensive review of linear algebra concepts',
      },
      {
        'title': 'Shakespeare\'s Plays Quiz',
        'description': 'Test your knowledge of Shakespeare\'s major works',
      },
      {
        'title': 'Economic Principles Test',
        'description': 'Assessment on basic economic concepts and theories',
      },
      {
        'title': 'Human Anatomy',
        'description': 'Quiz on major systems and organs of human body',
      },
      {
        'title': 'Quantum Physics Basics',
        'description':
            'Introduction to fundamental concepts in quantum physics',
      },
    ];

    final List<String> questionTypes = [
      'multiple-choice',
      'short-answer',
      'true-false',
      'matching',
      'fill-in-blank',
    ];

    final int numAssessments = min(NUM_ASSESSMENTS, assessmentData.length);
    _logger.log("Will create $numAssessments assessments", level: "INFO");
    int totalQuestions = 0;

    for (int i = 0; i < numAssessments; i++) {
      final String assessmentTitle = assessmentData[i]['title'] ?? '';
      if (assessmentTitle.isEmpty) {
        _logger.log(
          "WARNING: Skipping assessment with empty title at index $i",
          level: "WARNING",
        );
        continue;
      }

      final String assessmentId =
          'assessment_${i}_${assessmentTitle.toLowerCase().replaceAll(' ', '_')}_${_random.nextInt(10000)}';
      assessmentIds.add(assessmentId);
      _logger.log(
        "Creating assessment: $assessmentId - $assessmentTitle",
        level: "DEBUG",
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
      level: "INFO",
    );
    return assessmentIds;
  }

  Future<void> _shareAssessments(
    List<String> userIds,
    List<String> groupIds,
    List<String> assessmentIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log(
      "Starting assessment sharing with PROPERLY FIXED flag preservation",
      level: "INFO",
    );

    int assessmentsSharedWithUsers = 0;
    int assessmentsSharedWithGroups = 0;
    int usersBothFlagsSet = 0;

    final assessmentData = await _preloadAssessmentData(assessmentIds);
    final userFriends = await _preloadUserFriends(userIds);
    final groupInfo = await _preloadGroupData(groupIds);

    Map<String, Map<String, Set<String>>> sharingTracker = {};

    _logger.log(
      "👉 PHASE 1: Pre-marking all sharing relationships",
      level: "INFO",
    );

    for (String assessmentId in assessmentIds) {
      if (!assessmentData.containsKey(assessmentId)) {
        _logger.log(
          "Skipping missing assessment: $assessmentId",
          level: "WARNING",
        );
        continue;
      }

      final assessmentInfo = assessmentData[assessmentId]!;
      final String creatorId = assessmentInfo['creatorId'] ?? '';

      if (creatorId.isEmpty) {
        _logger.log(
          "Assessment $assessmentId has no creator, skipping",
          level: "WARNING",
        );
        continue;
      }

      sharingTracker[assessmentId] = {};

      final List<String> creatorFriends = userFriends[creatorId] ?? [];
      int numFriendsToShare = min(
        StaticData.MIN_SHARED_USERS,
        creatorFriends.length,
      );

      if (creatorFriends.isNotEmpty) {
        final shuffledFriends = List.from(creatorFriends)..shuffle(_random);
        final selectedFriends =
            shuffledFriends.take(numFriendsToShare).toList();

        for (String friendId in selectedFriends) {
          if (!sharingTracker[assessmentId]!.containsKey(friendId)) {
            sharingTracker[assessmentId]![friendId] = {};
          }
          sharingTracker[assessmentId]![friendId]!.add('direct');
          _logger.log(
            "Marked assessment $assessmentId for direct sharing with $friendId",
            level: "DEBUG",
          );
        }
      }

      int numGroupsToShare = min(StaticData.MIN_SHARED_GROUPS, groupIds.length);

      if (groupIds.isNotEmpty) {
        final eligibleGroups =
            groupIds
                .where(
                  (groupId) =>
                      groupInfo.containsKey(groupId) &&
                      groupInfo[groupId]!['channelId'] != null &&
                      groupInfo[groupId]!['mentorId'] != null,
                )
                .toList();

        if (eligibleGroups.isNotEmpty) {
          final shuffledGroups = List.from(eligibleGroups)..shuffle(_random);
          final selectedGroups = shuffledGroups.take(numGroupsToShare).toList();

          for (String groupId in selectedGroups) {
            final members =
                groupInfo[groupId]!['members'] as List<String>? ?? [];

            for (String memberId in members) {
              if (memberId == creatorId) continue;

              if (!sharingTracker[assessmentId]!.containsKey(memberId)) {
                sharingTracker[assessmentId]![memberId] = {};
              }
              sharingTracker[assessmentId]![memberId]!.add('group');
              _logger.log(
                "Marked assessment $assessmentId for group sharing with $memberId via group $groupId",
                level: "DEBUG",
              );
            }
          }
        }
      }
    }

    _logger.log(
      "👉 PHASE 2: Executing actual sharing operations with proper flags",
      level: "INFO",
    );

    for (String assessmentId in sharingTracker.keys) {
      final assessmentInfo = assessmentData[assessmentId]!;
      final String creatorId = assessmentInfo['creatorId'] ?? '';
      final String assessmentTitle = assessmentInfo['title'] ?? 'Assessment';

      Map<String, Map<String, String>> directShareUsers = {};
      for (String userId in sharingTracker[assessmentId]!.keys) {
        if (sharingTracker[assessmentId]![userId]!.contains('direct')) {
          final creatorName =
              userData[creatorId]?['displayName'] ?? 'Assessment Creator';
          directShareUsers[userId] = {creatorId: creatorName};
          assessmentsSharedWithUsers++;
        }
      }

      for (String userId in directShareUsers.keys) {
        final sharedUserRef = _firestore
            .collection('assessments')
            .doc(assessmentId)
            .collection('sharedWithUsers')
            .doc(userId);

        await batchManager.set(sharedUserRef, {
          'userMap': directShareUsers[userId],
          'sharedAt': FieldValue.serverTimestamp(),
        });
      }

      Set<String> groupShareGroups = {};
      Map<String, String> groupMembers = {};

      for (String userId in sharingTracker[assessmentId]!.keys) {
        if (sharingTracker[assessmentId]![userId]!.contains('group')) {
          for (String groupId in groupInfo.keys) {
            final members =
                groupInfo[groupId]!['members'] as List<String>? ?? [];
            if (members.contains(userId)) {
              groupShareGroups.add(groupId);
              final mentorId =
                  groupInfo[groupId]!['mentorId'] as String? ?? creatorId;
              groupMembers[userId] = mentorId;
            }
          }
        }
      }

      for (String groupId in groupShareGroups) {
        final groupName = groupInfo[groupId]?['name'] as String? ?? 'Group';
        final mentorId =
            groupInfo[groupId]?['mentorId'] as String? ?? creatorId;
        final mentorName = userData[mentorId]?['displayName'] ?? 'Group Mentor';
        final channelId = groupInfo[groupId]?['channelId'] as String?;

        if (channelId == null) {
          _logger.log(
            "No channel found for group $groupId, skipping",
            level: "WARNING",
          );
          continue;
        }

        final sharedGroupRef = _firestore
            .collection('assessments')
            .doc(assessmentId)
            .collection('sharedWithGroups')
            .doc(groupId);

        await batchManager.set(sharedGroupRef, {
          'groupName': groupName,
          'sharedBy': mentorId,
          'sharedAt': FieldValue.serverTimestamp(),
          'startTime': FieldValue.serverTimestamp(),
          'endTime': Timestamp.fromDate(DateTime.now().add(Duration(days: 14))),
          'hasTimer': _random.nextBool(),
          'timerDuration': 30,
          'attemptsAllowed': _random.nextInt(3) + 1,
        });

        final channelRef = _firestore
            .collection('groups')
            .doc(groupId)
            .collection('channels')
            .doc(channelId)
            .collection('assessments')
            .doc(assessmentId);

        await batchManager.set(channelRef, {
          'title': assessmentTitle,
          'description': assessmentInfo['description'] ?? '',
          'assignedBy': mentorId,
          'assignedAt': FieldValue.serverTimestamp(),
          'startTime': FieldValue.serverTimestamp(),
          'endTime': Timestamp.fromDate(DateTime.now().add(Duration(days: 14))),
          'hasTimer': _random.nextBool(),
          'timerDuration': 30,
          'madeByAI': assessmentInfo['madeByAI'] ?? false,
        });

        assessmentsSharedWithGroups++;
      }

      _logger.log(
        "👉 PHASE 3: Setting assessment flags in user documents",
        level: "INFO",
      );

      for (String userId in sharingTracker[assessmentId]!.keys) {
        final bool shareDirectly = sharingTracker[assessmentId]![userId]!
            .contains('direct');
        final bool shareViaGroup = sharingTracker[assessmentId]![userId]!
            .contains('group');

        _logger.log(
          "Setting flags for user $userId assessment $assessmentId: direct=$shareDirectly, group=$shareViaGroup",
          level: "DEBUG",
        );

        final userRef = _firestore.collection('users').doc(userId);
        final userAssessmentRef = userRef
            .collection('assessments')
            .doc(assessmentId);
        final doc = await userAssessmentRef.get();

        if (doc.exists) {
          final data = doc.data() ?? {};
          final bool existingDirectFlag = data['wasSharedWithUser'] ?? false;
          final bool existingGroupFlag = data['wasSharedInGroup'] ?? false;

          final bool finalDirectFlag = existingDirectFlag || shareDirectly;
          final bool finalGroupFlag = existingGroupFlag || shareViaGroup;

          if (finalDirectFlag && finalGroupFlag) {
            usersBothFlagsSet++;
          }

          await batchManager.update(userAssessmentRef, {
            'title': assessmentTitle,
            'description': assessmentInfo['description'] ?? '',
            'difficulty': assessmentInfo['difficulty'] ?? 'medium',
            'totalPoints': assessmentInfo['totalPoints'] ?? 100,
            'rating': assessmentInfo['rating'] ?? 3,
            'sourceDocumentId': assessmentInfo['sourceDocumentId'] ?? '',
            'madeByAI': assessmentInfo['madeByAI'] ?? false,
            'wasSharedWithUser': finalDirectFlag,
            'wasSharedInGroup': finalGroupFlag,
          });

          _logger.log(
            "UPDATED user assessment document with flags: direct=$finalDirectFlag, group=$finalGroupFlag",
            level: "DEBUG",
          );
        } else {
          await batchManager.set(userAssessmentRef, {
            'title': assessmentTitle,
            'createdAt': FieldValue.serverTimestamp(),
            'description': assessmentInfo['description'] ?? '',
            'difficulty': assessmentInfo['difficulty'] ?? 'medium',
            'totalPoints': assessmentInfo['totalPoints'] ?? 100,
            'rating': assessmentInfo['rating'] ?? 3,
            'sourceDocumentId': assessmentInfo['sourceDocumentId'] ?? '',
            'madeByAI': assessmentInfo['madeByAI'] ?? false,
            'wasSharedWithUser': shareDirectly,
            'wasSharedInGroup': shareViaGroup,
          });

          if (shareDirectly && shareViaGroup) {
            usersBothFlagsSet++;
          }

          _logger.log(
            "CREATED user assessment document with flags: direct=$shareDirectly, group=$shareViaGroup",
            level: "DEBUG",
          );
        }

        if (batchManager.operationCount > 400) {
          _logger.log(
            "Committing batch during sharing operation",
            level: "INFO",
          );
          await batchManager.commitBatch();
        }
      }
    }

    _logger.log(
      "Assessment sharing completed: $assessmentsSharedWithUsers direct shares, " +
          "$assessmentsSharedWithGroups group shares, $usersBothFlagsSet users with BOTH flags set",
      level: "SUCCESS",
    );

    await _verifyAssessmentSharing();
  }

  Future<Map<String, Map<String, dynamic>>> _preloadAssessmentData(
    List<String> assessmentIds,
  ) async {
    final Map<String, Map<String, dynamic>> result = {};
    final List<Future<void>> futures = [];

    for (String assessmentId in assessmentIds) {
      futures.add(
        _firestore.collection('assessments').doc(assessmentId).get().then((
          snapshot,
        ) {
          if (snapshot.exists) {
            result[assessmentId] = snapshot.data() ?? {};
          }
        }),
      );
    }

    await Future.wait(futures);
    _logger.log(
      "Preloaded data for ${result.length} assessments",
      level: "INFO",
    );
    return result;
  }

  Future<Map<String, List<String>>> _preloadUserFriends(
    List<String> userIds,
  ) async {
    final Map<String, List<String>> result = {};
    final List<Future<void>> futures = [];

    for (String userId in userIds) {
      futures.add(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('friends')
            .get()
            .then((snapshot) {
              result[userId] = snapshot.docs.map((doc) => doc.id).toList();
            }),
      );
    }

    await Future.wait(futures);
    _logger.log(
      "Preloaded friend data for ${result.length} users",
      level: "INFO",
    );
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _preloadGroupData(
    List<String> groupIds,
  ) async {
    final Map<String, Map<String, dynamic>> result = {};
    final List<Future<void>> futures = [];

    for (String groupId in groupIds) {
      futures.add(
        _firestore.collection('groups').doc(groupId).get().then((snapshot) {
          if (snapshot.exists) {
            result[groupId] = snapshot.data() ?? {};
            result[groupId]!['members'] = <String>[];
          }
        }),
      );
    }

    await Future.wait(futures);
    futures.clear();

    for (String groupId in result.keys) {
      futures.add(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .get()
            .then((snapshot) {
              result[groupId]!['members'] =
                  snapshot.docs.map((doc) => doc.id).toList();
            }),
      );

      futures.add(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .where('role', isEqualTo: 'mentor')
            .limit(1)
            .get()
            .then((snapshot) {
              if (snapshot.docs.isNotEmpty) {
                result[groupId]!['mentorId'] = snapshot.docs.first.id;
                result[groupId]!['mentorName'] =
                    snapshot.docs.first.data()['displayName'] ?? 'Mentor';
              }
            }),
      );

      futures.add(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('channels')
            .where('type', isEqualTo: 'assessment')
            .limit(1)
            .get()
            .then((snapshot) {
              if (snapshot.docs.isNotEmpty) {
                result[groupId]!['channelId'] = snapshot.docs.first.id;
              }
            }),
      );
    }

    await Future.wait(futures);
    _logger.log(
      "Preloaded complete data for ${result.length} groups",
      level: "INFO",
    );
    return result;
  }

  Future<void> _verifyAssessmentSharing() async {
    _logger.log(
      "VERIFICATION: Checking assessment sharing flags...",
      level: "INFO",
    );

    try {
      int totalAssessments = 0;
      int directShared = 0;
      int groupShared = 0;
      int bothFlags = 0;

      final userSnapshot = await _firestore.collection('users').limit(5).get();

      for (final userDoc in userSnapshot.docs) {
        final assessmentsSnapshot =
            await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('assessments')
                .get();

        totalAssessments += assessmentsSnapshot.docs.length;

        for (final assessmentDoc in assessmentsSnapshot.docs) {
          final data = assessmentDoc.data();
          final bool directFlag = data['wasSharedWithUser'] ?? false;
          final bool groupFlag = data['wasSharedInGroup'] ?? false;

          if (directFlag) directShared++;
          if (groupFlag) groupShared++;
          if (directFlag && groupFlag) bothFlags++;
        }
      }

      _logger.log("VERIFICATION RESULTS:", level: "INFO");
      _logger.log(
        "- Total assessments checked: $totalAssessments",
        level: "INFO",
      );
      _logger.log(
        "- With wasSharedWithUser=true: $directShared",
        level: "INFO",
      );
      _logger.log("- With wasSharedInGroup=true: $groupShared", level: "INFO");
      _logger.log("- With BOTH flags true: $bothFlags", level: "INFO");

      if (bothFlags > 0) {
        _logger.log(
          "✅ SUCCESS: Found assessments with both flags set!",
          level: "SUCCESS",
        );
      } else {
        _logger.log(
          "⚠️ WARNING: No assessments found with both flags set",
          level: "WARNING",
        );
      }
    } catch (e) {
      _logger.log("Error during verification: $e", level: "ERROR");
    }
  }

  Future<void> _generateSubmissions(
    List<String> userIds,
    List<String> groupIds,
    List<String> assessmentIds,
    Map<String, Map<String, dynamic>> userData,
    BatchManager batchManager,
  ) async {
    _logger.log(
      "Starting submission generation with FIXED mirroring",
      level: "INFO",
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
            level: "DEBUG",
          );
        }
      } catch (e) {
        _logger.log(
          "ERROR caching channels for group $groupId: $e",
          level: "ERROR",
        );
      }
    }

    _logger.log(
      "Prefetched assessment channels for ${groupChannelsCache.length} groups",
      level: "INFO",
    );

    for (String userId in userIds) {
      _logger.log("Processing submissions for user $userId", level: "DEBUG");

      final userAssessmentsSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('assessments')
              .get();

      if (userAssessmentsSnapshot.docs.isEmpty) {
        _logger.log(
          "No assessments found for user $userId, skipping",
          level: "DEBUG",
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
            level: "DEBUG",
          );
          continue;
        }

        _logger.log(
          "Processing assessment $assessmentId for user $userId (wasSharedWithUser=$wasSharedWithUser, wasSharedInGroup=$wasSharedInGroup)",
          level: "DEBUG",
        );

        final assessmentRef = _firestore
            .collection('assessments')
            .doc(assessmentId);

        final questionsSnapshot =
            await assessmentRef.collection('questions').get();
        if (questionsSnapshot.docs.isEmpty) {
          _logger.log(
            "No questions found for assessment $assessmentId, skipping",
            level: "WARNING",
          );
          continue;
        }

        final List<Map<String, dynamic>> questions = [];
        for (final questionDoc in questionsSnapshot.docs) {
          questions.add({
            'id': questionDoc.id,
            'type': questionDoc.data()['questionType'] ?? 'short-answer',
            'points': questionDoc.data()['points'] ?? 5,
            'options': questionDoc.data()['options'],
          });
        }

        _logger.log(
          "Found ${questions.length} questions for assessment $assessmentId",
          level: "DEBUG",
        );

        final int numberOfSubmissions = _random.nextInt(3) + 1;
        _logger.log(
          "Creating $numberOfSubmissions submissions for user $userId on assessment $assessmentId",
          level: "DEBUG",
        );

        for (int i = 0; i < numberOfSubmissions; i++) {
          final String submissionId =
              'submission_${userId}_${assessmentId}_${i}_${_random.nextInt(10000)}';

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
                status == 'evaluated'
                    ? 'Overall feedback for this submission'
                    : null,
          };

          await batchManager.set(submissionRef, submissionData);
          submissionsCreated++;
          _logger.log(
            "Created submission $submissionId with status=$status",
            level: "DEBUG",
          );

          int questionsToAnswer = questions.length;
          if (status == 'in-progress') {
            questionsToAnswer = _random.nextInt(questions.length) + 1;
            _logger.log(
              "In-progress submission will answer $questionsToAnswer of ${questions.length} questions",
              level: "DEBUG",
            );
          }

          final List<Map<String, dynamic>> answersData = [];

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
                level: "DEBUG",
              );
            }

            answersData.add({'id': answerId, 'data': answerData});

            await batchManager.set(answerRef, answerData);
            answersCreated++;
          }

          if (status == 'evaluated') {
            await batchManager.update(submissionRef, {
              'totalScore': totalScore,
            });
            submissionData['totalScore'] = totalScore;
            _logger.log(
              "Updated total score to $totalScore for submission $submissionId",
              level: "DEBUG",
            );
          }

          if (wasSharedInGroup) {
            _logger.log(
              "Assessment was shared in a group, mirroring submission to group channels",
              level: "DEBUG",
            );

            final sharedGroupsSnapshot =
                await assessmentRef.collection('sharedWithGroups').get();

            if (sharedGroupsSnapshot.docs.isEmpty) {
              _logger.log(
                "WARNING: Assessment $assessmentId has wasSharedInGroup=true but no entries in sharedWithGroups collection",
                level: "WARNING",
              );
            }

            int successfulMirrors = 0;

            for (final groupDoc in sharedGroupsSnapshot.docs) {
              final String groupId = groupDoc.id;
              _logger.log(
                "Checking group $groupId for mirroring assessment $assessmentId",
                level: "DEBUG",
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
                  level: "DEBUG",
                );
                continue;
              }

              String? channelId;
              if (groupChannelsCache.containsKey(groupId) &&
                  groupChannelsCache[groupId]!.isNotEmpty) {
                channelId = groupChannelsCache[groupId]!.keys.first;
                _logger.log(
                  "Using cached assessment channel $channelId for group $groupId",
                  level: "DEBUG",
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
                    level: "WARNING",
                  );
                  continue;
                }

                channelId = channelsSnapshot.docs.first.id;
                _logger.log(
                  "Found assessment channel $channelId for group $groupId",
                  level: "DEBUG",
                );
              }

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
                  level: "ERROR",
                );

                final assessmentDoc = await assessmentRef.get();

                if (!assessmentDoc.exists) {
                  _logger.log(
                    "ERROR: Original assessment $assessmentId does not exist, cannot mirror",
                    level: "ERROR",
                  );
                  mirroringErrors++;
                  continue;
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

                await batchManager.set(channelAssessmentRef, {
                  'title': assessmentDoc.data()?['title'] ?? 'Assessment',
                  'description': assessmentDoc.data()?['description'] ?? '',
                  'assignedBy': assignerId,
                  'assignedAt': FieldValue.serverTimestamp(),
                  'startTime': FieldValue.serverTimestamp(),
                  'endTime': Timestamp.fromDate(
                    DateTime.now().add(const Duration(days: 14)),
                  ),
                  'hasTimer': false,
                  'timerDuration': 30,
                  'madeByAI': assessmentDoc.data()?['madeByAI'] ?? false,
                });

                _logger.log(
                  "Created missing assessment $assessmentId in channel $channelId",
                  level: "INFO",
                );
              }

              final groupSubmissionRef = channelAssessmentRef
                  .collection('submissions')
                  .doc(submissionId);

              await batchManager.set(groupSubmissionRef, submissionData);
              _logger.log(
                "Mirrored submission $submissionId to group $groupId channel $channelId",
                level: "DEBUG",
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
                level: "DEBUG",
              );
              successfulMirrors++;
            }

            if (successfulMirrors > 0) {
              groupSubmissionsMirrored++;
              _logger.log(
                "Successfully mirrored submission to $successfulMirrors groups",
                level: "DEBUG",
              );
            } else {
              _logger.log(
                "WARNING: Failed to mirror submission to any groups despite wasSharedInGroup=true",
                level: "WARNING",
              );
            }
          }

          if (batchManager.operationCount > 200) {
            _logger.log(
              "Committing batch during submission generation to avoid size limits",
              level: "INFO",
            );
            await batchManager.commitBatch();
          }
        }
      }
    }

    if (mirroringErrors > 0) {
      _logger.log(
        "Encountered $mirroringErrors errors during submission mirroring",
        level: "ERROR",
      );
    }

    _logger.log(
      "Completed submission generation: created $submissionsCreated submissions with $answersCreated answers",
      level: "INFO",
    );
    _logger.log(
      "Successfully mirrored $groupSubmissionsMirrored submissions to group channels",
      level: "INFO",
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  void _startStepTimer(String step) {
    _stepTimers[step] = Stopwatch()..start();
  }

  void _stopStepTimer(String step) {
    if (_stepTimers.containsKey(step)) {
      final elapsed = _stepTimers[step]!.elapsedMilliseconds;
      _logger.log(
        'Step "$step" completed in ${(elapsed / 1000).toStringAsFixed(2)}s',
        level: "INFO",
      );
      _stepTimers[step]!.stop();
    }
  }

  void _logGenerationSummary() {
    final totalElapsed = _totalStopwatch.elapsedMilliseconds;

    _logger.log('=== DATA GENERATION SUMMARY ===', level: "SUCCESS");
    _logger.log(
      'Total time: ${(totalElapsed / 1000).toStringAsFixed(2)}s',
      level: "INFO",
    );

    List<MapEntry<String, int>> stepTimes = [];
    for (final entry in _stepTimers.entries) {
      if (entry.key != 'total') {
        stepTimes.add(MapEntry(entry.key, entry.value.elapsedMilliseconds));
      }
    }

    stepTimes.sort((a, b) => b.value.compareTo(a.value));

    for (final entry in stepTimes) {
      final percentage = (entry.value / totalElapsed * 100).toStringAsFixed(1);
      _logger.log(
        '- ${entry.key}: ${(entry.value / 1000).toStringAsFixed(2)}s ($percentage%)',
        level: "INFO",
      );
    }
  }
}
