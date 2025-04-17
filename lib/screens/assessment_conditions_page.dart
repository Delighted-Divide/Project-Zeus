import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'quiz_page.dart';

class AssessmentConditionsPage extends StatefulWidget {
  final String assessmentId;
  final String? groupName;

  const AssessmentConditionsPage({
    super.key,
    required this.assessmentId,
    this.groupName,
  });

  @override
  AssessmentConditionsPageState createState() =>
      AssessmentConditionsPageState();
}

class AssessmentConditionsPageState extends State<AssessmentConditionsPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _assessmentData;
  Map<String, dynamic>? _groupShareData;
  bool _wasSharedInGroup = false;
  bool _isConditionsEditable = false;

  bool _hasTimer = false;
  int _timerDuration = 60;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _loadAssessmentData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAssessmentData() async {
    developer.log(
      'AssessmentConditionsPage: Loading assessment data for ID: ${widget.assessmentId}',
    );

    try {
      final String? currentUserId = _auth.currentUser?.uid;

      if (currentUserId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "You must be logged in to view this assessment.";
        });
        return;
      }

      final userAssessmentDoc =
          await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (!userAssessmentDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Assessment not found in your collection.";
        });
        return;
      }

      final userAssessmentData = userAssessmentDoc.data() ?? {};

      final bool wasSharedInGroup =
          userAssessmentData['wasSharedInGroup'] == true;

      final mainAssessmentDoc =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (!mainAssessmentDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Assessment not found.";
        });
        return;
      }

      final mainAssessmentData = mainAssessmentDoc.data() ?? {};

      Map<String, dynamic> assessmentData = {
        'id': widget.assessmentId,
        'title':
            userAssessmentData['title'] ??
            mainAssessmentData['title'] ??
            'Untitled Assessment',
        'description':
            mainAssessmentData['description'] ?? 'No description available',
        'difficulty': mainAssessmentData['difficulty'] ?? 'Medium',
        'totalPoints': mainAssessmentData['totalPoints'] ?? 0,
        'wasSharedInGroup': wasSharedInGroup,
        'isCreator': mainAssessmentData['creatorId'] == currentUserId,
        'madeByAI': mainAssessmentData['madeByAI'] ?? false,
      };

      Map<String, dynamic>? groupShareData;

      if (wasSharedInGroup) {
        if (widget.groupName != null) {
          final userGroupsSnapshot =
              await _firestore
                  .collection('users')
                  .doc(currentUserId)
                  .collection('groups')
                  .get();

          String? targetGroupId;

          for (var groupDoc in userGroupsSnapshot.docs) {
            if (groupDoc.data()['name'] == widget.groupName) {
              targetGroupId = groupDoc.id;
              break;
            }
          }

          if (targetGroupId != null) {
            final groupShareDoc =
                await _firestore
                    .collection('assessments')
                    .doc(widget.assessmentId)
                    .collection('sharedWithGroups')
                    .doc(targetGroupId)
                    .get();

            if (groupShareDoc.exists) {
              groupShareData = groupShareDoc.data();
              groupShareData?['groupId'] = targetGroupId;
              groupShareData?['groupName'] = widget.groupName;
            }
          }
        }

        if (groupShareData == null) {
          final groupSharesSnapshot =
              await _firestore
                  .collection('assessments')
                  .doc(widget.assessmentId)
                  .collection('sharedWithGroups')
                  .limit(1)
                  .get();

          if (groupSharesSnapshot.docs.isNotEmpty) {
            final groupShareDoc = groupSharesSnapshot.docs.first;
            groupShareData = groupShareDoc.data();
            groupShareData['groupId'] = groupShareDoc.id;

            final groupDoc =
                await _firestore
                    .collection('groups')
                    .doc(groupShareDoc.id)
                    .get();

            if (groupDoc.exists) {
              groupShareData['groupName'] =
                  groupDoc.data()?['name'] ?? 'Unknown Group';
            } else {
              groupShareData['groupName'] = 'Unknown Group';
            }
          }
        }
      }

      _animationController.forward();

      setState(() {
        _assessmentData = assessmentData;
        _groupShareData = groupShareData;
        _wasSharedInGroup = wasSharedInGroup;
        _isConditionsEditable = !wasSharedInGroup;

        if (groupShareData != null) {
          _hasTimer = groupShareData['hasTimer'] ?? false;
          _timerDuration = groupShareData['timerDuration'] ?? 60;
        }

        _isLoading = false;
      });
    } catch (e) {
      developer.log(
        'AssessmentConditionsPage: Error loading assessment data: $e',
        name: 'AssessmentConditionsPage',
        error: e,
      );

      setState(() {
        _isLoading = false;
        _errorMessage = "Error loading assessment data. Please try again.";
      });
    }
  }

  void _startAssessment() {
    Map<String, dynamic> conditions = {
      'hasTimer': _hasTimer,
      'timerDuration': _timerDuration,
    };

    if (_wasSharedInGroup && _groupShareData != null) {
      conditions['groupId'] = _groupShareData!['groupId'];
      conditions['groupName'] = _groupShareData!['groupName'];
      conditions['startTime'] = _groupShareData!['startTime'];
      conditions['endTime'] = _groupShareData!['endTime'];
    }

    developer.log(
      'AssessmentConditionsPage: Starting assessment with conditions: $conditions',
      name: 'AssessmentConditionsPage',
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => QuizPage(
              assessmentId: _assessmentData!['id'],
              groupName: conditions['groupName'],
              timerDuration: _hasTimer ? _timerDuration : null,
            ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF4CAF50);
      case 'medium':
        return const Color(0xFFFFA726);
      case 'hard':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  String _getDifficultyEmoji(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return '😊';
      case 'medium':
        return '😐';
      case 'hard':
        return '😓';
      default:
        return '🤔';
    }
  }

  @override
  Widget build(BuildContext context) {
    final LinearGradient primaryGradient = const LinearGradient(
      colors: [Color(0xFF7F51E6), Color(0xFF5E72EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? _buildLoadingState(primaryGradient)
              : _errorMessage != null
              ? _buildErrorState(primaryGradient)
              : _buildMainContent(primaryGradient),
    );
  }

  Widget _buildLoadingState(LinearGradient primaryGradient) {
    return Container(
      decoration: BoxDecoration(color: Colors.white),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: primaryGradient,
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(
                    color: primaryGradient.colors.first.withAlpha(
                      (0.3 * 255).round(),
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          primaryGradient.colors.first,
                        ),
                        strokeWidth: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Preparing Your Assessment',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryGradient.colors.first,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              child: Text(
                'We\'re setting up everything you need for a great learning experience.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(LinearGradient primaryGradient) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
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
                child: Icon(Icons.arrow_back, color: Colors.grey[800]),
              ),
            ),

            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red[400],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Oops! Something went wrong',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      child: Text(
                        _errorMessage ?? 'Unknown error occurred',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGradient.colors.first,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                      ),
                      child: Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(LinearGradient primaryGradient) {
    final String difficulty = _assessmentData?['difficulty'] ?? 'Medium';
    _getDifficultyColor(difficulty);
    final bool isAiGenerated = _assessmentData?['madeByAI'] ?? false;

    bool isLocked = false;
    String? lockReason;

    if (_wasSharedInGroup &&
        _groupShareData != null &&
        _groupShareData!['startTime'] != null) {
      final startTime = _groupShareData!['startTime'].toDate();
      if (startTime.isAfter(DateTime.now())) {
        isLocked = true;
        lockReason =
            'This assessment will be available on ${_formatTimestamp(_groupShareData!['startTime'])}';
      }
    }

    return SafeArea(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryGradient.colors.first.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        'Assessment Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 42),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _assessmentData?['title'] ??
                                      'Untitled Assessment',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _assessmentData?['description'] ??
                                      'No description available',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      if (isAiGenerated)
                        Container(
                          margin: const EdgeInsets.only(left: 12, top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'AI Generated',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Row(
                        children: [
                          _buildInfoBadge(
                            _getDifficultyEmoji(difficulty),
                            difficulty,
                            Colors.white.withOpacity(0.2),
                            Colors.white,
                          ),
                          const SizedBox(width: 12),

                          _buildInfoBadge(
                            '🏆',
                            '${_assessmentData?['totalPoints'] ?? 0} Points',
                            Colors.white.withOpacity(0.2),
                            Colors.white,
                          ),

                          if (_wasSharedInGroup && _groupShareData != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: _buildInfoBadge(
                                '👥',
                                'Group Assessment',
                                Colors.white.withOpacity(0.2),
                                Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_wasSharedInGroup && _groupShareData != null)
                        _buildGroupNotice(primaryGradient),

                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildMotivationCard(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Text(
                            'Assessment Conditions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildTimerSettings(primaryGradient),
                        ),
                      ),

                      if (_wasSharedInGroup &&
                          _groupShareData != null &&
                          (_groupShareData!['startTime'] != null ||
                              _groupShareData!['endTime'] != null))
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildTimeConstraints(primaryGradient),
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      if (isLocked && lockReason != null)
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildLockWarning(lockReason, primaryGradient),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: isLocked ? null : _startAssessment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isLocked
                              ? Colors.grey[300]
                              : primaryGradient.colors.first,
                      foregroundColor: Colors.white,
                      elevation: isLocked ? 0 : 2,
                      shadowColor:
                          isLocked
                              ? null
                              : primaryGradient.colors.first.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLocked ? Icons.lock : Icons.play_arrow,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLocked ? 'Assessment Locked' : 'Start Assessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupNotice(LinearGradient primaryGradient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryGradient.colors.first.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryGradient.colors.first.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGradient.colors.first.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.group,
              color: primaryGradient.colors.first,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Group Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryGradient.colors.first,
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryGradient.colors.first,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _groupShareData!['groupName'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'This assessment was shared in your group. The settings below were determined by the instructor.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFB347), Color(0xFFFFCC33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFB347).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Begin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Take a deep breath and focus',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Trust your preparation. We believe in your abilities!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTimerSettings(LinearGradient primaryGradient) {
    final Color timerColor = _hasTimer ? Color(0xFF4CAF50) : Colors.grey[400]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          _hasTimer
                              ? Color(0xFF4CAF50).withOpacity(0.1)
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.timer,
                      color: _hasTimer ? Color(0xFF4CAF50) : Colors.grey[400],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time Limit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        _hasTimer
                            ? 'Time restriction enabled'
                            : 'No time restriction',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),

              _isConditionsEditable
                  ? Switch(
                    value: _hasTimer,
                    onChanged: (value) {
                      setState(() {
                        _hasTimer = value;
                      });
                    },
                    activeColor: Color(0xFF4CAF50),
                    activeTrackColor: Color(0xFF4CAF50).withOpacity(0.3),
                  )
                  : Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _hasTimer
                              ? Color(0xFF4CAF50).withOpacity(0.1)
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _hasTimer ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        color: _hasTimer ? Color(0xFF4CAF50) : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
            ],
          ),

          if (_hasTimer) ...[
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Duration:',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: timerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: timerColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _formatDuration(_timerDuration),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: timerColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_isConditionsEditable) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '10min',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '3hr',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '6hr',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  activeTrackColor: timerColor,
                  inactiveTrackColor: Colors.grey[200],
                  thumbColor: Colors.white,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayColor: timerColor.withOpacity(0.2),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 20),
                ),
                child: Slider(
                  min: 10,
                  max: 360,
                  divisions: 35,
                  value: _timerDuration.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _timerDuration = value.round();
                    });
                  },
                ),
              ),
            ] else ...[
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _timerDuration / 360,
                  child: Container(
                    decoration: BoxDecoration(
                      color: timerColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isConditionsEditable
                          ? 'You can adjust the time limit based on your comfort level.'
                          : 'This time limit was set by your instructor and cannot be changed.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeConstraints(LinearGradient primaryGradient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.event_note,
                  color: Colors.blue[400],
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Schedule Restrictions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_groupShareData!['startTime'] != null ||
              _groupShareData!['endTime'] != null) ...[
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  if (_groupShareData!['startTime'] != null)
                    Expanded(
                      child: _buildTimelinePoint(
                        'Available From',
                        _formatTimestamp(_groupShareData!['startTime']),
                        Icons.play_arrow,
                        Colors.blue[400]!,
                        isStart: true,
                        isEnd: _groupShareData!['endTime'] == null,
                      ),
                    ),

                  if (_groupShareData!['startTime'] != null &&
                      _groupShareData!['endTime'] != null)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        height: 2,
                        color: Colors.grey[300],
                      ),
                    ),

                  if (_groupShareData!['endTime'] != null)
                    Expanded(
                      child: _buildTimelinePoint(
                        'Due By',
                        _formatTimestamp(_groupShareData!['endTime']),
                        Icons.flag,
                        Colors.red[400]!,
                        isStart: _groupShareData!['startTime'] == null,
                        isEnd: true,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These schedule restrictions were set by your instructor and cannot be changed.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelinePoint(
    String label,
    String timeText,
    IconData icon,
    Color color, {
    required bool isStart,
    required bool isEnd,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.5), width: 2),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          timeText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildLockWarning(String message, LinearGradient primaryGradient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.lock_clock, color: Colors.amber[800], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assessment Not Yet Available',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(fontSize: 14, color: Colors.amber[900]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(
    String emoji,
    String label,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '$hours ${hours == 1 ? 'hour' : 'hours'} $remainingMinutes ${remainingMinutes == 1 ? 'minute' : 'minutes'}';
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      return '';
    }

    final day = dateTime.day.toString().padLeft(2, '0');
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[dateTime.month - 1];
    final year = dateTime.year;

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year at $hour:$minute $period';
  }
}
