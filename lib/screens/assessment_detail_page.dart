import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

class AssessmentDetailPage extends StatefulWidget {
  final String assessmentId;

  const AssessmentDetailPage({super.key, required this.assessmentId});

  @override
  State<AssessmentDetailPage> createState() => _AssessmentDetailPageState();
}

class _AssessmentDetailPageState extends State<AssessmentDetailPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _animationController;

  bool _isLoading = true;
  Map<String, dynamic> _assessmentData = {};
  int _participantsCount = 0;
  Map<String, int> _questionTypeCount = {};
  int _totalQuestions = 0;
  bool _isCreator = false;
  String? _sourceDocumentUrl;
  bool _isSourceButtonPressed = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _loadAssessmentData().then((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAssessmentData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String? currentUserId = _auth.currentUser?.uid;

      final assessmentDoc =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .get();

      if (!assessmentDoc.exists) {
        throw 'Assessment not found';
      }

      final assessmentData = assessmentDoc.data() ?? {};

      final bool isCreator = assessmentData['creatorId'] == currentUserId;

      final questionsSnapshot =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .collection('questions')
              .get();

      final Map<String, int> questionTypeCount = {};
      for (var doc in questionsSnapshot.docs) {
        final String type = doc.data()['questionType'] ?? 'unknown';
        questionTypeCount[type] = (questionTypeCount[type] ?? 0) + 1;
      }

      final sharedWithUsersSnapshot =
          await _firestore
              .collection('assessments')
              .doc(widget.assessmentId)
              .collection('sharedWithUsers')
              .get();

      String sourceDocUrl =
          "https://firebasestorage.googleapis.com/v0/b/attempt1-314eb.firebasestorage.app/o/pdfs%2F7ZEp4JqUB8cDIMjE5jTDdmYbXFZ2%2Flech205.pdf?alt=media&token=00fee7b8-901c-47ca-9f6e-19c02962114c";

      if (mounted) {
        setState(() {
          _assessmentData = assessmentData;
          _questionTypeCount = questionTypeCount;
          _totalQuestions = questionsSnapshot.docs.length;
          _participantsCount = sharedWithUsersSnapshot.docs.length;
          _isCreator = isCreator;
          _sourceDocumentUrl = sourceDocUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log(
        'Error loading assessment data: $e',
        name: 'AssessmentDetailPage',
        error: e,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openSourceDocument() async {
    setState(() {
      _isSourceButtonPressed = true;
    });

    try {
      if (_sourceDocumentUrl == null) {
        throw 'Source document URL is not available';
      }

      final Uri url = Uri.parse(_sourceDocumentUrl!);
      if (!url.toString().toLowerCase().contains('.pdf')) {
        throw 'Invalid PDF URL';
      }

      if (await canLaunchUrl(url)) {
        final bool launched = await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );

        if (!launched) {
          await launchUrl(url, mode: LaunchMode.platformDefault);
        }
      } else {
        _showSnackBar('Could not open document - URL cannot be launched');
      }
    } catch (e) {
      _showSnackBar('Error opening document: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isSourceButtonPressed = false;
        });
      }
    }
  }

  void _startAssessment() {
    HapticFeedback.mediumImpact();
    _showSnackBar('Starting assessment...');
  }

  void _showSnackBar(String message) {
    final primaryColor = _getDifficultyColor(
      _assessmentData['difficulty'] as String?,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final date = timestamp.toDate();
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return const Color(0xFF43E97B);
      case 'medium':
        return const Color(0xFFFF9E40);
      case 'hard':
        return const Color(0xFFFF6584);
      case 'expert':
        return const Color(0xFF6C63FF);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  (IconData, Color) _getQuestionTypeInfo(String type) {
    switch (type.toLowerCase()) {
      case 'multiple-choice':
        return (Icons.check_circle_outline, Colors.blue);
      case 'multiple-answer':
        return (Icons.check_box_outlined, Colors.indigo);
      case 'true-false':
        return (Icons.toggle_on_outlined, Colors.green);
      case 'fill-in-the-blank':
        return (Icons.text_fields_outlined, Colors.blueGrey);
      case 'short-answer':
        return (Icons.short_text, Colors.orange);
      case 'long-answer':
        return (Icons.notes_outlined, Colors.purple);
      case 'match-the-following':
        return (Icons.compare_arrows, Colors.amber);
      default:
        return (Icons.help_outline, Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        _isLoading
            ? const Color(0xFF6C63FF)
            : _getDifficultyColor(_assessmentData['difficulty'] as String?);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back, color: primaryColor, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? _buildLoadingState(primaryColor)
              : _buildContentState(primaryColor),
      bottomNavigationBar:
          _isLoading ? null : _buildBottomActionBar(primaryColor),
    );
  }

  Widget _buildLoadingState(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor.withAlpha(204), primaryColor.withAlpha(51)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) {
                return SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: value * 2 * 3.14159,
                        child: CircularProgressIndicator(
                          value: null,
                          strokeWidth: 5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withAlpha(230),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: -value * 3 * 3.14159,
                        child: CircularProgressIndicator(
                          value: null,
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withAlpha(179),
                          ),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withAlpha(76),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: primaryColor,
                          size: 35,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Loading Assessment',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _buildLoadingDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return StatefulBuilder(
      builder: (context, setState) {
        final now = DateTime.now();
        final dotCount = (now.millisecondsSinceEpoch / 500).round() % 4;

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() {});
        });

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    index < dotCount
                        ? Colors.white
                        : Colors.white.withAlpha(77),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildContentState(Color primaryColor) {
    final title = _assessmentData['title'] ?? 'Untitled Assessment';
    final description =
        _assessmentData['description'] ?? 'No description available';
    final isAI = _assessmentData['madeByAI'] == true;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.2, 0.8],
                colors: [
                  primaryColor.withOpacity(0.1),
                  Colors.white.withOpacity(0.95),
                  Colors.white,
                ],
              ),
            ),
            child: CustomPaint(
              painter: PatternPainter(primaryColor.withOpacity(0.15)),
              size: const Size(double.infinity, double.infinity),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  title: title,
                  description: description,
                  isAI: isAI,
                  primaryColor: primaryColor,
                ),
                _buildStatsRow(primaryColor),
                _buildAssessmentInfoCard(primaryColor),
                _buildQuestionDistributionCard(primaryColor),
                _buildRatingCard(primaryColor),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({
    required String title,
    required String description,
    required bool isAI,
    required Color primaryColor,
  }) {
    final String formattedDescription =
        description.trim().isEmpty ? 'No description available' : description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final animation = CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(
                        0.0,
                        0.6,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - animation.value)),
                      child: Opacity(opacity: animation.value, child: child),
                    );
                  },
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
              ),
              if (isAI)
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final animation = CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(
                        0.3,
                        0.8,
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    return Transform.translate(
                      offset: Offset(30 * (1 - animation.value), 0),
                      child: Opacity(opacity: animation.value, child: child),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 12, top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.purple, Colors.deepPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withAlpha(77),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'AI Generated',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final animation = CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
              );

              return Opacity(
                opacity: animation.value,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color:
                          formattedDescription == 'No description available'
                              ? Colors.grey.withAlpha(26)
                              : primaryColor.withAlpha(26),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    formattedDescription,
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          formattedDescription == 'No description available'
                              ? Colors.grey.shade500
                              : Colors.grey.shade700,
                      height: 1.5,
                      fontStyle:
                          formattedDescription == 'No description available'
                              ? FontStyle.italic
                              : FontStyle.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Color primaryColor) {
    final totalPoints = _assessmentData['totalPoints'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final animation = CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
          );

          return Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: Opacity(opacity: animation.value, child: child),
          );
        },
        child: Row(
          children: [
            _buildStatCard(
              icon: Icons.quiz_outlined,
              title: '$_totalQuestions',
              subtitle: 'Questions',
              color: Colors.blue,
              isPrimary: true,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              icon: Icons.star_outline,
              title: '$totalPoints',
              subtitle: 'Points',
              color: Colors.amber,
              isPrimary: false,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              icon: Icons.people_outline,
              title: '$_participantsCount',
              subtitle: 'Taken',
              color: Colors.green,
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isPrimary,
  }) {
    return Expanded(
      flex: isPrimary ? 4 : 3,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withAlpha(isPrimary ? 51 : 38),
              color.withAlpha(isPrimary ? 26 : 13),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(26),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isPrimary ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentInfoCard(Color primaryColor) {
    final difficulty = _assessmentData['difficulty'] ?? 'Medium';
    final createdAt = _formatDate(_assessmentData['createdAt']);
    final creatorName =
        _isCreator ? 'You' : _assessmentData['creatorName'] ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final animation = CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
          );

          return Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: Opacity(opacity: animation.value, child: child),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      Color.lerp(primaryColor, Colors.white, 0.3) ??
                          primaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(77),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Assessment Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.signal_cellular_alt_outlined,
                      color: _getDifficultyColor(difficulty),
                      title: 'Difficulty Level',
                      value: difficulty,
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow(
                      icon: Icons.person_outline,
                      color: Colors.blue,
                      title: 'Created by',
                      value: creatorName,
                    ),
                    const SizedBox(height: 24),
                    _buildInfoRow(
                      icon: Icons.event_outlined,
                      color: Colors.purple,
                      title: 'Created on',
                      value: createdAt,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(child: Icon(icon, color: color, size: 24)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionDistributionCard(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final animation = CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
          );

          return Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: Opacity(opacity: animation.value, child: child),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(primaryColor, Colors.blue, 0.3) ?? Colors.blue,
                      Color.lerp(primaryColor, Colors.blue, 0.7) ?? Colors.blue,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(77),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.radar,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Question Distribution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (_questionTypeCount.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'No questions available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 300,
                            width: double.infinity,
                            child: _buildRadarChart(),
                          ),
                          const SizedBox(height: 24),
                          ..._buildQuestionTypeList(),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarChart() {
    final Color primaryColor = _getDifficultyColor(
      _assessmentData['difficulty'] as String?,
    );

    if (_questionTypeCount.isEmpty) {
      return Container();
    }

    final int maxCount = _questionTypeCount.values.fold(
      0,
      (a, b) => a > b ? a : b,
    );

    final sortedTypes = _questionTypeCount.keys.toList()..sort();

    final List<List<RadarEntry>> allDataSets = [[]];

    for (String type in sortedTypes) {
      final count = _questionTypeCount[type] ?? 0;
      final double normalizedValue = maxCount > 0 ? count / maxCount : 0;
      allDataSets[0].add(RadarEntry(value: normalizedValue));
    }

    final List<String> titles =
        sortedTypes.map((type) {
          final words = type.split('-');
          return words
              .map(
                (word) =>
                    word.isNotEmpty
                        ? '${word[0].toUpperCase()}${word.substring(1)}'
                        : '',
              )
              .join(' ');
        }).toList();

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        dataSets: [
          RadarDataSet(
            fillColor: primaryColor.withOpacity(0.2),
            borderColor: primaryColor,
            entryRadius: 5,
            borderWidth: 2.5,
            dataEntries:
                allDataSets[0]
                    .map(
                      (entry) => RadarEntry(
                        value: entry.value * _animationController.value,
                      ),
                    )
                    .toList(),
          ),
        ],
        titleTextStyle: TextStyle(
          color: Colors.grey[800],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        ticksTextStyle: TextStyle(color: Colors.grey[600], fontSize: 10),
        gridBorderData: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        tickBorderData: BorderSide(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
        titlePositionPercentageOffset: 0.2,
        radarBackgroundColor: Colors.transparent,
        getTitle:
            (index, angle) =>
                RadarChartTitle(text: titles[index], angle: angle),
        tickCount: 5,
      ),
      duration: const Duration(milliseconds: 500),
    );
  }

  List<Widget> _buildQuestionTypeList() {
    if (_questionTypeCount.isEmpty) {
      return [];
    }

    final sortedTypes =
        _questionTypeCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTypes.map((entry) {
      final type = entry.key;
      final count = entry.value;
      final percent =
          (_totalQuestions > 0) ? (count / _totalQuestions * 100).round() : 0;

      final typeInfo = _getQuestionTypeInfo(type);
      final IconData icon = typeInfo.$1;
      final Color color = typeInfo.$2;

      final formattedType = type
          .split('-')
          .map(
            (word) =>
                word.isNotEmpty
                    ? word[0].toUpperCase() + word.substring(1)
                    : '',
          )
          .join(' ');

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                formattedType,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count ($percent%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildRatingCard(Color primaryColor) {
    final rating = (_assessmentData['rating'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final animation = CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
          );

          return Transform.translate(
            offset: Offset(0, 30 * (1 - animation.value)),
            child: Opacity(opacity: animation.value, child: child),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(77),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Rating & Feedback',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: rating),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return Icon(
                              index < value.floor()
                                  ? Icons.star
                                  : (index < value.ceil() &&
                                      value.ceil() - value < 1)
                                  ? Icons.star_half
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 40,
                            );
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        Text(
                          ' / 5.0',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Based on $_participantsCount ${_participantsCount == 1 ? 'rating' : 'ratings'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform:
                      _isSourceButtonPressed
                          ? Matrix4.translationValues(0, 2, 0)
                          : Matrix4.translationValues(0, 0, 0),
                  child: GestureDetector(
                    onTapDown:
                        (_) => setState(() => _isSourceButtonPressed = true),
                    onTapUp: (_) => _openSourceDocument(),
                    onTapCancel:
                        () => setState(() => _isSourceButtonPressed = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryColor, width: 1.5),
                        boxShadow:
                            _isSourceButtonPressed
                                ? []
                                : [
                                  BoxShadow(
                                    color: primaryColor.withAlpha(51),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View Source',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withAlpha(102),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _startAssessment,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Start Assessment',
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
            ],
          ),
        ),
      ),
    );
  }
}

class PatternPainter extends CustomPainter {
  final Color color;

  PatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    const double spacing = 35;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height / 2; y += spacing) {
        if ((x ~/ spacing + y ~/ spacing) % 2 == 0) {
          canvas.drawCircle(Offset(x, y), 0.5, paint);
        } else {
          canvas.drawCircle(
            Offset(x, y),
            1.5,
            paint..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
