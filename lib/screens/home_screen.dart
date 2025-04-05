import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart' as logger_pkg;
import '../screens/dummy_data_generator.dart';
import '../screens/signup_page.dart';
import '../screens/friends_groups_page.dart';
import '../screens/assistant_page.dart';

/// A home screen widget that displays user information and database statistics.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Logger instance for better debugging
  final logger_pkg.Logger _logger = logger_pkg.Logger(
    printer: logger_pkg.PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: logger_pkg.DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // Animation controller for statistics cards
  late AnimationController _animationController;

  // User information
  String? _userEmail;
  bool _isLoading = true;
  String? _userName;
  String? _profileImagePath;
  bool _isGeneratingDummyData = false;

  // Database statistics
  final Map<String, dynamic> _dbStats = {
    'users': 0,
    'groups': 0,
    'assessments': 0,
    'sharedWithUser': 0,
    'sharedInGroup': 0,
    'submissions': {
      'total': 0,
      'inProgress': 0,
      'submitted': 0,
      'evaluated': 0,
    },
    'tags': 0,
    'friendships': 0,
  };
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for stat cards
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _initializeUser();
    _loadDatabaseStats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Initialize user and check if they already exist in Firestore
  Future<void> _initializeUser() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        _logger.i('Initializing user: ${currentUser.uid}');
        // Set email from authentication
        _userEmail = currentUser.email;

        // Check if user already exists in Firestore
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (!userDoc.exists) {
          _logger.w('User does not exist in Firestore yet');
          // User doesn't exist in Firestore yet
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Welcome! Use the Generate Dummy Data button to set up your account.',
                ),
                backgroundColor: Colors.blue,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            );
          }
        } else {
          _logger.i('User found in Firestore, fetching profile data');
          // User already exists, fetch their display name and profile image path
          final userData = userDoc.data();
          if (userData != null) {
            _userName = userData['displayName'];
            _profileImagePath = userData['photoURL'];

            // If we have a photoURL value from Firestore, check if it's a Firebase Storage URL
            if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
              if (_profileImagePath!.startsWith('gs://') ||
                  _profileImagePath!.startsWith('http')) {
                // This is a Firebase Storage URL, we can use it directly
                _logger.d(
                  'Using Firebase Storage profile image: $_profileImagePath',
                );
              } else {
                // This is a local file path, check if it exists
                final file = File(_profileImagePath!);
                if (!await file.exists()) {
                  _logger.w(
                    'Profile image file does not exist at path: $_profileImagePath',
                  );
                  _profileImagePath = null;
                }
              }
            }
          }
        }
      } else {
        _logger.w('No current user found');
      }

      // Update UI
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Start animation after UI is loaded
        _animationController.forward();
      }
    } catch (e, stackTrace) {
      _logger.e('Error initializing user', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up user profile: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Load all database statistics
  Future<void> _loadDatabaseStats() async {
    if (_isLoadingStats) return;

    setState(() {
      _isLoadingStats = true;
    });

    try {
      _logger.i('Loading database statistics');

      // Reset animation to play again when refreshing stats
      _animationController.reset();

      // Run queries in parallel for better performance
      await Future.wait([
        _countUsers(),
        _countGroups(),
        _countAssessments(),
        _countTags(),
        _countSharedAssessments(),
        _countUniqueFriendships(),
        _countSubmissionsByStatus(),
      ]);

      _logger.i('Database statistics loaded successfully');

      if (mounted) {
        // Start animation again after stats are loaded
        _animationController.forward();
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error loading database statistics',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading database statistics: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  /// Count total users
  Future<void> _countUsers() async {
    try {
      final usersSnapshot = await _firestore.collection('users').count().get();
      _dbStats['users'] = usersSnapshot.count;
      _logger.d('Total users count: ${_dbStats['users']}');
    } catch (e, stackTrace) {
      _logger.e('Error counting users', error: e, stackTrace: stackTrace);
    }
  }

  /// Count total groups
  Future<void> _countGroups() async {
    try {
      final groupsSnapshot =
          await _firestore.collection('groups').count().get();
      _dbStats['groups'] = groupsSnapshot.count;
      _logger.d('Total groups count: ${_dbStats['groups']}');
    } catch (e, stackTrace) {
      _logger.e('Error counting groups', error: e, stackTrace: stackTrace);
    }
  }

  /// Count total assessments
  Future<void> _countAssessments() async {
    try {
      final assessmentsSnapshot =
          await _firestore.collection('assessments').count().get();
      _dbStats['assessments'] = assessmentsSnapshot.count;
      _logger.d('Total assessments count: ${_dbStats['assessments']}');
    } catch (e, stackTrace) {
      _logger.e('Error counting assessments', error: e, stackTrace: stackTrace);
    }
  }

  /// Count total tags
  Future<void> _countTags() async {
    try {
      final tagsSnapshot = await _firestore.collection('tags').count().get();
      _dbStats['tags'] = tagsSnapshot.count;
      _logger.d('Total tags count: ${_dbStats['tags']}');
    } catch (e, stackTrace) {
      _logger.e('Error counting tags', error: e, stackTrace: stackTrace);
    }
  }

  /// Count shared assessments - improved version
  Future<void> _countSharedAssessments() async {
    try {
      _logger.d('Counting shared assessments');
      int sharedWithUserCount = 0;
      int sharedInGroupCount = 0;

      // Use batched query for better performance
      final usersQuery = await _firestore.collection('users').limit(10).get();
      _logger.d(
        'Processing ${usersQuery.docs.length} users for shared assessments',
      );

      for (final userDoc in usersQuery.docs) {
        // Query assessments where wasSharedWithUser is true
        final userSharedWithUserQuery =
            await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('assessments')
                .where('wasSharedWithUser', isEqualTo: true)
                .count()
                .get();

        sharedWithUserCount += userSharedWithUserQuery.count as int;

        // Query assessments where wasSharedInGroup is true
        final userSharedInGroupQuery =
            await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('assessments')
                .where('wasSharedInGroup', isEqualTo: true)
                .count()
                .get();

        sharedInGroupCount += userSharedInGroupQuery.count as int;
      }

      _dbStats['sharedWithUser'] = sharedWithUserCount;
      _dbStats['sharedInGroup'] = sharedInGroupCount;

      _logger.d(
        'Shared with users count: $sharedWithUserCount, Shared in groups count: $sharedInGroupCount',
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Error counting shared assessments',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Count unique friendships - improved version
  Future<void> _countUniqueFriendships() async {
    try {
      _logger.d('Counting unique friendships');
      final Set<String> processedPairs = {};
      int uniqueFriendshipsCount = 0;

      // Sample friendships from users
      final usersQuery = await _firestore.collection('users').limit(20).get();
      _logger.d('Processing ${usersQuery.docs.length} users for friendships');

      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.id;
        final userFriendsQuery =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('friends')
                .get();

        for (final friendDoc in userFriendsQuery.docs) {
          final friendId = friendDoc.id;

          // Create a unique identifier for each friendship pair (using alphabetical ordering)
          final friendshipPair = [userId, friendId]..sort();
          final pairKey = '${friendshipPair[0]}_${friendshipPair[1]}';

          if (!processedPairs.contains(pairKey)) {
            processedPairs.add(pairKey);
            uniqueFriendshipsCount++;
          }
        }
      }

      _dbStats['friendships'] = uniqueFriendshipsCount;
      _logger.d('Unique friendships count: $uniqueFriendshipsCount');
    } catch (e, stackTrace) {
      _logger.e(
        'Error counting unique friendships',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Count submissions and categorize by status
  Future<void> _countSubmissionsByStatus() async {
    try {
      _logger.d('Counting submissions by status');
      int totalSubmissions = 0;
      int inProgressCount = 0;
      int submittedCount = 0;
      int evaluatedCount = 0;

      // Sample submissions from users
      final usersQuery = await _firestore.collection('users').limit(10).get();
      _logger.d('Processing ${usersQuery.docs.length} users for submissions');

      for (final userDoc in usersQuery.docs) {
        final userAssessmentsQuery =
            await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('assessments')
                .limit(10)
                .get();

        for (final assessmentDoc in userAssessmentsQuery.docs) {
          final submissionsQuery =
              await _firestore
                  .collection('users')
                  .doc(userDoc.id)
                  .collection('assessments')
                  .doc(assessmentDoc.id)
                  .collection('submissions')
                  .get();

          totalSubmissions += submissionsQuery.docs.length;

          // Categorize submissions by status
          for (final submissionDoc in submissionsQuery.docs) {
            final status = submissionDoc.data()['status'] as String?;

            if (status == 'in-progress') {
              inProgressCount++;
            } else if (status == 'submitted') {
              submittedCount++;
            } else if (status == 'evaluated') {
              evaluatedCount++;
            }
          }
        }
      }

      _dbStats['submissions'] = {
        'total': totalSubmissions,
        'inProgress': inProgressCount,
        'submitted': submittedCount,
        'evaluated': evaluatedCount,
      };

      _logger.d(
        'Submissions counts - Total: $totalSubmissions, In Progress: $inProgressCount, Submitted: $submittedCount, Evaluated: $evaluatedCount',
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Error counting submissions by status',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Generate dummy data for all collections
  Future<void> _generateDummyData() async {
    if (_isGeneratingDummyData) {
      return; // Don't allow multiple simultaneous generations
    }

    setState(() {
      _isGeneratingDummyData = true;
    });

    try {
      _logger.i('Starting dummy data generation');

      // Use the updated DummyDataGenerator to create all dummy data
      final generator = DummyDataGenerator(context);
      await generator.generateAllDummyData();

      _logger.i('Dummy data generated successfully');

      // Refresh user data after generation
      await _initializeUser();

      // Refresh database statistics
      await _loadDatabaseStats();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dummy data generated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error generating dummy data',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating dummy data: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingDummyData = false;
        });
      }
    }
  }

  /// Method to handle sign out
  Future<void> _signOut(BuildContext context) async {
    try {
      _logger.i('Signing out user');

      // Update lastActive timestamp before signing out
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
          'isActive': false,
        });
      }

      await _auth.signOut();
      _logger.i('User signed out successfully');

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Navigate back to signup page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignupPage()),
      );
    } catch (e, stackTrace) {
      _logger.e('Error signing out', error: e, stackTrace: stackTrace);
      // Show error message if sign out fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Navigate to dashboard
  void _navigateToDashboard() {
    _logger.i('Navigating to dashboard');
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const FriendsGroupsPage()));
  }

  /// Navigate to AI Assistant page
  void _navigateToAIAssistant() {
    _logger.i('Navigating to AI Assistant');
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AIAssistantPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF6A3DE8), const Color(0xFF9C8AFF)],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                SizedBox(height: 20),
                Text(
                  'Loading Grade Genie...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Sliver app bar with profile info
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            floating: false,
            backgroundColor: const Color(0xFF6A3DE8),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF6A3DE8), const Color(0xFF9C8AFF)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Profile picture with improved shadow and borders
                          Hero(
                            tag: 'profileImage',
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    _profileImagePath != null &&
                                            _profileImagePath!.isNotEmpty
                                        ? _profileImagePath!.startsWith(
                                                  'http',
                                                ) ||
                                                _profileImagePath!.startsWith(
                                                  'gs://',
                                                )
                                            ? Image.network(
                                              _profileImagePath!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                _logger.w(
                                                  'Error loading profile image',
                                                  error: error,
                                                  stackTrace: stackTrace,
                                                );
                                                return Container(
                                                  color: Colors.white,
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 45,
                                                    color: Color(0xFF6A3DE8),
                                                  ),
                                                );
                                              },
                                            )
                                            : Image.file(
                                              File(_profileImagePath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                _logger.w(
                                                  'Error loading profile image file',
                                                  error: error,
                                                  stackTrace: stackTrace,
                                                );
                                                return Container(
                                                  color: Colors.white,
                                                  child: const Icon(
                                                    Icons.person,
                                                    size: 45,
                                                    color: Color(0xFF6A3DE8),
                                                  ),
                                                );
                                              },
                                            )
                                        : Container(
                                          color: Colors.white,
                                          child: const Icon(
                                            Icons.person,
                                            size: 45,
                                            color: Color(0xFF6A3DE8),
                                          ),
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // User info with improved typography
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName ?? 'Welcome',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 2),
                                        blurRadius: 5,
                                        color: Color.fromRGBO(0, 0, 0, 0.3),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_userEmail != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _userEmail!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                // Online status indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4ADE80),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Online',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Sign out button with improved design
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white,
                              ),
                              onPressed: () => _signOut(context),
                              tooltip: 'Sign Out',
                              splashRadius: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              // Refresh statistics button
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Statistics',
                  onPressed: _loadDatabaseStats,
                  splashRadius: 24,
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card with improved design
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6A3DE8,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.school,
                                  color: Color(0xFF6A3DE8),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome to Grade Genie!',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6A3DE8),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Your ultimate learning companion',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Explore your educational journey, connect with friends, join groups, and assess your progress with personalized learning recommendations.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Action buttons with improved design
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _navigateToDashboard,
                                  icon: const Icon(Icons.dashboard),
                                  label: const Text('Dashboard'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFC857),
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // New AI Assistant button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _navigateToAIAssistant,
                                  icon: const Icon(Icons.smart_toy),
                                  label: const Text('AI Assistant'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6A3DE8),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Database Statistics Section with improved header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A3DE8).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.bar_chart,
                            color: Color(0xFF6A3DE8),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Database Statistics',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6A3DE8),
                          ),
                        ),
                        const Spacer(),
                        // Stats refresh indicator
                        if (_isLoadingStats)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6A3DE8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // User and Group Stats
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Text(
                      'Users & Groups',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // User & Group stats in grid
                  _isLoadingStats
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                      : SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildAnimatedStatCard(
                              'Users',
                              _dbStats['users'] ?? 0,
                              Icons.people,
                              Colors.blue,
                              0,
                            ),
                            _buildAnimatedStatCard(
                              'Groups',
                              _dbStats['groups'] ?? 0,
                              Icons.group,
                              Colors.green,
                              1,
                            ),
                            _buildAnimatedStatCard(
                              'Friendships',
                              _dbStats['friendships'] ?? 0,
                              Icons.handshake,
                              Colors.pink,
                              2,
                            ),
                            _buildAnimatedStatCard(
                              'Tags',
                              _dbStats['tags'] ?? 0,
                              Icons.label,
                              Colors.purple,
                              3,
                            ),
                          ],
                        ),
                      ),

                  const SizedBox(height: 16),

                  // Assessments Stats
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Text(
                      'Assessments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // Assessment stats in grid
                  _isLoadingStats
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                      : SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildAnimatedStatCard(
                              'Assessments',
                              _dbStats['assessments'] ?? 0,
                              Icons.assignment,
                              Colors.orange,
                              4,
                            ),
                            _buildAnimatedStatCard(
                              'Shared with Users',
                              _dbStats['sharedWithUser'] ?? 0,
                              Icons.person_add,
                              Colors.indigo,
                              5,
                            ),
                            _buildAnimatedStatCard(
                              'Shared in Groups',
                              _dbStats['sharedInGroup'] ?? 0,
                              Icons.group_add,
                              Colors.deepOrange,
                              6,
                            ),
                          ],
                        ),
                      ),

                  const SizedBox(height: 16),

                  // Submissions Stats
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Text(
                      'Submissions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // Submission stats with detailed breakdown
                  _isLoadingStats
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                      : Column(
                        children: [
                          // Total submissions card
                          _buildSubmissionTotalCard(
                            _dbStats['submissions']['total'] ?? 0,
                            {
                              'In Progress':
                                  _dbStats['submissions']['inProgress'] ?? 0,
                              'Submitted':
                                  _dbStats['submissions']['submitted'] ?? 0,
                              'Evaluated':
                                  _dbStats['submissions']['evaluated'] ?? 0,
                            },
                          ),
                          const SizedBox(height: 12),
                          // Submission status breakdown in horizontal list
                          SizedBox(
                            height: 120,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _buildAnimatedStatCard(
                                  'In Progress',
                                  _dbStats['submissions']['inProgress'] ?? 0,
                                  Icons.hourglass_top,
                                  Colors.amber,
                                  7,
                                ),
                                _buildAnimatedStatCard(
                                  'Submitted',
                                  _dbStats['submissions']['submitted'] ?? 0,
                                  Icons.check_circle_outline,
                                  Colors.lightBlue,
                                  8,
                                ),
                                _buildAnimatedStatCard(
                                  'Evaluated',
                                  _dbStats['submissions']['evaluated'] ?? 0,
                                  Icons.grading,
                                  Colors.teal,
                                  9,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                  const SizedBox(height: 24),

                  // Dummy Data Generator with improved design
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.1),
                    color: const Color(0xFFF0F8FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Color(0xFF6A3DE8),
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6A3DE8,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.data_usage,
                                  color: Color(0xFF6A3DE8),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text(
                                  'Generate Dummy Data',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6A3DE8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Generate comprehensive dummy data including users, groups, assessments, submissions, and tags with proper relationships for testing and demonstration purposes.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isGeneratingDummyData
                                      ? null
                                      : _generateDummyData,
                              icon:
                                  _isGeneratingDummyData
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(Icons.play_arrow),
                              label: Text(
                                _isGeneratingDummyData
                                    ? 'Generating Data...'
                                    : 'Generate Data',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                disabledBackgroundColor: Colors.grey,
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToDashboard,
        backgroundColor: const Color(0xFFFFC857),
        foregroundColor: Colors.black87,
        elevation: 4,
        icon: const Icon(Icons.school),
        label: const Text('Dashboard'),
        tooltip: 'Go to Dashboard',
      ),
    );
  }

  // Helper method to build animated stat cards
  Widget _buildAnimatedStatCard(
    String title,
    int count,
    IconData icon,
    Color color,
    int index,
  ) {
    // Staggered animation delay based on index
    final delay = Duration(milliseconds: 100 * index);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          0.1 * (index % 5), // Stagger the start times
          1.0,
          curve: Curves.easeOut,
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(0.1 * (index % 5), 1.0, curve: Curves.easeOut),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
          width: 160,
          child: Card(
            elevation: 2,
            shadowColor: color.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: count),
                    duration: const Duration(milliseconds: 1000),
                    builder: (context, value, child) {
                      return Text(
                        value.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build submission total card with pie chart
  Widget _buildSubmissionTotalCard(int total, Map<String, int> breakdown) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.summarize, color: Colors.deepPurple, size: 20),
                SizedBox(width: 8),
                Text(
                  'Submission Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Total count with animation
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Submissions',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: total),
                        duration: const Duration(milliseconds: 1000),
                        builder: (context, value, child) {
                          return Text(
                            value.toString(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Breakdown in progress bars
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressIndicator(
                        'In Progress',
                        breakdown['In Progress'] ?? 0,
                        total,
                        Colors.amber,
                      ),
                      const SizedBox(height: 8),
                      _buildProgressIndicator(
                        'Submitted',
                        breakdown['Submitted'] ?? 0,
                        total,
                        Colors.lightBlue,
                      ),
                      const SizedBox(height: 8),
                      _buildProgressIndicator(
                        'Evaluated',
                        breakdown['Evaluated'] ?? 0,
                        total,
                        Colors.teal,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build progress indicators for submission breakdown
  Widget _buildProgressIndicator(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: percentage / 100),
          duration: const Duration(milliseconds: 1000),
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            );
          },
        ),
      ],
    );
  }
}
