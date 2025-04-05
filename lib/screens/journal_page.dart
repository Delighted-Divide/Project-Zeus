import 'package:flutter/material.dart';
import 'assessment_page.dart';
import 'dashboard.dart';
import 'friends_groups_page.dart';
import 'ai_learning_page.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  int _selectedDayIndex = 3; // Thursday (index 3) is selected by default

  // Days of the week
  final List<String> _daysOfWeek = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  // Sample dates for the week (hardcoded to match the image)
  final List<int> _datesOfWeek = [24, 25, 26, 27, 28, 29, 30];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background for the entire screen
      body: Column(
        children: [
          // Salmon colored container for the top section
          Container(
            color: const Color(0xFFFFA07A), // Salmon background
            child: SafeArea(
              bottom: false, // Don't add bottom padding
              child: Column(
                children: [
                  _buildHeader(),
                  _buildDaySelector(),
                  // Curved bottom edge for the salmon section
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
          ),

          // Main content area (white background)
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildNeedsSatisfactionMeter(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          _buildActivityCard(
                            icon: Icons.assignment,
                            title: 'Question Creation',
                            duration: '15min',
                            indicatorPosition: 0.5, // 50% (middle bar)
                            showUpArrow: true,
                          ),
                          _buildActivityCard(
                            icon: Icons.question_answer,
                            title: 'Student Responses',
                            duration: '12min',
                            indicatorPosition: 0.3, // 30% (first bar)
                            showHeartIcon: true,
                          ),
                          _buildActivityCard(
                            icon: Icons.analytics,
                            title: 'AI Evaluation',
                            duration: '36min',
                            indicatorPosition: 0.9, // 90% (third bar)
                            showUpArrow: true,
                          ),
                          _buildActivityCard(
                            icon: Icons.psychology,
                            title: 'Learning Assessment',
                            duration: '72min',
                            indicatorPosition: 0.7, // 70% (third bar)
                            showSquareIcon: true,
                          ),
                          // Add extra space at the bottom for scrolling past the nav bar
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Bottom navigation bar as a separate element
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Header with JOURNAL text
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: const Text(
        'JOURNAL',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  // Day selector with days of the week
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
              // Add oval outline for selected day
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
                  // Day label (outside the circle)
                  Text(
                    _daysOfWeek[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Date with black circle background for selected day
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

  // Needs satisfaction meter
  Widget _buildNeedsSatisfactionMeter() {
    const double percentage = 0.38; // 38%

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: Colors.orange[300], size: 20),
                  const SizedBox(width: 4),
                  const Text(
                    '38%',
                    style: TextStyle(
                      fontSize: 36, // Larger font size
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'NEEDS',
                        style: TextStyle(
                          fontSize: 14, // Larger font size
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'SATISFACTION',
                        style: TextStyle(
                          fontSize: 14, // Larger font size
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'EDIT GOAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress meter
          Container(
            height: 16, // Thicker bar
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black,
                width: 2,
              ), // Thicker black border
            ),
            child: Row(
              children: [
                // Filled part (38%)
                Expanded(
                  flex: (percentage * 100).toInt(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange[300],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        topRight:
                            percentage == 1.0
                                ? Radius.circular(8)
                                : Radius.zero,
                        bottomRight:
                            percentage == 1.0
                                ? Radius.circular(8)
                                : Radius.zero,
                      ),
                    ),
                  ),
                ),
                // Unfilled part (62%)
                Expanded(
                  flex: 100 - (percentage * 100).toInt(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft:
                            percentage == 0.0
                                ? Radius.circular(8)
                                : Radius.zero,
                        bottomLeft:
                            percentage == 0.0
                                ? Radius.circular(8)
                                : Radius.zero,
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
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

  // Activity card with three separate progress bars
  Widget _buildActivityCard({
    required IconData icon,
    required String title,
    required String duration,
    required double indicatorPosition, // 0.0 to 1.0
    bool showUpArrow = false,
    bool showHeartIcon = false,
    bool showSquareIcon = false,
  }) {
    // Determine which segment is active based on the indicator position
    bool isFirstActive = indicatorPosition < 0.33;
    bool isSecondActive = indicatorPosition >= 0.33 && indicatorPosition < 0.66;
    bool isThirdActive = indicatorPosition >= 0.66;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.black,
          width: 2,
        ), // Thicker black border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with title and duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title with icon
              Row(
                children: [
                  Icon(icon, size: 20, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              // Duration with indicator
              Row(
                children: [
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (showUpArrow)
                    const Icon(
                      Icons.arrow_upward,
                      size: 16,
                      color: Colors.green,
                    ),
                  if (showHeartIcon)
                    const Icon(Icons.favorite, size: 16, color: Colors.red),
                  if (showSquareIcon)
                    const Icon(Icons.stop, size: 16, color: Colors.blue),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bars with indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Three separate bar meters
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 12, // Thicker bar
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color:
                            isFirstActive ? Colors.red[300] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 12, // Thicker bar
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color:
                            isSecondActive
                                ? Colors.amber[300]
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 12, // Thicker bar
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color:
                            isThirdActive
                                ? Colors.green[300]
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                    ),
                  ),
                ],
              ),

              // Pointer indicator (black triangle pointing down to the bars)
              Positioned(
                left:
                    (MediaQuery.of(context).size.width - 80) *
                        indicatorPosition -
                    20,
                top: -20, // Position further above the bars
                child: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Labels for the three segments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Expanded(
                child: Text(
                  'Below Average',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  'Average',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  'Above Average',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bottom navigation bar
  // Modified section from journal_page.dart to update the navigation for the bar chart icon

  // Bottom navigation bar
  // Update to _buildBottomNavBar in journal_page.dart
  Widget _buildBottomNavBar() {
    return Container(
      height: 55,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 25.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA07A), // Salmon background color
        border: Border.all(color: Colors.black, width: 1.5), // Black border
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
          // Bar chart icon with navigation to AssessmentPage
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AssessmentPage()),
              );
            },
            child: _buildNavItem(Icons.bar_chart, false),
          ),
          // AI Learning page navigation
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AILearningPage()),
              );
            },
            child: _buildNavItem(Icons.access_time, false),
          ),
          // Home icon with navigation to Dashboard
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
            },
            child: _buildNavItem(Icons.home, false),
          ),
          _buildNavItem(Icons.assessment, true), // Assessment icon is selected
          // Person icon with navigation to FriendsGroupsPage
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

  // Individual navigation item
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
        size: 24, // Smaller icon size
      ),
    );
  }
}
