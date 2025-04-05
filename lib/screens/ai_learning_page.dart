import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

import 'assessment_page.dart';
import 'dashboard.dart';
import 'journal_page.dart';
import 'friends_groups_page.dart';

class AILearningPage extends StatefulWidget {
  const AILearningPage({super.key});

  @override
  State<AILearningPage> createState() => _AILearningPageState();
}

class _AILearningPageState extends State<AILearningPage>
    with TickerProviderStateMixin {
  int _selectedPathIndex = 0;
  bool _isPathDetailView = false;
  int _currentCarouselIndex = 0; // For the auto-switching carousel
  Timer? _carouselTimer; // Timer for auto-switching

  // Animation controllers
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _pathAnimationController;
  late PageController _carouselController; // For carousel
  // Scroll controllers
  final ScrollController _mainScrollController = ScrollController();

  void _onScroll() {
    // Performance optimization: Track scroll position
    // for potential lazy loading or animation triggers
  }

  // Featured learning paths (now including non-AI subjects)
  final List<Map<String, dynamic>> _featuredPaths = [
    {
      'title': 'AI Fundamentals',
      'subtitle': 'Learn core AI concepts',
      'description':
          'A comprehensive introduction to artificial intelligence concepts, principles, and applications.',
      'color': const Color(0xFF5D5FEF), // More vibrant blue-purple
      'icon': Icons.auto_awesome,
      'progress': 0.35,
      'totalModules': 8,
      'completedModules': 3,
      'totalHours': 12,
      'level': 'Beginner',
      'category': 'Technology',
      'modules': [
        {
          'title': 'Introduction to AI',
          'duration': '25 min',
          'isCompleted': true,
          'description':
              'Learn the fundamental concepts of artificial intelligence and its historical development.',
          'outcomes': [
            'Understand AI terminology and concepts',
            'Recognize different types of AI systems',
            'Explain the historical development of AI',
          ],
        },
        {
          'title': 'Machine Learning Basics',
          'duration': '35 min',
          'isCompleted': true,
          'description':
              'Explore the core principles of machine learning, including supervised and unsupervised learning.',
          'outcomes': [
            'Distinguish between supervised and unsupervised learning',
            'Understand basic ML algorithms',
            'Identify appropriate ML techniques for different problems',
          ],
        },
        {
          'title': 'Neural Networks',
          'duration': '40 min',
          'isCompleted': true,
          'description':
              'Dive into the structure and function of neural networks and how they mimic human brain functioning.',
          'outcomes': [
            'Explain how neural networks are structured',
            'Understand activation functions and their purpose',
            'Describe the training process for neural networks',
          ],
        },
        {
          'title': 'Deep Learning',
          'duration': '45 min',
          'isCompleted': false,
          'description':
              'Explore advanced neural network architectures and deep learning techniques.',
          'outcomes': [
            'Understand the difference between shallow and deep networks',
            'Recognize different deep learning architectures',
            'Identify appropriate applications for deep learning',
          ],
        },
      ],
    },
    {
      'title': 'World History',
      'subtitle': 'Civilization & development',
      'description':
          'Explore the key events, periods, and figures that shaped human history across different civilizations.',
      'color': const Color(0xFF67B26F), // Vibrant green
      'icon': Icons.public,
      'progress': 0.15,
      'totalModules': 10,
      'completedModules': 2,
      'totalHours': 15,
      'level': 'Intermediate',
      'category': 'History',
      'modules': [
        {
          'title': 'Ancient Civilizations',
          'duration': '30 min',
          'isCompleted': true,
          'description':
              'Explore the earliest human civilizations including Mesopotamia, Egypt, Indus Valley, and China.',
          'outcomes': [
            'Identify major ancient civilizations and their locations',
            'Compare the cultural developments across different civilizations',
            'Understand the important technological advances of early humanity',
          ],
        },
        {
          'title': 'Medieval Period',
          'duration': '35 min',
          'isCompleted': true,
          'description':
              'Study the Middle Ages, from the fall of Rome to the Renaissance, across Europe, Asia, and Africa.',
          'outcomes': [
            'Understand feudal systems and governance structures',
            'Analyze the role of religion in medieval societies',
            'Recognize major cultural and technological developments',
          ],
        },
        {
          'title': 'Renaissance',
          'duration': '30 min',
          'isCompleted': false,
          'description':
              'Examine the cultural, artistic, and intellectual rebirth that transformed Europe from the 14th to 17th centuries.',
          'outcomes': [
            'Understand humanist philosophy and its impact',
            'Identify major artistic innovations and important figures',
            'Explore scientific advancements of the period',
          ],
        },
        {
          'title': 'Modern Era',
          'duration': '40 min',
          'isCompleted': false,
          'description':
              'Study the transformative events from the industrial revolution to the present day.',
          'outcomes': [
            'Analyze the causes and effects of industrialization',
            'Understand major political revolutions and their impacts',
            'Explore globalization and technological acceleration',
          ],
        },
      ],
    },
    {
      'title': 'Advanced Mathematics',
      'subtitle': 'Calculus & beyond',
      'description':
          'Develop your mathematical skills with calculus, linear algebra, and other advanced mathematical concepts.',
      'color': const Color(0xFFE94057), // Vibrant red
      'icon': Icons.calculate,
      'progress': 0.60,
      'totalModules': 8,
      'completedModules': 5,
      'totalHours': 14,
      'level': 'Advanced',
      'category': 'Mathematics',
      'modules': [
        {
          'title': 'Differential Calculus',
          'duration': '40 min',
          'isCompleted': true,
          'description':
              'Master derivatives and their applications in finding rates of change and optimization problems.',
          'outcomes': [
            'Apply differentiation rules to various functions',
            'Solve optimization problems using derivatives',
            'Understand the geometric interpretation of derivatives',
          ],
        },
        {
          'title': 'Integral Calculus',
          'duration': '45 min',
          'isCompleted': true,
          'description':
              'Explore integration techniques and their applications in calculating areas and volumes.',
          'outcomes': [
            'Apply integration techniques to various functions',
            'Calculate areas and volumes using definite integrals',
            'Understand the connection between derivatives and integrals',
          ],
        },
        {
          'title': 'Linear Algebra',
          'duration': '35 min',
          'isCompleted': true,
          'description':
              'Study vector spaces, matrices, and linear transformations that are fundamental to many fields.',
          'outcomes': [
            'Perform matrix operations and understand their properties',
            'Solve systems of linear equations',
            'Understand eigenvalues and eigenvectors and their applications',
          ],
        },
        {
          'title': 'Probability Theory',
          'duration': '30 min',
          'isCompleted': false,
          'description':
              'Learn about probability distributions, expected values, and statistical inference.',
          'outcomes': [
            'Calculate probabilities for different types of events',
            'Work with probability distributions and their properties',
            'Apply probability theory to real-world problems',
          ],
        },
      ],
    },
    {
      'title': 'Creative Writing',
      'subtitle': 'Storytelling & expression',
      'description':
          'Learn the craft of creative writing, from developing characters to structuring compelling narratives.',
      'color': const Color(0xFF8A2387), // Vibrant purple
      'icon': Icons.create,
      'progress': 0.25,
      'totalModules': 6,
      'completedModules': 1,
      'totalHours': 9,
      'level': 'All Levels',
      'category': 'Arts',
      'modules': [
        {
          'title': 'Narrative Structure',
          'duration': '25 min',
          'isCompleted': true,
          'description':
              'Explore different story structures, plot development, and narrative arcs.',
          'outcomes': [
            'Understand classic and modern story structures',
            'Develop compelling narrative arcs',
            'Create effective plot outlines for stories',
          ],
        },
        {
          'title': 'Character Development',
          'duration': '30 min',
          'isCompleted': false,
          'description':
              'Learn techniques for creating multidimensional characters with depth and authenticity.',
          'outcomes': [
            'Create character profiles and backstories',
            'Develop character arcs that integrate with plot',
            'Write authentic dialogue that reveals character',
          ],
        },
        {
          'title': 'Dialogue Writing',
          'duration': '35 min',
          'isCompleted': false,
          'description':
              'Master the art of writing natural, compelling dialogue that advances your story and reveals character.',
          'outcomes': [
            'Write dialogue that sounds natural and distinct',
            'Use dialogue to reveal character and advance plot',
            'Balance dialogue with action and description',
          ],
        },
        {
          'title': 'World Building',
          'duration': '40 min',
          'isCompleted': false,
          'description':
              'Develop immersive settings and worlds that enhance your storytelling.',
          'outcomes': [
            'Create detailed and consistent fictional worlds',
            'Integrate setting with plot and character development',
            'Research effectively to add authenticity to settings',
          ],
        },
      ],
    },
  ];

  // Additional learning paths (recommended section)
  final List<Map<String, dynamic>> _additionalPaths = [
    {
      'title': 'Data Science',
      'subtitle': 'Analytics & interpretation',
      'description':
          'Master data visualization, statistical analysis, and predictive modeling techniques.',
      'color': const Color(0xFF00BCD4), // Cyan
      'icon': Icons.insert_chart,
      'level': 'Intermediate',
      'category': 'Technology',
      'totalModules': 9,
      'estimatedHours': 16,
    },
    {
      'title': 'Cognitive Psychology',
      'subtitle': 'Mind & behavior',
      'description':
          'Understand how we perceive, think, remember, and make decisions.',
      'color': const Color(0xFFFF9800), // Orange
      'icon': Icons.psychology,
      'level': 'Beginner',
      'category': 'Psychology',
      'totalModules': 7,
      'estimatedHours': 10,
    },
    {
      'title': 'Sustainable Design',
      'subtitle': 'Eco-friendly approaches',
      'description':
          'Learn principles and practices for environmentally conscious design solutions.',
      'color': const Color(0xFF4CAF50), // Green
      'icon': Icons.eco,
      'level': 'All Levels',
      'category': 'Design',
      'totalModules': 6,
      'estimatedHours': 8,
    },
    {
      'title': 'Blockchain Technology',
      'subtitle': 'Decentralized systems',
      'description':
          'Explore the fundamentals of blockchain, smart contracts, and decentralized applications.',
      'color': const Color(0xFF673AB7), // Deep Purple
      'icon': Icons.link,
      'level': 'Intermediate',
      'category': 'Technology',
      'totalModules': 8,
      'estimatedHours': 14,
    },
  ];

  // Learning ecosystems with updated titles and reorganization
  final List<Map<String, dynamic>> _learningEcosystems = [
    {
      'title': 'Interactive Labs',
      'description': 'Coming soon: Hands-on practice environments',
      'icon': Icons.science,
      'color': const Color(0xFF5D5FEF), // Vibrant blue-purple
      'isEnabled': false,
    },
    {
      'title': 'Live Classes',
      'description': 'Real-time learning with expert instructors',
      'icon': Icons.live_tv,
      'color': const Color(0xFF67B26F), // Vibrant green
      'isEnabled': true,
    },
    {
      'title': 'Learning Circles',
      'description': 'Peer-to-peer collaborative study groups',
      'icon': Icons.people,
      'color': const Color(0xFFE94057), // Vibrant red
      'isEnabled': true,
    },
    {
      'title': 'Content Library',
      'description': 'Coming soon: Comprehensive resource collection',
      'icon': Icons.menu_book,
      'color': const Color(0xFF8A2387), // Vibrant purple
      'isEnabled': false,
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pathAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Initialize carousel controller
    _carouselController = PageController(initialPage: 0);

    // Start with fade animation
    _fadeAnimationController.forward();

    // Start with slide animation for staggered elements
    _slideAnimationController.forward();

    // Add scroll listener for optimized rendering
    _mainScrollController.addListener(_onScroll);

    // Start auto-switching for the carousel
    _startAutoSwitchTimer();
  }

  // Simple timer for auto-switching
  void _startAutoSwitchTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        _currentCarouselIndex =
            (_currentCarouselIndex + 1) % _additionalPaths.length;
      });
    });
  }

  void _startCarouselTimer() {
    // Cancel any existing timer
    _carouselTimer?.cancel();

    // Create a new timer that switches every 5 seconds
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentCarouselIndex < _additionalPaths.length - 1) {
        _currentCarouselIndex++;
      } else {
        _currentCarouselIndex = 0;
      }

      if (_carouselController.hasClients) {
        _carouselController.animateToPage(
          _currentCarouselIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  // Toggle between main view and path detail view
  void _togglePathDetailView({int? pathIndex}) {
    setState(() {
      if (pathIndex != null) {
        _selectedPathIndex = pathIndex;
      }
      _isPathDetailView = !_isPathDetailView;
    });

    // Reset scroll position when toggling views
    _mainScrollController.jumpTo(0);
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    _pulseAnimationController.dispose();
    _pathAnimationController.dispose();
    _mainScrollController.removeListener(_onScroll);
    _mainScrollController.dispose();
    _carouselController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    // Extra padding to ensure content doesn't get hidden by navbar
    const double navbarSpacing = 100.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false, // We'll handle bottom padding ourselves
          child: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // App bar (simplified without search and profile icons)
                  _buildAppBar(),

                  // Main scrollable content area
                  Expanded(
                    child:
                        _isPathDetailView
                            ? _buildPathDetailView(size)
                            : _buildMainContentView(
                              size,
                              navbarSpacing,
                              bottomPadding,
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Bottom navigation bar (restored to original style)
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  // App bar with title only (search and profile icons removed)
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title with back button when in detail view
          _isPathDetailView
              ? GestureDetector(
                onTap: _togglePathDetailView,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'AI LEARNING',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
              : const Text(
                'AI LEARNING',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

          // Right side spacer (icons removed)
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // Main content view with featured paths and ecosystems
  Widget _buildMainContentView(
    Size size,
    double navbarSpacing,
    double bottomPadding,
  ) {
    return SingleChildScrollView(
      controller: _mainScrollController,
      physics: const BouncingScrollPhysics(),
      // Increased bottom padding to ensure no content is hidden behind the navbar
      padding: EdgeInsets.only(bottom: navbarSpacing + bottomPadding + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Learning progress summary (without percentage increase)
          _buildLearningProgressSummary(),

          // Featured paths section
          _buildFeaturedPathsSection(),

          // Additional learning paths (recommended section with carousel)
          _buildAdditionalPathsSection(),

          // Learning ecosystems (updated)
          _buildLearningEcosystemsSection(),
        ],
      ),
    );
  }

  // Learning progress summary card (removed percentage increase)
  Widget _buildLearningProgressSummary() {
    return FadeTransition(
      opacity: _fadeAnimationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _fadeAnimationController,
            curve: Curves.easeOutCubic,
          ),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5D5FEF), // More vibrant blue-purple
                const Color(
                  0xFF98DBDF,
                ).withOpacity(0.9), // Slightly more vibrant blue-teal
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D5FEF).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
            // Added blue border for consistency
            border: Border.all(
              color: const Color(0xFF5D5FEF).withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // User progress info
                  const Expanded(
                    child: Text(
                      'Your Learning Journey',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Animated badge
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: const Duration(seconds: 2),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF5D5FEF),
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Progress info
              Row(
                children: [
                  // Circular progress indicator
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: 0.45,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 8,
                          ),
                        ),
                        Center(
                          child: Text(
                            '45%',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressStat('Courses Completed', '2/6'),
                        const SizedBox(height: 8),
                        _buildProgressStat('Total Hours', '8.5 hrs'),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Continue learning - select first incomplete path
                    for (int i = 0; i < _featuredPaths.length; i++) {
                      if (_featuredPaths[i]['progress'] < 1.0) {
                        _togglePathDetailView(pathIndex: i);
                        break;
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: const Color(0xFF5D5FEF),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue Learning',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for progress stats
  Widget _buildProgressStat(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // Featured paths section
  Widget _buildFeaturedPathsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FEATURED PATHS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              // Filter button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 14,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Featured paths list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _featuredPaths.length,
          itemBuilder: (context, index) {
            final path = _featuredPaths[index];

            return AnimatedBuilder(
              animation: _slideAnimationController,
              builder: (context, child) {
                final delay = index * 0.15;
                final start = delay;
                final end = delay + 0.4;

                // Calculate current animation value
                final double t = _slideAnimationController.value;
                double opacity = 0.0;
                double yOffset = 20.0;

                if (t >= start) {
                  final double itemProgress = ((t - start) / (end - start))
                      .clamp(0.0, 1.0);
                  final double easeValue = Curves.easeOutCubic.transform(
                    itemProgress,
                  );

                  opacity = easeValue;
                  yOffset = 20 * (1 - easeValue);
                }

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, yOffset),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => _togglePathDetailView(pathIndex: index),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: path['color'].withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: path['color'].withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: path['color'].withOpacity(0.05),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: path['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                path['icon'],
                                color: path['color'],
                                size: 24,
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Title & subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    path['title'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    path['subtitle'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Category badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: path['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: path['color'].withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                path['category'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: path['color'],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            Text(
                              path['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 16),

                            // Progress bar
                            Row(
                              children: [
                                // Progress percentage
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${(path['progress'] * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: path['color'],
                                    ),
                                  ),
                                ),

                                // Progress bar
                                Expanded(
                                  child: Stack(
                                    children: [
                                      // Background
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),

                                      // Progress
                                      FractionallySizedBox(
                                        widthFactor: path['progress'],
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: path['color'],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Module count
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    '${path['completedModules']}/${path['totalModules']} modules',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Info chips
                                Row(
                                  children: [
                                    _buildInfoChip(
                                      Icons.timer_outlined,
                                      '${path['totalHours']} hrs',
                                      Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildInfoChip(
                                      Icons.signal_cellular_alt,
                                      path['level'],
                                      path['color'],
                                    ),
                                  ],
                                ),

                                // Continue/Start button
                                Container(
                                  decoration: BoxDecoration(
                                    color: path['color'],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    onPressed:
                                        () => _togglePathDetailView(
                                          pathIndex: index,
                                        ),
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    tooltip: 'Continue',
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    padding: const EdgeInsets.all(8),
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
          },
        ),
      ],
    );
  }

  // Additional learning paths section with auto-switching carousel
  Widget _buildAdditionalPathsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            'RECOMMENDED FOR YOU',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),

        // Carousel with indicators - using more reliable layout constraints
        SizedBox(
          height: 261,
          child: Column(
            children: [
              // Carousel in Expanded to take available space
              Expanded(
                child: PageView.builder(
                  controller: _carouselController,
                  itemCount: _additionalPaths.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentCarouselIndex = index;
                    });
                    // Reset the timer when manually swiped
                    _startCarouselTimer();
                    // Provide haptic feedback for better UX
                    HapticFeedback.selectionClick();
                  },
                  itemBuilder: (context, index) {
                    final path = _additionalPaths[index];

                    return AnimatedOpacity(
                      opacity: _currentCarouselIndex == index ? 1.0 : 0.9,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: path['color'].withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                          border: Border.all(
                            color: path['color'].withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Main content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Path header with improved design
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: path['color'].withOpacity(0.05),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon with animation
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: path['color'].withOpacity(
                                            0.12,
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: path['color'].withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          path['icon'],
                                          color: path['color'],
                                          size: 24,
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // Title & subtitle
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              path['title'],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              path['subtitle'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Category badge with polish
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: path['color'].withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: path['color'].withOpacity(
                                              0.2,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          path['category'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: path['color'],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Path content
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Description - reduced to single line for space efficiency
                                        Text(
                                          path['description'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            height: 1.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        // Stats and action row
                                        Column(
                                          children: [
                                            // Stats row
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  // Modules info
                                                  Expanded(
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .view_module_outlined,
                                                          size: 16,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade600,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '${path['totalModules']} modules',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                Colors
                                                                    .grey
                                                                    .shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Hours info
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.timer_outlined,
                                                        size: 16,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${path['estimatedHours']} hours',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                  const SizedBox(width: 12),

                                                  // Level badge
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: path['color']
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      path['level'],
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: path['color'],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Explore button - more compact for space efficiency
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  // Handle path start action
                                                  HapticFeedback.mediumImpact();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Starting ${path['title']}',
                                                      ),
                                                      behavior:
                                                          SnackBarBehavior
                                                              .floating,
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor:
                                                      path['color'],
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                ),
                                                child: const Text(
                                                  'Explore Path',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Subtle swipe indicators for better UX
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 4,
                              child: Center(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity:
                                      0.0, // Hidden by default, could be shown on touch
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 4,
                              child: Center(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity:
                                      0.0, // Hidden by default, could be shown on touch
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Page indicators - simplified approach based on best practices
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  height: 10,
                  child: Center(
                    child: ListView.builder(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: _additionalPaths.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Allow tapping on indicators to switch pages
                            _carouselController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: _currentCarouselIndex == index ? 10.0 : 6.0,
                            height: 6.0,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color:
                                  _currentCarouselIndex == index
                                      ? const Color(0xFF5D5FEF)
                                      : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Add Learning Path button with reduced margins
        Container(
          margin: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Handle add learning path action
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add Learning Path feature coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Learning Path'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5D5FEF),
              side: const BorderSide(color: Color(0xFF5D5FEF)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Learning ecosystems section (updated)
  Widget _buildLearningEcosystemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Text(
            'LEARNING ECOSYSTEMS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),

        // Grid of ecosystems
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
          ),
          itemCount: _learningEcosystems.length,
          itemBuilder: (context, index) {
            final ecosystem = _learningEcosystems[index];
            final bool isEnabled = ecosystem['isEnabled'] ?? false;

            return GestureDetector(
              onTap: () {
                if (isEnabled) {
                  // Handle ecosystem tap
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening ${ecosystem['title']}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  // Handle disabled ecosystem tap
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${ecosystem['title']} coming soon'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isEnabled ? Colors.white : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow:
                      isEnabled
                          ? [
                            BoxShadow(
                              color: ecosystem['color'].withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ]
                          : null,
                  border: Border.all(
                    color:
                        isEnabled
                            ? ecosystem['color'].withOpacity(0.2)
                            : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    if (isEnabled)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedBuilder(
                            animation: _pulseAnimationController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: 0.05 * _pulseAnimationController.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        ecosystem['color'],
                                        ecosystem['color'].withOpacity(0.0),
                                      ],
                                      center: Alignment.center,
                                      radius:
                                          0.8 +
                                          (_pulseAnimationController.value *
                                              0.3),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    // Content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with improved visual design
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isEnabled
                                    ? ecosystem['color'].withOpacity(0.12)
                                    : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            boxShadow:
                                isEnabled
                                    ? [
                                      BoxShadow(
                                        color: ecosystem['color'].withOpacity(
                                          0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Icon(
                            ecosystem['icon'],
                            color:
                                isEnabled
                                    ? ecosystem['color']
                                    : Colors.grey.shade500,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ecosystem['title'],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color:
                                isEnabled ? Colors.black : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ecosystem['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isEnabled
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Coming soon badge with improved design
                    if (!isEnabled)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'COMING SOON',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Path detail view
  Widget _buildPathDetailView(Size size) {
    final path = _featuredPaths[_selectedPathIndex];
    final modules = path['modules'] as List<Map<String, dynamic>>;

    return SingleChildScrollView(
      controller: _mainScrollController,
      physics: const BouncingScrollPhysics(),
      // Add padding at bottom to prevent content from being hidden behind the navbar
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Path header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: path['color'].withOpacity(0.05)),
            child: Row(
              children: [
                // Path icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: path['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(path['icon'], color: path['color'], size: 24),
                ),

                const SizedBox(width: 16),

                // Path title and info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path['title'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        path['subtitle'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: path['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: path['color'].withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    path['category'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: path['color'],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Path description
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ABOUT THIS PATH',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  path['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Path stats
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildPathDetailItem(
                    'Total Hours',
                    '${path['totalHours']}',
                    Icons.timer_outlined,
                    path['color'],
                  ),
                ),
                Expanded(
                  child: _buildPathDetailItem(
                    'Modules',
                    '${path['totalModules']}',
                    Icons.view_module_outlined,
                    path['color'],
                  ),
                ),
                Expanded(
                  child: _buildPathDetailItem(
                    'Completed',
                    '${(path['progress'] * 100).toInt()}%',
                    Icons.check_circle_outline,
                    path['color'],
                  ),
                ),
              ],
            ),
          ),

          // Modules section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MODULES',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // Module list
                ...List.generate(
                  modules.length,
                  (index) => _buildModuleItem(
                    modules[index],
                    index + 1,
                    path['color'],
                  ),
                ),
              ],
            ),
          ),

          // Action button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: ElevatedButton(
              onPressed: () {
                // Find first incomplete module
                int moduleIndex = modules.indexWhere(
                  (module) => !module['isCompleted'],
                );
                if (moduleIndex == -1)
                  moduleIndex = 0; // If all complete, start with first

                _showModuleStartDialog(path, modules[moduleIndex]);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: path['color'],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                path['progress'] > 0 ? 'Continue Path' : 'Start Path',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Module item in path detail
  Widget _buildModuleItem(
    Map<String, dynamic> module,
    int number,
    Color color,
  ) {
    final bool isCompleted = module['isCompleted'] ?? false;

    return GestureDetector(
      onTap: () {
        // Show module start dialog on tap anywhere on the item
        _showModuleStartDialog(_featuredPaths[_selectedPathIndex], module);
        HapticFeedback.selectionClick();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted ? color.withOpacity(0.3) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isCompleted
                      ? color.withOpacity(0.12)
                      : Colors.grey.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Module number or completion indicator with subtle animation
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.95, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOutSine,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: isCompleted ? value : 1.0, // Only animate if completed
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted ? color : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      boxShadow:
                          isCompleted
                              ? [
                                BoxShadow(
                                  color: color.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Center(
                      child:
                          isCompleted
                              ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                              : Text(
                                '$number',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isCompleted
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                ),
                              ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 16),

            // Module info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module['title'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? color : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        module['duration'],
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

            // Action button with enhanced visual design
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isCompleted ? color.withOpacity(0.1) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  _showModuleStartDialog(
                    _featuredPaths[_selectedPathIndex],
                    module,
                  );
                  HapticFeedback.selectionClick();
                },
                icon: Icon(
                  isCompleted ? Icons.replay : Icons.play_arrow,
                  color: isCompleted ? color : Colors.grey.shade700,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog for module details and starting
  void _showModuleStartDialog(
    Map<String, dynamic> path,
    Map<String, dynamic> module,
  ) {
    final bool isCompleted = module['isCompleted'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Module header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: path['color'].withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: path['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(path['icon'], color: path['color'], size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            module['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            path['title'],
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

              // Module info
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Duration and level
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.timer_outlined,
                            module['duration'],
                            Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          _buildInfoChip(
                            Icons.signal_cellular_alt,
                            path['level'],
                            path['color'],
                          ),

                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              Icons.check_circle_outline,
                              'Completed',
                              Colors.green,
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Module description
                      const Text(
                        'About this module',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        module['description'] ?? 'No description available.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // What you'll learn
                      const Text(
                        'What you\'ll learn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Learning outcomes
                      if (module['outcomes'] != null) ...[
                        ...List.generate(
                          (module['outcomes'] as List).length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: path['color'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    module['outcomes'][index],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          'No specific outcomes listed for this module.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Module structure
                      const Text(
                        'Module structure',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Module sections
                      ...List.generate(
                        4,
                        (index) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getModuleSection(module['title'], index),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                _getSectionDuration(index),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Container(
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
                child: Row(
                  children: [
                    // Save button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Save module
                          Navigator.pop(context);

                          // Show confirmation message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${module['title']} saved for later',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.bookmark_border_outlined,
                          color: Colors.black,
                        ),
                        tooltip: 'Save for Later',
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Start button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);

                          // Show success message with different text based on completion
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isCompleted
                                    ? 'Restarting ${module['title']}'
                                    : 'Starting ${module['title']}',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          // In a real app, we would start the actual module content here
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: path['color'],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          isCompleted ? 'Restart Module' : 'Start Module',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      },
    );
  }

  // Path detail item
  Widget _buildPathDetailItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // Info chip for path cards
  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Bottom navigation bar (original style)
  Widget _buildBottomNavBar() {
    return Container(
      height: 55,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 25.0),
      decoration: BoxDecoration(
        color: const Color(0xFF98DBDF), // Light blue-teal for AI Learning page
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
          // Chart icon - Navigate to AssessmentPage
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AssessmentPage()),
              );
            },
            child: _buildNavItem(Icons.bar_chart, false),
          ),
          // Clock icon (AI Learning) - Currently selected
          _buildNavItem(Icons.access_time, true),
          // Home icon - Navigate to Dashboard
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
            },
            child: _buildNavItem(Icons.home, false),
          ),
          // Journal icon - Navigate to JournalPage
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const JournalPage()),
              );
            },
            child: _buildNavItem(Icons.assessment, false),
          ),
          // Person icon - Navigate to FriendsGroupsPage
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
        size: 24,
      ),
    );
  }

  // Helper functions for dynamic content generation
  String _getModuleSection(String moduleTitle, int index) {
    // Generate appropriate sections based on module title
    if (moduleTitle.contains('Neural Networks')) {
      final sections = [
        'Neural Network Architecture',
        'Activation Functions',
        'Training Fundamentals',
        'Applications & Examples',
      ];
      return sections[index % sections.length];
    } else if (moduleTitle.contains('World')) {
      final sections = [
        'Introduction to World Building',
        'Creating Consistent Settings',
        'Environmental Details',
        'Character Integration',
      ];
      return sections[index % sections.length];
    } else {
      final sections = [
        'Introduction and Overview',
        'Core Concepts',
        'Practical Applications',
        'Interactive Exercise',
      ];
      return sections[index % sections.length];
    }
  }

  String _getSectionDuration(int index) {
    // Realistic section durations
    final durations = ['5 min', '10 min', '12 min', '8 min'];
    return durations[index % durations.length];
  }
}
