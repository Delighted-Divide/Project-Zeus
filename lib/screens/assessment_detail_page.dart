import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'assessment_page.dart';
import 'dashboard.dart';

class AssessmentDetailPage extends StatefulWidget {
  final String assessmentId;
  final int initialTab;

  const AssessmentDetailPage({
    Key? key,
    required this.assessmentId,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage>
    with TickerProviderStateMixin {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;

  // Loading state
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Data state
  Map<String, dynamic> _assessmentData = {};
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _userSubmissions = [];
  Map<String, dynamic>? _currentSubmission;
  Map<String, dynamic>? _latestEvaluatedSubmission;
  Map<String, dynamic> _answers = {};
  String? _groupId;
  bool _hasTimer = false;
  int _timerDuration = 0;

  // Animation controllers
  late TabController _tabController;
  late final AnimationController _fadeInController;
  late final AnimationController _slideController;
  late final AnimationController _scaleController;

  // Tab information
  final List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.info_outline, 'label': 'Overview'},
    {'icon': Icons.assignment_outlined, 'label': 'Questions'},
    {'icon': Icons.history_outlined, 'label': 'Submissions'},
    {'icon': Icons.analytics_outlined, 'label': 'Results'},
  ];

  @override
  void initState() {
    super.initState();
    developer.log(
      'AssessmentDetailPage: Initializing for assessment ID: ${widget.assessmentId}',
      name: 'AssessmentDetailPage',
    );

    // Initialize tab controller
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    // Initialize animation controllers
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Initialize current user and load data
    _initializeCurrentUser();

    // Start animations
    _fadeInController.forward();
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    developer.log(
      'AssessmentDetailPage: Disposing controllers',
      name: 'AssessmentDetailPage',
    );
    _tabController.dispose();
    _fadeInController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Initialize current user and load assessment data
  Future<void> _initializeCurrentUser() async {
    developer.log(
      'AssessmentDetailPage: Initializing current user',
      name: 'AssessmentDetailPage',
    );

    try {
      // Get current user
      _currentUserId = _auth.currentUser?.uid;
      developer.log(
        'AssessmentDetailPage: Current user ID: $_currentUserId',
        name: 'AssessmentDetailPage',
      );

      if (_currentUserId != null) {
        // Load assessment data
        await _loadAssessmentData();
      } else {
        // Handle not logged in state
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('You need to be logged in to view this assessment.');
      }
    } catch (e) {
      developer.log(
        'AssessmentDetailPage: Error initializing user: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error initializing user data.');
    }
  }

  // Load assessment data
  Future<void> _loadAssessmentData() async {
    try {
      developer.log(
        'AssessmentDetailPage: Loading assessment data for ID: ${widget.assessmentId}',
        name: 'AssessmentDetailPage',
      );

      // Get assessment document from Firestore
      final assessmentDoc =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (!assessmentDoc.exists) {
        developer.log(
          'AssessmentDetailPage: Assessment not found',
          name: 'AssessmentDetailPage',
        );
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Assessment not found.');
        return;
      }

      // Get assessment data
      final assessmentData = assessmentDoc.data()!;
      _assessmentData = {'id': assessmentDoc.id, ...assessmentData};

      developer.log(
        'AssessmentDetailPage: Assessment data loaded: ${_assessmentData['title']}',
        name: 'AssessmentDetailPage',
      );

      // Check if this is a group assessment
      final userAssessmentDoc =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (userAssessmentDoc.exists) {
        final userAssessmentData = userAssessmentDoc.data() ?? {};
        if (userAssessmentData['wasSharedInGroup'] == true) {
          _assessmentData['wasSharedInGroup'] = true;

          // Find which group this assessment belongs to
          final sharedInGroups = userAssessmentData['sharedInGroups'] ?? [];
          developer.log(
            'AssessmentDetailPage: Assessment shared in groups: $sharedInGroups',
            name: 'AssessmentDetailPage',
          );

          for (var groupId in sharedInGroups) {
            final groupShareDoc =
                await _firestore
                    .collection('assessments')
                    .doc(widget.assessmentId)
                    .collection('sharedWithGroups')
                    .doc(groupId)
                    .get();

            if (groupShareDoc.exists) {
              _groupId = groupId;
              final groupShareData = groupShareDoc.data() ?? {};
              _assessmentData['groupShareData'] = groupShareData;
              _hasTimer = groupShareData['hasTimer'] ?? false;
              _timerDuration = groupShareData['timerDuration'] ?? 0;

              developer.log(
                'AssessmentDetailPage: Found group data - Group ID: $_groupId, hasTimer: $_hasTimer, timerDuration: $_timerDuration',
                name: 'AssessmentDetailPage',
              );
              break;
            }
          }
        }
      }

      // Load questions
      await _loadQuestions();

      // Load submissions
      await _loadSubmissions();

      // Update state
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      developer.log(
        'AssessmentDetailPage: Error loading assessment data: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading assessment data.');
    }
  }

  // Load questions
  Future<void> _loadQuestions() async {
    try {
      developer.log(
        'AssessmentDetailPage: Loading questions for assessment: ${widget.assessmentId}',
        name: 'AssessmentDetailPage',
      );

      // Get questions from Firestore
      final questionsSnapshot =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .collection('questions')
              .orderBy('orderIndex')
              .get();

      _questions = [];
      for (var doc in questionsSnapshot.docs) {
        _questions.add({'id': doc.id, ...doc.data()});
      }

      developer.log(
        'AssessmentDetailPage: Loaded ${_questions.length} questions',
        name: 'AssessmentDetailPage',
      );
    } catch (e) {
      developer.log(
        'AssessmentDetailPage: Error loading questions: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      _showErrorSnackBar('Error loading questions.');
    }
  }

  // Load submissions
  Future<void> _loadSubmissions() async {
    try {
      developer.log(
        'AssessmentDetailPage: Loading submissions for user: $_currentUserId, assessment: ${widget.assessmentId}',
        name: 'AssessmentDetailPage',
      );

      List<QueryDocumentSnapshot> submissionDocs;

      // Get user's submissions from Firestore
      if (_groupId != null) {
        // For group assessments, find the channel and get submissions
        developer.log(
          'AssessmentDetailPage: Fetching group submissions for group: $_groupId',
          name: 'AssessmentDetailPage',
        );

        final channelsSnapshot =
            await _firestore
                .collection('groups')
                .doc(_groupId)
                .collection('channels')
                .where('type', isEqualTo: 'assessment')
                .get();

        List<QueryDocumentSnapshot> allSubmissions = [];
        for (var channel in channelsSnapshot.docs) {
          developer.log(
            'AssessmentDetailPage: Checking channel: ${channel.id}',
            name: 'AssessmentDetailPage',
          );

          final subs =
              await channel.reference
                  .collection('assessments')
                  .doc(widget.assessmentId)
                  .collection('submissions')
                  .where('userId', isEqualTo: _currentUserId)
                  .orderBy('submittedAt', descending: true)
                  .get();

          allSubmissions.addAll(subs.docs);
        }
        submissionDocs = allSubmissions;
      } else {
        // For regular assessments, get from user's collection
        developer.log(
          'AssessmentDetailPage: Fetching user submissions',
          name: 'AssessmentDetailPage',
        );

        final submissionsSnapshot =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('submissions')
                .orderBy('submittedAt', descending: true)
                .get();

        submissionDocs = submissionsSnapshot.docs;
      }

      _userSubmissions = [];
      for (var doc in submissionDocs) {
        Map<String, dynamic> submissionData = {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };

        _userSubmissions.add(submissionData);

        // Check if this is an evaluated submission
        if (submissionData['status'] == 'evaluated') {
          if (_latestEvaluatedSubmission == null ||
              (submissionData['submittedAt'] != null &&
                  _latestEvaluatedSubmission!['submittedAt'] != null &&
                  submissionData['submittedAt'].toDate().isAfter(
                    _latestEvaluatedSubmission!['submittedAt'].toDate(),
                  ))) {
            _latestEvaluatedSubmission = submissionData;
          }
        }

        // Check if this is an in-progress submission
        if (submissionData['status'] == 'in-progress') {
          if (_currentSubmission == null ||
              (submissionData['startedAt'] != null &&
                  _currentSubmission!['startedAt'] != null &&
                  submissionData['startedAt'].toDate().isAfter(
                    _currentSubmission!['startedAt'].toDate(),
                  ))) {
            _currentSubmission = submissionData;
          }
        }
      }

      developer.log(
        'AssessmentDetailPage: Loaded ${_userSubmissions.length} submissions, in-progress: ${_currentSubmission != null}, evaluated: ${_latestEvaluatedSubmission != null}',
        name: 'AssessmentDetailPage',
      );

      // If there is an in-progress submission, load answers
      if (_currentSubmission != null) {
        await _loadAnswers(_currentSubmission!['id']);
      }
    } catch (e) {
      developer.log(
        'AssessmentDetailPage: Error loading submissions: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      _showErrorSnackBar('Error loading submissions.');
    }
  }

  // Load answers for a specific submission
  Future<void> _loadAnswers(String submissionId) async {
    try {
      developer.log(
        'AssessmentDetailPage: Loading answers for submission: $submissionId',
        name: 'AssessmentDetailPage',
      );

      List<QueryDocumentSnapshot> answerDocs;

      // Get answers from Firestore
      if (_groupId != null) {
        // For group assessments, find the channel and get answers
        final channelsSnapshot =
            await _firestore
                .collection('groups')
                .doc(_groupId)
                .collection('channels')
                .where('type', isEqualTo: 'assessment')
                .get();

        List<QueryDocumentSnapshot> allAnswers = [];
        for (var channel in channelsSnapshot.docs) {
          final answersSnapshot =
              await channel.reference
                  .collection('assessments')
                  .doc(widget.assessmentId)
                  .collection('submissions')
                  .doc(submissionId)
                  .collection('answers')
                  .get();

          if (answersSnapshot.docs.isNotEmpty) {
            allAnswers = answersSnapshot.docs;
            break;
          }
        }
        answerDocs = allAnswers;
      } else {
        // For regular assessments, get from user's collection
        final answersSnapshot =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('submissions')
                .doc(submissionId)
                .collection('answers')
                .get();

        answerDocs = answersSnapshot.docs;
      }

      _answers = {};
      for (var doc in answerDocs) {
        final answerData = doc.data() as Map<String, dynamic>;
        _answers[answerData['questionId']] = {'id': doc.id, ...answerData};
      }

      developer.log(
        'AssessmentDetailPage: Loaded ${_answers.length} answers',
        name: 'AssessmentDetailPage',
      );
    } catch (e) {
      developer.log(
        'AssessmentDetailPage: Error loading answers: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      _showErrorSnackBar('Error loading answers.');
    }
  }

  // Start a new assessment attempt
  Future<void> _startAssessment() async {
    try {
      setState(() {
        _isSubmitting = true;
      });

      developer.log(
        'AssessmentDetailPage: Starting new assessment attempt',
        name: 'AssessmentDetailPage',
      );

      // Create new submission document
      final submissionData = {
        'userId': _currentUserId,
        'startedAt': FieldValue.serverTimestamp(),
        'status': 'in-progress',
      };

      // Add user name if available
      final userDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        submissionData['userName'] = userData?['displayName'] ?? 'Unknown User';
      }

      // Save submission to appropriate location
      DocumentReference submissionRef;
      if (_groupId != null) {
        // For group assessments, find the channel and save there
        developer.log(
          'AssessmentDetailPage: Creating group submission for group: $_groupId',
          name: 'AssessmentDetailPage',
        );

        final channelsSnapshot =
            await _firestore
                .collection('groups')
                .doc(_groupId)
                .collection('channels')
                .where('type', isEqualTo: 'assessment')
                .limit(1)
                .get();

        if (channelsSnapshot.docs.isEmpty) {
          throw Exception('No assessment channel found for group');
        }

        submissionRef =
            channelsSnapshot.docs.first.reference
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('submissions')
                .doc();
      } else {
        // For regular assessments, save to user's collection
        developer.log(
          'AssessmentDetailPage: Creating user submission',
          name: 'AssessmentDetailPage',
        );

        submissionRef =
            _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('assessments')
                .doc(widget.assessmentId)
                .collection('submissions')
                .doc();
      }

      await submissionRef.set(submissionData);

      developer.log(
        'AssessmentDetailPage: Created new submission: ${submissionRef.id}',
        name: 'AssessmentDetailPage',
      );

      setState(() {
        _isSubmitting = false;
      });

      // Navigate to attempt page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => AssessmentAttemptPage(
                assessmentId: widget.assessmentId,
                submissionId: submissionRef.id,
                groupId: _groupId,
                hasTimer: _hasTimer,
                timerDuration: _timerDuration,
                questions: _questions,
              ),
        ),
      ).then((_) {
        // Reload data when returning from attempt page
        developer.log(
          'AssessmentDetailPage: Returned from attempt page, reloading data',
          name: 'AssessmentDetailPage',
        );

        setState(() {
          _isLoading = true;
        });
        _loadAssessmentData();
      });
    } catch (e) {
      developer.log(
        'AssessmentDetailPage: Error starting assessment: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      setState(() {
        _isSubmitting = false;
      });
      _showErrorSnackBar('Error starting assessment.');
    }
  }

  // Continue an in-progress assessment
  void _continueAssessment() {
    if (_currentSubmission == null) return;

    developer.log(
      'AssessmentDetailPage: Continuing assessment: ${_currentSubmission!['id']}',
      name: 'AssessmentDetailPage',
    );

    // Navigate to attempt page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AssessmentAttemptPage(
              assessmentId: widget.assessmentId,
              submissionId: _currentSubmission!['id'],
              groupId: _groupId,
              hasTimer: _hasTimer,
              timerDuration: _timerDuration,
              questions: _questions,
              answers: _answers,
              isResuming: true,
            ),
      ),
    ).then((_) {
      // Reload data when returning from attempt page
      developer.log(
        'AssessmentDetailPage: Returned from continue attempt page, reloading data',
        name: 'AssessmentDetailPage',
      );

      setState(() {
        _isLoading = true;
      });
      _loadAssessmentData();
    });
  }

  // View a specific submission
  void _viewSubmission(Map<String, dynamic> submission) {
    developer.log(
      'AssessmentDetailPage: Viewing submission: ${submission['id']}',
      name: 'AssessmentDetailPage',
    );

    // Navigate to attempt page in review mode
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AssessmentAttemptPage(
              assessmentId: widget.assessmentId,
              submissionId: submission['id'],
              groupId: _groupId,
              isReviewing: true,
              questions: _questions,
            ),
      ),
    );
  }

  // Share assessment
  Future<void> _shareAssessment() async {
    developer.log(
      'AssessmentDetailPage: Sharing assessment: ${widget.assessmentId}',
      name: 'AssessmentDetailPage',
    );

    try {
      // Generate a dynamic link or a deep link
      final String shareText =
          'Check out this assessment: ${_assessmentData['title']}\n\n'
          'Difficulty: ${_assessmentData['difficulty']}\n'
          'Total Points: ${_assessmentData['totalPoints']}\n\n'
          'Open in the app to view and attempt!';

      await Share.share(shareText, subject: 'Check out this assessment!');

      developer.log(
        'AssessmentDetailPage: Assessment shared successfully',
        name: 'AssessmentDetailPage',
      );
    } catch (e) {
      developer.log(
        'AssessmentDetailPage: Error sharing assessment: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      _showErrorSnackBar('Error sharing assessment.');
    }
  }

  // Format timestamp helpers
  String _formatTimestamp(dynamic timestamp, {bool includeTime = true}) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      return '';
    }

    if (includeTime) {
      return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '';

    final int totalSeconds =
        seconds is int ? seconds : int.tryParse(seconds.toString()) ?? 0;
    final int minutes = totalSeconds ~/ 60;
    final int remainingSeconds = totalSeconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Helper method to get color based on difficulty
  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return const Color(0xFF43E97B); // Green
      case 'medium':
        return const Color(0xFFFF9E40); // Orange
      case 'hard':
        return const Color(0xFFFF6584); // Red
      case 'expert':
        return const Color(0xFF6C63FF); // Purple
      default:
        return const Color(0xFF6C63FF); // Purple default
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    developer.log(
      'AssessmentDetailPage: Showing error: $message',
      name: 'AssessmentDetailPage',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    developer.log(
      'AssessmentDetailPage: Building UI, loading: $_isLoading',
      name: 'AssessmentDetailPage',
    );

    return Scaffold(body: _isLoading ? _buildLoadingState() : _buildContent());
  }

  // Build loading state
  Widget _buildLoadingState() {
    return Container(
      color: Colors.grey.shade50,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shimmer effect loader
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Colors.grey.shade600,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading Assessment...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build main content
  Widget _buildContent() {
    // Get color based on difficulty
    final String difficulty = _assessmentData['difficulty'] ?? 'Medium';
    final Color difficultyColor = _getDifficultyColor(difficulty);

    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.grey.shade50,
        child: Stack(
          children: [
            // Main content
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App bar
                _buildAppBar(difficultyColor),

                // Header section
                _buildHeader(difficultyColor),

                // Tab bar
                _buildTabBar(difficultyColor),

                // Tab content
                _buildTabContent(difficultyColor),

                // Bottom padding for FAB
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120 + MediaQuery.of(context).padding.bottom,
                  ),
                ),
              ],
            ),

            // Action button
            _buildActionButton(difficultyColor),
          ],
        ),
      ),
    );
  }

  // Build app bar
  Widget _buildAppBar(Color primaryColor) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 70,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.arrow_back, color: primaryColor, size: 20),
          ),
        ),
      ),
      actions: [
        // Share button
        GestureDetector(
          onTap: _shareAssessment,
          child: Container(
            margin: const EdgeInsets.only(right: 20, top: 8, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.share, color: primaryColor, size: 20),
          ),
        ),
      ],
      toolbarHeight: 70,
    );
  }

  // Build header section
  Widget _buildHeader(Color primaryColor) {
    final bool isCreator = _assessmentData['creatorId'] == _currentUserId;
    final String creatorName = _assessmentData['creatorName'] ?? 'Unknown';
    final bool isAiGenerated = _assessmentData['madeByAI'] == true;
    final int points = _assessmentData['totalPoints'] ?? 0;
    final double rating = (_assessmentData['rating'] ?? 0.0).toDouble();

    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeInController,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                _assessmentData['title'] ?? 'Untitled Assessment',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 16),

              // Metadata row
              Row(
                children: [
                  // Creator avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isCreator ? Icons.person : Icons.person_outline,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Creator name and date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCreator
                              ? 'Created by you'
                              : 'Created by $creatorName',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimestamp(_assessmentData['createdAt']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // AI generated badge
                  if (isAiGenerated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Colors.purple,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // Stats row
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _slideController,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Difficulty stat
                      _buildStatItem(
                        icon: Icons.signal_cellular_alt,
                        label: 'Difficulty',
                        value: _assessmentData['difficulty'] ?? 'Medium',
                        valueColor: primaryColor,
                      ),

                      // Divider
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),

                      // Points stat
                      _buildStatItem(
                        icon: Icons.star,
                        label: 'Points',
                        value: '$points',
                        valueColor: Colors.amber.shade700,
                      ),

                      // Divider
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.shade200,
                      ),

                      // Rating stat
                      _buildStatItem(
                        icon: Icons.thumb_up,
                        label: 'Rating',
                        value: rating > 0 ? rating.toStringAsFixed(1) : '-',
                        valueColor: Colors.blue.shade600,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Build stat item
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // Build tab bar
  Widget _buildTabBar(Color primaryColor) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          tabs:
              _tabs.map((tab) {
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tab['icon'], size: 18),
                      const SizedBox(width: 8),
                      Text(tab['label']),
                    ],
                  ),
                );
              }).toList(),
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey.shade700,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
      ),
    );
  }

  // Build tab content
  Widget _buildTabContent(Color primaryColor) {
    return SliverFillRemaining(
      fillOverscroll: true,
      hasScrollBody: false,
      child: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          // Overview tab
          _buildOverviewTab(primaryColor),

          // Questions tab
          _buildQuestionsTab(primaryColor),

          // Submissions tab
          _buildSubmissionsTab(primaryColor),

          // Results tab
          _buildResultsTab(primaryColor),
        ],
      ),
    );
  }

  // Build overview tab
  Widget _buildOverviewTab(Color primaryColor) {
    final String description =
        _assessmentData['description'] ?? 'No description available.';

    // Get timer info if available
    final bool hasTimer =
        _hasTimer || (_assessmentData['groupShareData']?['hasTimer'] == true);
    final int timerDuration =
        _timerDuration > 0
            ? _timerDuration
            : (_assessmentData['groupShareData']?['timerDuration'] ?? 0);

    // Get deadline if available
    final dynamic endTime = _assessmentData['groupShareData']?['endTime'];

    // Get tags if available
    final List<dynamic> tags = _assessmentData['tags'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section title
                Row(
                  children: [
                    Icon(Icons.description, color: primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description text
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Time constraints section
          if (hasTimer || endTime != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  Row(
                    children: [
                      Icon(Icons.timer, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Time Constraints',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Time limit if available
                  if (hasTimer && timerDuration > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.hourglass_bottom,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time Limit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${timerDuration ~/ 60} minutes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Deadline if available
                  if (endTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.event,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deadline',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(endTime),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
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

          if (hasTimer || endTime != null) const SizedBox(height: 24),

          // Tags section
          if (tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  Row(
                    children: [
                      Icon(Icons.tag, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Tags',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tags wrap
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        tags.map<Widget>((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),

          if (tags.isNotEmpty) const SizedBox(height: 24),

          // Stats section - questions, total points
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section title
                Row(
                  children: [
                    Icon(Icons.analytics, color: primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Assessment Stats',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Questions count
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.question_answer,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Questions',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_questions.length}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Points total
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber.shade700,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Points',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_assessmentData['totalPoints'] ?? 0}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Submissions count
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Attempts',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_userSubmissions.length}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build questions tab
  Widget _buildQuestionsTab(Color primaryColor) {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.question_mark, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No questions available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This assessment doesn\'t have any questions yet.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Questions (${_questions.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Start the assessment to view and answer questions.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 24),

          // Questions list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];
              return _buildQuestionPreviewCard(question, index, primaryColor);
            },
          ),
        ],
      ),
    );
  }

  // Build question preview card
  Widget _buildQuestionPreviewCard(
    Map<String, dynamic> question,
    int index,
    Color primaryColor,
  ) {
    final String questionType = question['questionType'] ?? 'unknown';
    final int points = question['points'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Question number
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Question ${index + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),

                // Points
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$points pts',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question preview (blurred)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Blurred text
                      Text(
                        question['questionText'] ??
                            'No question text available',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Blur overlay
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                          child: Container(
                            color: Colors.white.withOpacity(0.5),
                            width: double.infinity,
                            height: 60,
                          ),
                        ),
                      ),

                      // Lock icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Question type
                Row(
                  children: [
                    Icon(
                      _getQuestionTypeIcon(questionType),
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatQuestionType(questionType),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Get question type icon
  IconData _getQuestionTypeIcon(String questionType) {
    switch (questionType.toLowerCase()) {
      case 'multiple-choice':
        return Icons.check_box;
      case 'single-choice':
        return Icons.radio_button_checked;
      case 'short-answer':
        return Icons.short_text;
      case 'essay':
        return Icons.text_fields;
      case 'true-false':
        return Icons.rule;
      case 'matching':
        return Icons.compare_arrows;
      case 'fill-blank':
        return Icons.text_format;
      default:
        return Icons.question_answer;
    }
  }

  // Format question type
  String _formatQuestionType(String questionType) {
    switch (questionType.toLowerCase()) {
      case 'multiple-choice':
        return 'Multiple Choice';
      case 'single-choice':
        return 'Single Choice';
      case 'short-answer':
        return 'Short Answer';
      case 'essay':
        return 'Essay';
      case 'true-false':
        return 'True/False';
      case 'matching':
        return 'Matching';
      case 'fill-blank':
        return 'Fill in the Blank';
      default:
        return questionType;
    }
  }

  // Build submissions tab
  Widget _buildSubmissionsTab(Color primaryColor) {
    if (_userSubmissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No submissions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start the assessment to record your first submission.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Your Submissions (${_userSubmissions.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 24),

          // Submissions list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userSubmissions.length,
            itemBuilder: (context, index) {
              final submission = _userSubmissions[index];
              return _buildSubmissionCard(submission, index, primaryColor);
            },
          ),
        ],
      ),
    );
  }

  // Build submission card
  Widget _buildSubmissionCard(
    Map<String, dynamic> submission,
    int index,
    Color primaryColor,
  ) {
    final String status = submission['status'] ?? 'in-progress';
    final dynamic startedAt = submission['startedAt'];
    final dynamic submittedAt = submission['submittedAt'];
    final int score = submission['totalScore'] ?? 0;
    final int totalPoints = _assessmentData['totalPoints'] ?? 100;
    final double percentage = totalPoints > 0 ? (score / totalPoints * 100) : 0;
    final String durationText =
        startedAt != null && submittedAt != null
            ? _formatSubmissionDuration(startedAt, submittedAt)
            : '';

    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'in-progress':
        statusColor = Colors.blue;
        statusIcon = Icons.edit;
        statusText = 'In Progress';
        break;
      case 'submitted':
        statusColor = Colors.orange;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Submitted';
        break;
      case 'evaluated':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Evaluated';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown';
    }

    return GestureDetector(
      onTap: () => _viewSubmission(submission),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Attempt number
                  Text(
                    'Attempt ${_userSubmissions.length - index}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timestamps row
                  Row(
                    children: [
                      // Started at
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(startedAt),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Submitted at (if available)
                      if (submittedAt != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Submitted',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(submittedAt),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Duration (if submission completed)
                  if (durationText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: $durationText',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Score (if evaluated)
                  if (status == 'evaluated') ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Score text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Score: $score / $totalPoints',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Score progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey.shade200,
                              color: _getScoreColor(percentage),
                              minHeight: 8,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Percentage
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _getScoreColor(percentage),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // View details button
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _viewSubmission(submission),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == 'in-progress'
                                ? Icons.edit
                                : Icons.visibility,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status == 'in-progress'
                                ? 'Continue'
                                : 'View Details',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }

  // Format submission duration
  String _formatSubmissionDuration(dynamic startedAt, dynamic submittedAt) {
    if (startedAt == null || submittedAt == null) return '';

    DateTime startTime;
    DateTime endTime;

    if (startedAt is Timestamp) {
      startTime = startedAt.toDate();
    } else {
      return '';
    }

    if (submittedAt is Timestamp) {
      endTime = submittedAt.toDate();
    } else {
      return '';
    }

    final difference = endTime.difference(startTime);

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (hours > 0) {
      return '$hours hr ${minutes.toString().padLeft(2, '0')} min';
    } else {
      return '$minutes min ${seconds.toString().padLeft(2, '0')} sec';
    }
  }

  // Get score color based on percentage
  Color _getScoreColor(double percentage) {
    if (percentage >= 80) {
      return Colors.green.shade600;
    } else if (percentage >= 70) {
      return Colors.lightGreen.shade600;
    } else if (percentage >= 60) {
      return Colors.amber.shade600;
    } else if (percentage >= 50) {
      return Colors.orange.shade600;
    } else {
      return Colors.red.shade600;
    }
  }

  // Build results tab
  Widget _buildResultsTab(Color primaryColor) {
    // Check if there's an evaluated submission
    if (_latestEvaluatedSubmission == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assessment, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No results available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Complete the assessment to see your results.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Get score data
    final int score = _latestEvaluatedSubmission!['totalScore'] ?? 0;
    final int totalPoints = _assessmentData['totalPoints'] ?? 100;
    final double percentage = totalPoints > 0 ? (score / totalPoints * 100) : 0;
    final String feedback =
        _latestEvaluatedSubmission!['overallFeedback'] ?? '';
    final Timestamp? evaluatedAt = _latestEvaluatedSubmission!['evaluatedAt'];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Assessment Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Your latest evaluated submission',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 24),

          // Score card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Score circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _getScoreColor(percentage).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getScoreColor(percentage),
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(percentage),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$score / $totalPoints',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Grade text
                Text(
                  _getGradeText(percentage),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(percentage),
                  ),
                ),

                const SizedBox(height: 8),

                // Evaluated date
                if (evaluatedAt != null) ...[
                  Text(
                    'Evaluated on ${_formatTimestamp(evaluatedAt)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                ],

                // View details button
                ElevatedButton(
                  onPressed: () => _viewSubmission(_latestEvaluatedSubmission!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getScoreColor(percentage),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.assessment, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'View Detailed Results',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Feedback section (if available)
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
                  Row(
                    children: [
                      Icon(Icons.feedback, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Feedback',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Feedback text
                  Text(
                    feedback,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Performance stats
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section title
                Row(
                  children: [
                    Icon(Icons.insights, color: primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Performance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Performance stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Attempts stats
                    _buildResultsStat(
                      icon: Icons.repeat,
                      label: 'Attempts',
                      value: '${_userSubmissions.length}',
                      color: Colors.blue.shade600,
                    ),

                    // Best score
                    _buildResultsStat(
                      icon: Icons.emoji_events,
                      label: 'Best Score',
                      value: '${percentage.toStringAsFixed(0)}%',
                      color: _getScoreColor(percentage),
                    ),

                    // Time spent
                    _buildResultsStat(
                      icon: Icons.access_time,
                      label: 'Last Duration',
                      value: _formatSubmissionDuration(
                        _latestEvaluatedSubmission!['startedAt'],
                        _latestEvaluatedSubmission!['submittedAt'],
                      ),
                      color: Colors.purple.shade600,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build results stat item
  Widget _buildResultsStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(child: Icon(icon, color: color, size: 24)),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Get grade text based on percentage
  String _getGradeText(double percentage) {
    if (percentage >= 90) {
      return 'Excellent!';
    } else if (percentage >= 80) {
      return 'Great Job!';
    } else if (percentage >= 70) {
      return 'Good Work!';
    } else if (percentage >= 60) {
      return 'Satisfactory';
    } else if (percentage >= 50) {
      return 'Needs Improvement';
    } else {
      return 'Try Again';
    }
  }

  // Build action button
  Widget _buildActionButton(Color primaryColor) {
    // Determine button text and color based on current state
    String buttonText;
    Color buttonColor;
    IconData buttonIcon;
    VoidCallback onPressed;

    if (_currentSubmission != null) {
      // Has in-progress submission
      buttonText = 'Continue Assessment';
      buttonColor = Colors.blue.shade600;
      buttonIcon = Icons.edit;
      onPressed = _continueAssessment;
    } else {
      // Start new assessment
      buttonText = 'Start Assessment';
      buttonColor = primaryColor;
      buttonIcon = Icons.play_arrow;
      onPressed = _startAssessment;
    }

    return Positioned(
      bottom: 20 + MediaQuery.of(context).padding.bottom,
      left: 0,
      right: 0,
      child: Center(
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
            CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: buttonColor.withOpacity(0.4),
              ),
              child:
                  _isSubmitting
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(buttonIcon),
                          const SizedBox(width: 12),
                          Text(
                            buttonText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

// Custom tab bar delegate
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, {this.backgroundColor = Colors.white});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

// Placeholder for AssessmentAttemptPage
class AssessmentAttemptPage extends StatelessWidget {
  final String assessmentId;
  final String submissionId;
  final String? groupId;
  final bool hasTimer;
  final int timerDuration;
  final List<Map<String, dynamic>> questions;
  final Map<String, dynamic>? answers;
  final bool isResuming;
  final bool isReviewing;

  const AssessmentAttemptPage({
    Key? key,
    required this.assessmentId,
    required this.submissionId,
    this.groupId,
    this.hasTimer = false,
    this.timerDuration = 0,
    required this.questions,
    this.answers,
    this.isResuming = false,
    this.isReviewing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This is a placeholder - you would implement a proper assessment attempt page
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Attempt')),
      body: Center(
        child: Text(
          'Assessment Attempt Page - ${isReviewing
              ? 'Reviewing'
              : isResuming
              ? 'Resuming'
              : 'Starting'} submission $submissionId',
        ),
      ),
    );
  }
}
