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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  late AnimationController _animationController;

  String? _userEmail;
  bool _isLoading = true;
  String? _userName;
  String? _profileImagePath;
  bool _isGeneratingDummyData = false;

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

  Future<void> _initializeUser() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        _logger.i('Initializing user: ${currentUser.uid}');
        _userEmail = currentUser.email;

        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (!userDoc.exists) {
          _logger.w('User does not exist in Firestore yet');
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
          final userData = userDoc.data();
          if (userData != null) {
            _userName = userData['displayName'];
            _profileImagePath = userData['photoURL'];

            if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
              if (_profileImagePath!.startsWith('gs://') ||
                  _profileImagePath!.startsWith('http')) {
                _logger.d(
                  'Using Firebase Storage profile image: $_profileImagePath',
                );
              } else {
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

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

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

  Future<void> _loadDatabaseStats() async {
    if (_isLoadingStats) return;

    setState(() {
      _isLoadingStats = true;
    });

    try {
      _logger.i('Loading database statistics');

      _animationController.reset();

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

  Future<void> _countUsers() async {
    try {
      final usersSnapshot = await _firestore.collection('users').count().get();
      _dbStats['users'] = usersSnapshot.count;
      _logger.d('Total users count: ${_dbStats['users']}');
    } catch (e, stackTrace) {
      _logger.e('Error counting users', error: e, stackTrace: stackTrace);
    }
  }

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

  Future<void> _countTags() async {
    try {
      final tagsSnapshot = await _firestore.collection('tags').count().get();
      _dbStats['tags'] = tagsSnapshot.count;
      _logger.d('Total tags count: ${_dbStats['tags']}');
    } catch (e, stackTrace) {
      _logger.e('Error counting tags', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _countSharedAssessments() async {
    try {
      _logger.d('Counting shared assessments');
      int sharedWithUserCount = 0;
      int sharedInGroupCount = 0;

      final usersQuery = await _firestore.collection('users').limit(10).get();
      _logger.d(
        'Processing ${usersQuery.docs.length} users for shared assessments',
      );

      for (final userDoc in usersQuery.docs) {
        final userSharedWithUserQuery =
            await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('assessments')
                .where('wasSharedWithUser', isEqualTo: true)
                .count()
                .get();

        sharedWithUserCount += userSharedWithUserQuery.count as int;

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

  Future<void> _countUniqueFriendships() async {
    try {
      _logger.d('Counting unique friendships');
      final Set<String> processedPairs = {};
      int uniqueFriendshipsCount = 0;

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

  Future<void> _countSubmissionsByStatus() async {
    try {
      _logger.d('Counting submissions by status');
      int totalSubmissions = 0;
      int inProgressCount = 0;
      int submittedCount = 0;
      int evaluatedCount = 0;

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

  Future<void> _generateDummyData() async {
    if (_isGeneratingDummyData) {
      return;
    }

    setState(() {
      _isGeneratingDummyData = true;
    });

    try {
      _logger.i('Starting dummy data generation');

      final generator = DummyDataGenerator(context);
      await generator.generateAllDummyData();

      _logger.i('Dummy data generated successfully');

      await _initializeUser();

      await _loadDatabaseStats();

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

  Future<void> _signOut(BuildContext context) async {
    try {
      _logger.i('Signing out user');

      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
          'isActive': false,
        });
      }

      await _auth.signOut();
      _logger.i('User signed out successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignupPage()),
      );
    } catch (e, stackTrace) {
      _logger.e('Error signing out', error: e, stackTrace: stackTrace);
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

  void _navigateToDashboard() {
    _logger.i('Navigating to dashboard');
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const FriendsGroupsPage()));
  }

  void _navigateToAIAssistant() {
    _logger.i('Navigating to AI Assistant');
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AIAssistantPage()));
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 600;

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
          SliverAppBar(
            expandedHeight: screenSize.height * 0.28,
            pinned: true,
            floating: false,
            backgroundColor: const Color(0xFF6A3DE8),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.04,
                vertical: screenSize.height * 0.02,
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
                  padding: EdgeInsets.all(screenSize.width * 0.04),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: 'profileImage',
                            child: Container(
                              width: screenSize.width * 0.2,
                              height: screenSize.width * 0.2,
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
                                                  child: Icon(
                                                    Icons.person,
                                                    size:
                                                        screenSize.width * 0.1,
                                                    color: const Color(
                                                      0xFF6A3DE8,
                                                    ),
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
                                                  child: Icon(
                                                    Icons.person,
                                                    size:
                                                        screenSize.width * 0.1,
                                                    color: const Color(
                                                      0xFF6A3DE8,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                        : Container(
                                          color: Colors.white,
                                          child: Icon(
                                            Icons.person,
                                            size: screenSize.width * 0.1,
                                            color: const Color(0xFF6A3DE8),
                                          ),
                                        ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenSize.width * 0.04),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName ?? 'Welcome',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenSize.width * 0.06,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 2),
                                        blurRadius: 5,
                                        color: const Color.fromRGBO(
                                          0,
                                          0,
                                          0,
                                          0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                if (_userEmail != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: screenSize.height * 0.005,
                                    ),
                                    child: Text(
                                      _userEmail!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: screenSize.width * 0.035,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                SizedBox(height: screenSize.height * 0.01),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenSize.width * 0.025,
                                    vertical: screenSize.height * 0.005,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: screenSize.width * 0.02,
                                        height: screenSize.width * 0.02,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4ADE80),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: screenSize.width * 0.015),
                                      Text(
                                        'Online',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: screenSize.width * 0.03,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                              padding: EdgeInsets.all(screenSize.width * 0.02),
                              constraints: const BoxConstraints(),
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
              Padding(
                padding: EdgeInsets.only(right: screenSize.width * 0.02),
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Statistics',
                  onPressed: _loadDatabaseStats,
                  padding: EdgeInsets.all(screenSize.width * 0.02),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenSize.width * 0.04,
                vertical: screenSize.height * 0.01,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(screenSize.width * 0.05),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  screenSize.width * 0.03,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6A3DE8,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.school,
                                  color: const Color(0xFF6A3DE8),
                                  size: screenSize.width * 0.07,
                                ),
                              ),
                              SizedBox(width: screenSize.width * 0.04),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome to Grade Genie!',
                                      style: TextStyle(
                                        fontSize: screenSize.width * 0.055,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF6A3DE8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    SizedBox(height: screenSize.height * 0.005),
                                    Text(
                                      'Your ultimate learning companion',
                                      style: TextStyle(
                                        fontSize: screenSize.width * 0.035,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: screenSize.height * 0.02),
                          Text(
                            'Explore your educational journey, connect with friends, join groups, and assess your progress with personalized learning recommendations.',
                            style: TextStyle(
                              fontSize: screenSize.width * 0.04,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: screenSize.height * 0.03),
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenSize.width * 0.04,
                                      vertical: screenSize.height * 0.015,
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              SizedBox(width: screenSize.width * 0.03),
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenSize.width * 0.04,
                                      vertical: screenSize.height * 0.015,
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

                  SizedBox(height: screenSize.height * 0.03),

                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.02,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(screenSize.width * 0.02),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A3DE8).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bar_chart,
                            color: const Color(0xFF6A3DE8),
                            size: screenSize.width * 0.05,
                          ),
                        ),
                        SizedBox(width: screenSize.width * 0.03),
                        Text(
                          'Database Statistics',
                          style: TextStyle(
                            fontSize: screenSize.width * 0.05,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6A3DE8),
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingStats)
                          Container(
                            padding: EdgeInsets.all(screenSize.width * 0.015),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SizedBox(
                              width: screenSize.width * 0.04,
                              height: screenSize.width * 0.04,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF6A3DE8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth =
                          isSmallScreen
                              ? constraints.maxWidth * 0.4
                              : constraints.maxWidth * 0.3;

                      return Column(
                        children: [
                          _buildStatSection('Users & Groups', [
                            _buildAnimatedStatCard(
                              'Users',
                              _dbStats['users'] ?? 0,
                              Icons.people,
                              Colors.blue,
                              0,
                              cardWidth,
                            ),
                            _buildAnimatedStatCard(
                              'Groups',
                              _dbStats['groups'] ?? 0,
                              Icons.group,
                              Colors.green,
                              1,
                              cardWidth,
                            ),
                            _buildAnimatedStatCard(
                              'Friendships',
                              _dbStats['friendships'] ?? 0,
                              Icons.handshake,
                              Colors.pink,
                              2,
                              cardWidth,
                            ),
                          ]),

                          SizedBox(height: screenSize.height * 0.02),

                          _buildStatSection('Assessments', [
                            _buildAnimatedStatCard(
                              'Total',
                              _dbStats['assessments'] ?? 0,
                              Icons.assignment,
                              Colors.orange,
                              3,
                              cardWidth,
                            ),
                            _buildAnimatedStatCard(
                              'Shared Users',
                              _dbStats['sharedWithUser'] ?? 0,
                              Icons.person_add,
                              Colors.indigo,
                              4,
                              cardWidth,
                            ),
                            _buildAnimatedStatCard(
                              'Shared Groups',
                              _dbStats['sharedInGroup'] ?? 0,
                              Icons.group_add,
                              Colors.deepOrange,
                              5,
                              cardWidth,
                            ),
                          ]),
                        ],
                      );
                    },
                  ),
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

  Widget _buildStatSection(String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: cards),
        ),
      ],
    );
  }

  Widget _buildAnimatedStatCard(
    String title,
    int count,
    IconData icon,
    Color color,
    int index,
    double width,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.1 * index, 1.0, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(0.1 * index, 1.0, curve: Curves.easeOut),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: width,
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
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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
}
