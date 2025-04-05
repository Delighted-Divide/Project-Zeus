import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/log_level.dart';
import '../models/static_data.dart';
import '../services/batch_manager.dart';
import '../utils/logging_utils.dart';
import 'tag_generator.dart';
import 'user_generator.dart';
import 'social_generator.dart';
import 'group_generator.dart';
import 'assessment_generator.dart';
import 'submission_generator.dart';

/// A comprehensive utility class to orchestrate generating test data for educational application
/// Optimized for performance and reliability through modular architecture
class DummyDataGenerator {
  // Core Firebase services
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Build context for UI feedback
  final BuildContext context;

  // Utility and generator instances
  final LoggingUtils _logger;
  final TagGenerator _tagGenerator;
  final UserGenerator _userGenerator;
  final SocialGenerator _socialGenerator;
  final GroupGenerator _groupGenerator;
  final AssessmentGenerator _assessmentGenerator;
  final SubmissionGenerator _submissionGenerator;

  // Timers for tracking performance
  final Stopwatch _totalStopwatch = Stopwatch();
  final Map<String, Stopwatch> _stepTimers = {};

  // Constructor with dependency injection
  DummyDataGenerator(this.context, {bool verbose = true})
    : _auth = FirebaseAuth.instance,
      _firestore = FirebaseFirestore.instance,
      _logger = LoggingUtils(verbose: verbose),
      _tagGenerator = TagGenerator(FirebaseFirestore.instance),
      _userGenerator = UserGenerator(
        FirebaseAuth.instance,
        FirebaseFirestore.instance,
      ),
      _socialGenerator = SocialGenerator(FirebaseFirestore.instance),
      _groupGenerator = GroupGenerator(FirebaseFirestore.instance),
      _assessmentGenerator = AssessmentGenerator(FirebaseFirestore.instance),
      _submissionGenerator = SubmissionGenerator(FirebaseFirestore.instance);

  /// Main function to orchestrate the generation of all dummy data
  Future<void> generateAllDummyData() async {
    _totalStopwatch.start();
    _startStepTimer('total');
    try {
      // Log start of process
      _logger.log(
        "====== STARTING DUMMY DATA GENERATION PROCESS ======",
        level: LogLevel.INFO,
      );

      // Verify a user is signed in
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        _showSnackBar('No user signed in. Please sign in first.', Colors.red);
        _logger.log("Error: No user signed in", level: LogLevel.ERROR);
        return;
      }

      _logger.log(
        "Current user: ${currentUser.uid} (${currentUser.email})",
        level: LogLevel.INFO,
      );

      // Store original user info for reference
      final String originalUid = currentUser.uid;

      _showSnackBar('Starting to generate dummy data...', Colors.blue);

      // Create a batch manager for Firestore operations
      final batchManager = BatchManager(_firestore, verbose: true);

      // Execute data generation steps
      await _executeDataGenerationSteps(currentUser, batchManager);

      // Log final stats
      _logGenerationSummary();

      _showSnackBar(
        'Dummy data generation completed successfully!',
        Colors.green,
      );
      _logger.log(
        "====== DUMMY DATA GENERATION COMPLETED SUCCESSFULLY ======",
        level: LogLevel.SUCCESS,
      );
    } catch (e, stackTrace) {
      _logger.log("ERROR generating dummy data: $e", level: LogLevel.ERROR);
      _logger.log("Stack trace: $stackTrace", level: LogLevel.ERROR);
      _showSnackBar('Error generating dummy data: $e', Colors.red);
    } finally {
      _stopStepTimer('total');
      _totalStopwatch.stop();
      // Save logs to file
      await _logger.saveLogsToFile();
    }
  }

  /// Execute all data generation steps with proper timing and metrics
  Future<void> _executeDataGenerationSteps(
    User currentUser,
    BatchManager batchManager,
  ) async {
    // Step 1: Generate tags
    _startStepTimer('generateTags');
    _logger.log("STEP 1: Generating tags", level: LogLevel.INFO);
    final tagIds = await _tagGenerator.generateTags(batchManager);
    await batchManager.commit();
    _stopStepTimer('generateTags');
    _logger.log(
      "Tags generated and committed: ${tagIds.length} tags",
      level: LogLevel.SUCCESS,
    );

    // Step 2: Generate users
    _startStepTimer('generateUsers');
    _logger.log("STEP 2: Generating users", level: LogLevel.INFO);
    final userData = await _userGenerator.generateUsers(currentUser);
    final userIds = userData.keys.toList();
    _stopStepTimer('generateUsers');
    _logger.log(
      "Users generated: ${userIds.length} users",
      level: LogLevel.SUCCESS,
    );

    // Step 3: Assign favorite tags
    _startStepTimer('assignTags');
    _logger.log("STEP 3: Assigning favorite tags", level: LogLevel.INFO);
    await _tagGenerator.assignFavoriteTags(userIds, tagIds, batchManager);
    await batchManager.commit();
    _stopStepTimer('assignTags');
    _logger.log(
      "Favorite tags assigned and committed",
      level: LogLevel.SUCCESS,
    );

    // Step 4: Create user goals
    _startStepTimer('createGoals');
    _logger.log("STEP 4: Creating user goals", level: LogLevel.INFO);
    await _userGenerator.createUserGoals(userIds, batchManager);
    await batchManager.commit();
    _stopStepTimer('createGoals');
    _logger.log("User goals created and committed", level: LogLevel.SUCCESS);

    // Step 5: Create friendships
    _startStepTimer('createFriendships');
    _logger.log("STEP 5: Creating friendships", level: LogLevel.INFO);
    await _socialGenerator.createFriendships(userIds, userData, batchManager);
    await batchManager.commit();
    _stopStepTimer('createFriendships');
    _logger.log("Friendships created and committed", level: LogLevel.SUCCESS);

    // Step 6: Generate groups
    _startStepTimer('generateGroups');
    _logger.log("STEP 6: Generating groups", level: LogLevel.INFO);
    final groupIds = await _groupGenerator.generateGroups(
      userIds,
      tagIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('generateGroups');
    _logger.log(
      "Groups generated and committed: ${groupIds.length} groups",
      level: LogLevel.SUCCESS,
    );

    // Step 7: Create group memberships
    _startStepTimer('createMemberships');
    _logger.log("STEP 7: Creating group memberships", level: LogLevel.INFO);
    await _groupGenerator.createGroupMemberships(
      userIds,
      groupIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('createMemberships');
    _logger.log(
      "Group memberships created and committed",
      level: LogLevel.SUCCESS,
    );

    // Step 8: Generate assessments
    _startStepTimer('generateAssessments');
    _logger.log("STEP 8: Generating assessments", level: LogLevel.INFO);
    final assessmentIds = await _assessmentGenerator.generateAssessments(
      userIds,
      tagIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('generateAssessments');
    _logger.log(
      "Assessments generated and committed: ${assessmentIds.length} assessments",
      level: LogLevel.SUCCESS,
    );

    // Step 9: Share assessments
    _startStepTimer('shareAssessments');
    _logger.log("STEP 9: Sharing assessments", level: LogLevel.INFO);
    await _assessmentGenerator.shareAssessments(
      userIds,
      groupIds,
      assessmentIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('shareAssessments');
    _logger.log(
      "Assessment sharing completed and committed",
      level: LogLevel.SUCCESS,
    );

    // Step 10: Generate submissions
    _startStepTimer('generateSubmissions');
    _logger.log("STEP 10: Generating submissions", level: LogLevel.INFO);
    await _submissionGenerator.generateSubmissions(
      userIds,
      groupIds,
      assessmentIds,
      userData,
      batchManager,
    );
    await batchManager.commit();
    _stopStepTimer('generateSubmissions');
    _logger.log("Submissions generated and committed", level: LogLevel.SUCCESS);
  }

  /// Show snackbar with message
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  /// Start a step timer
  void _startStepTimer(String step) {
    _stepTimers[step] = Stopwatch()..start();
  }

  /// Stop a step timer and log the elapsed time
  void _stopStepTimer(String step) {
    if (_stepTimers.containsKey(step)) {
      final elapsed = _stepTimers[step]!.elapsedMilliseconds;
      _logger.log(
        'Step "$step" completed in ${(elapsed / 1000).toStringAsFixed(2)}s',
        level: LogLevel.INFO,
      );
      _stepTimers[step]!.stop();
    }
  }

  /// Log a summary of the generation process
  void _logGenerationSummary() {
    final totalElapsed = _totalStopwatch.elapsedMilliseconds;

    _logger.log('=== DATA GENERATION SUMMARY ===', level: LogLevel.SUCCESS);
    _logger.log(
      'Total time: ${(totalElapsed / 1000).toStringAsFixed(2)}s',
      level: LogLevel.INFO,
    );

    // List step times in order
    List<MapEntry<String, int>> stepTimes = [];
    for (final entry in _stepTimers.entries) {
      if (entry.key != 'total') {
        // Skip total time
        stepTimes.add(MapEntry(entry.key, entry.value.elapsedMilliseconds));
      }
    }

    // Sort by elapsed time (descending)
    stepTimes.sort((a, b) => b.value.compareTo(a.value));

    // Log each step time
    for (final entry in stepTimes) {
      final percentage = (entry.value / totalElapsed * 100).toStringAsFixed(1);
      _logger.log(
        '- ${entry.key}: ${(entry.value / 1000).toStringAsFixed(2)}s ($percentage%)',
        level: LogLevel.INFO,
      );
    }
  }
}
