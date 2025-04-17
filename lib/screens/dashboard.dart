import 'package:flutter/material.dart';
import 'dart:async';
import 'journal_page.dart';
import 'assessment_page.dart';
import 'friends_groups_page.dart';
import 'ai_learning_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedDayIndex = 3;
  int _currentAssignmentIndex = 0;
  late PageController _assignmentPageController;
  Timer? _assignmentTimer;
  final ScrollController _scrollController = ScrollController();

  final List<String> _daysOfWeek = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  final List<Map<String, dynamic>> _assignments = [
    {
      'name': 'Math Assignment: Calculus I',
      'completion': 75,
      'dueDate': 'Today',
      'dueTime': '11:59 PM',
      'progress': 'incomplete',
      'subject': 'Mathematics',
    },
    {
      'name': 'Physics Lab Report',
      'completion': 90,
      'dueDate': 'Tomorrow',
      'dueTime': '3:00 PM',
      'progress': 'in_review',
      'subject': 'Physics',
    },
    {
      'name': 'Literature Essay',
      'completion': 100,
      'dueDate': 'Yesterday',
      'dueTime': '11:59 PM',
      'progress': 'graded',
      'subject': 'English',
    },
    {
      'name': 'Computer Science Project',
      'completion': 45,
      'dueDate': 'Friday',
      'dueTime': '5:00 PM',
      'progress': 'incomplete',
      'subject': 'Computer Science',
    },
  ];

  final List<Map<String, dynamic>> _feedbackList = [
    {
      'subject': 'Calculus',
      'feedback':
          'Your approach to integration problems is improving. Try using u-substitution for the remaining questions.',
    },
    {
      'subject': 'Physics',
      'feedback':
          'Good work on the momentum problems. Review Newton\'s Third Law application in the lab report section 2.',
    },
    {
      'subject': 'Literature',
      'feedback':
          'Your character analysis shows depth. Consider exploring the historical context more in your next essay.',
    },
    {
      'subject': 'Literature',
      'feedback':
          'Your character analysis shows depth. Consider exploring the historical context more in your next essay.',
    },
    {
      'subject': 'Literature',
      'feedback':
          'Your character analysis shows depth. Consider exploring the historical context more in your next essay.',
    },
    {
      'subject': 'Literature',
      'feedback':
          'Your character analysis shows depth. Consider exploring the historical context more in your next essay.',
    },
    {
      'subject': 'Literature',
      'feedback':
          'Your character analysis shows depth. Consider exploring the historical context more in your next essay.',
    },
  ];

  final DateTime _now = DateTime.now();
  late final List<int> _datesOfWeek;

  @override
  void initState() {
    super.initState();

    final monday = _now.subtract(Duration(days: _now.weekday - 1));
    _datesOfWeek = List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return date.day;
    });

    _assignmentPageController = PageController(initialPage: 0);

    _assignmentTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentAssignmentIndex < _assignments.length - 1) {
        _currentAssignmentIndex++;
      } else {
        _currentAssignmentIndex = 0;
      }

      if (_assignmentPageController.hasClients) {
        _assignmentPageController.animateToPage(
          _currentAssignmentIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _assignmentTimer?.cancel();
    _assignmentPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: const Color(0xFFFFC857),
            child: SafeArea(
              bottom: false,
              child: Column(children: [_buildTopBar(), _buildDaySelector()]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFFFC857),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 160,
                          child: PageView.builder(
                            controller: _assignmentPageController,
                            itemCount: _assignments.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentAssignmentIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final assignmentIndex =
                                  index % _assignments.length;
                              return _buildCurrentAssignmentCard(
                                _assignments[assignmentIndex],
                              );
                            },
                          ),
                        ),
                        _buildStatsGrid(),
                        const SizedBox(height: 20),
                        _buildLearningActivities(),
                        const SizedBox(height: 25),
                        Container(
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 16.0,
                            top: 8.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'AI FEEDBACK',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFC857,
                                  ).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      '3',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'New Suggestions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._feedbackList.map(
                          (feedback) => _buildFeedbackCard(feedback),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Text(
          'THIS WEEK',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final isSelected = index == _selectedDayIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDayIndex = index;
              });
            },
            child: Container(
              width: 40,
              height: 65,
              decoration:
                  isSelected
                      ? BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1),
                        borderRadius: BorderRadius.circular(20),
                      )
                      : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _daysOfWeek[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  isSelected
                      ? Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                        child: Center(
                          child: Text(
                            '${_datesOfWeek[index]}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                      : Text(
                        '${_datesOfWeek[index]}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentAssignmentCard(Map<String, dynamic> assignment) {
    final Map<String, IconData> progressIcons = {
      'incomplete': Icons.pending_actions,
      'in_review': Icons.rate_review,
      'graded': Icons.star,
    };

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF80AB82),
                ),
                child: const Icon(
                  Icons.assignment,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_alarm,
                              size: 16,
                              color: Colors.black.withOpacity(0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              assignment['dueDate'].toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      assignment['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          assignment['dueTime'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.7),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            progressIcons[assignment['progress']] ??
                                Icons.help_outline,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${assignment['completion']}%',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.7),
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
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Assignment Completion',
                  75,
                  const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Study Time Goal',
                  62,
                  const Color(0xFF98D8C8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Comprehension Score',
                  87,
                  const Color(0xFFD8BFD8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Performance Index',
                  76,
                  const Color(0xFFF4A9A8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int percentage, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(
                width: 55,
                height: 55,
                child: CustomProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  color: Colors.white,
                  strokeWidth: 8,
                  divisions: 8,
                  centerBackgroundColor: backgroundColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningActivities() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActivityTag(
            icon: Icons.menu_book,
            label: 'Reading',
            color: const Color(0xFFF4A9A8),
          ),
          _buildActivityTag(
            icon: Icons.calculate,
            label: 'Problem Solving',
            color: const Color(0xFF98D8C8),
          ),
          _buildActivityTag(
            icon: Icons.edit_note,
            label: 'Writing',
            color: const Color(0xFF80AB82),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4A9A8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                feedback['subject'],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feedback['feedback'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 55,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 25.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857),
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AssessmentPage()),
              );
            },
            child: _buildNavItem(Icons.bar_chart, false),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AILearningPage()),
              );
            },
            child: _buildNavItem(Icons.access_time, false),
          ),
          _buildNavItem(Icons.home, true),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const JournalPage()),
              );
            },
            child: _buildNavItem(Icons.assessment, false),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const FriendsGroupsPage(),
                ),
              );
            },
            child: _buildNavItem(Icons.person_outline, false),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isSelected ? Colors.black : Colors.black.withOpacity(0.7),
        size: 24,
      ),
    );
  }
}

class CustomProgressIndicator extends StatelessWidget {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final int divisions;
  final Color centerBackgroundColor;

  const CustomProgressIndicator({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 4.0,
    this.divisions = 8,
    required this.centerBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DivisionProgressPainter(
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        strokeWidth: strokeWidth,
        divisions: divisions,
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: centerBackgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1),
          ),
        ),
      ),
    );
  }
}

class _DivisionProgressPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final int divisions;

  _DivisionProgressPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.divisions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    final backgroundPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final progressPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final outlinePaint =
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final filledDivisions = (value * divisions).floor();
    final arcAngle = 2 * 3.14159 / divisions;

    canvas.drawCircle(center, radius, outlinePaint);

    for (int i = 0; i < divisions; i++) {
      final startAngle = -3.14159 / 2 + i * arcAngle;

      final paint = i < filledDivisions ? progressPaint : backgroundPaint;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle * 0.85,
        false,
        paint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcAngle * 0.85,
        false,
        outlinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DivisionProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.divisions != divisions;
  }
}
