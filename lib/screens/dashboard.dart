import 'package:flutter/material.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
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

  // Get the current date and calculate the dates for the week
  final DateTime _now = DateTime.now();
  late final List<int> _datesOfWeek;

  @override
  void initState() {
    super.initState();
    // Calculate dates for the week (starting from Monday)
    final monday = _now.subtract(Duration(days: _now.weekday - 1));
    _datesOfWeek = List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return date.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFFFC857,
      ), // Exact yellow background from image
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildDaySelector(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildLiveStatusCard(),
                    _buildStatsGrid(),
                    const SizedBox(
                      height: 20,
                    ), // Add extra space after stat cards
                    _buildActivityTags(),
                    const SizedBox(
                      height: 25,
                    ), // Add extra space before insights
                    // Insights section in white container with rounded corners
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      padding: const EdgeInsets.all(16.0),
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
                      child: _buildInsights(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  // Top bar with "TODAY" text
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Text(
          'TODAY',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  // Day selector with oval outline and black circle covering only the date
  Widget _buildDaySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
              // Add oval outline for selected day (positioned higher up)
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
                  // Date with black circle background
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

  // Live status card with pet photo and status
  Widget _buildLiveStatusCard() {
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
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Pet image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(
                    0xFF80AB82,
                  ), // Green tint for the image background
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/cat.png', // Replace with your actual image path
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.pets,
                        size: 40,
                        color: Colors.white.withOpacity(0.8),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Pet status and info
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
                              Icons.wifi,
                              size: 16,
                              color: Colors.black.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '87%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.battery_full,
                              size: 16,
                              color: Colors.black.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mau is on a walk.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                          '10:24',
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
                          child: const Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '200m Away',
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

  // Grid of stats with circular progress indicators
  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Needs Satisfaction',
                  38,
                  const Color(0xFFF4A9A8), // Light salmon from image
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Activity Goal',
                  62,
                  const Color(0xFF98D8C8), // Light teal from image
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Sleep Quality',
                  87,
                  const Color(0xFFD8BFD8), // Light purple from image
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Wellness Index',
                  76,
                  const Color(0xFFF4A9A8), // Light coral from image
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Individual stat card with circular progress
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
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      strokeWidth: 4,
                      color: Colors.white,
                    ),
                    Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  // Activity tags row
  Widget _buildActivityTags() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActivityTag(
            icon: Icons.favorite,
            label: 'Meowing',
            color: const Color(0xFFF4A9A8), // Light coral
          ),
          _buildActivityTag(
            icon: Icons.water_drop_outlined,
            label: 'Licking',
            color: const Color(0xFF98D8C8), // Light teal
          ),
          _buildActivityTag(
            icon: Icons.pets,
            label: 'Scratching',
            color: const Color(0xFF80AB82), // Green
          ),
        ],
      ),
    );
  }

  // Individual activity tag
  Widget _buildActivityTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  // Insights section - inside a white container
  Widget _buildInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // INSIGHTS header row with notification count
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'INSIGHTS',
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
                  color: const Color(0xFFFFC857).withOpacity(
                    0.3,
                  ), // Same as background color but transparent
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      '2',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'New Notifications',
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

        // Notification card with rounded corners
        Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date label with rounded pink background
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 3,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4A9A8), // Light coral
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '31 Jan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Notification text
                const Expanded(
                  child: Text(
                    'It seems that Mau presents anxious behaviors when you leave her alone.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Bottom navigation bar - same color as the background
  Widget _buildBottomNavBar() {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857), // Same as the background color
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
          _buildNavItem(Icons.location_on_outlined, false),
          _buildNavItem(Icons.access_time, false),
          _buildNavItem(Icons.home, true),
          _buildNavItem(Icons.pets, false),
          _buildNavItem(Icons.person_outline, false),
        ],
      ),
    );
  }

  // Individual navigation item
  Widget _buildNavItem(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isSelected ? Colors.black : Colors.black.withOpacity(0.7),
        size: 28,
      ),
    );
  }
}
