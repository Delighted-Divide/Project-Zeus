import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'create_assessment_page.dart';
import 'dashboard.dart';
import 'journal_page.dart';
import 'assessment_detail_page.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'ai_learning_page.dart';
import 'friends_groups_page.dart';

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({super.key});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage>
    with TickerProviderStateMixin {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;

  // PageView controller
  late final PageController _pageController;

  // Animation controllers
  late final AnimationController _fabAnimationController;
  late final AnimationController _cardsAnimationController;
  late final AnimationController _categoryAnimationController;

  // Category information
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'My Assessments',
      'icon': Icons.edit_document,
      'color': const Color(0xFF6C63FF), // Blue-purple
      'secondaryColor': const Color(0xFF8B81FF),
      'illustration': Icons.assignment_outlined,
    },
    {
      'name': 'Shared',
      'icon': Icons.share,
      'color': const Color(0xFFFF6584), // Pink
      'secondaryColor': const Color(0xFFFF8FAA),
      'illustration': Icons.share_outlined,
    },
    {
      'name': 'Group',
      'icon': Icons.groups,
      'color': const Color(0xFF43E97B), // Green
      'secondaryColor': const Color(0xFF7DEEA2),
      'illustration': Icons.group_outlined,
    },
    {
      'name': 'Public',
      'icon': Icons.public,
      'color': const Color(0xFFFF9E40), // Orange
      'secondaryColor': const Color(0xFFFFBC7D),
      'illustration': Icons.public_outlined,
    },
  ];

  // State variables
  int _selectedCategoryIndex = 0;
  double _categoryIndicatorPosition = 0.0;
  bool _isFabExpanded = false;
  bool _isLoading = true;

  // Data caching
  Map<int, List<Map<String, dynamic>>> _cachedAssessments = {};
  Map<int, bool> _categoryLoaded = {};

  // Sort and filter state
  String _sortOption = 'newest'; // Default sort option
  final List<String> _sortOptions = [
    'newest',
    'oldest',
    'difficulty',
    'points',
    'rating',
  ];

  @override
  void initState() {
    super.initState();
    developer.log('AssessmentPage: Initializing state', name: 'AssessmentPage');

    // Initialize PageController with physics for smooth scrolling
    _pageController = PageController(
      initialPage: _selectedCategoryIndex,
      viewportFraction: 1.0,
    );

    // Initialize animation controllers
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _cardsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _categoryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Start with full animation
    _categoryAnimationController.value = 1.0;

    // Initialize current user and load data
    _initializeCurrentUser();

    // Add listener to page controller for indicator animation
    _pageController.addListener(_updateCategoryIndicator);
  }

  @override
  void dispose() {
    developer.log('AssessmentPage: Disposing state', name: 'AssessmentPage');
    _pageController.removeListener(_updateCategoryIndicator);
    _pageController.dispose();
    _fabAnimationController.dispose();
    _cardsAnimationController.dispose();
    _categoryAnimationController.dispose();
    super.dispose();
  }

  // Update the category indicator position based on page scroll
  void _updateCategoryIndicator() {
    final double page = _pageController.page ?? 0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = screenWidth / _categories.length;

    setState(() {
      _categoryIndicatorPosition = page * itemWidth;
    });
  }

  // Initialize current user and load assessments
  Future<void> _initializeCurrentUser() async {
    developer.log(
      'AssessmentPage: Initializing current user',
      name: 'AssessmentPage',
    );

    try {
      // Get current user
      _currentUserId = _auth.currentUser?.uid;
      developer.log(
        'AssessmentPage: Current user ID: $_currentUserId',
        name: 'AssessmentPage',
      );

      if (_currentUserId != null) {
        // Load initial category's assessments
        await _loadAssessmentsForCategory(_selectedCategoryIndex);
      } else {
        // Handle not logged in state
        developer.log(
          'AssessmentPage: No user logged in',
          name: 'AssessmentPage',
        );
        setState(() {
          _isLoading = false;
          _cachedAssessments[_selectedCategoryIndex] = [];
          _categoryLoaded[_selectedCategoryIndex] = true;
        });
      }
    } catch (e) {
      developer.log(
        'AssessmentPage: Error initializing user: $e',
        name: 'AssessmentPage',
        error: e,
      );
      setState(() {
        _isLoading = false;
        _cachedAssessments[_selectedCategoryIndex] = [];
        _categoryLoaded[_selectedCategoryIndex] = true;
      });
    }
  }

  // Load assessments for a specific category
  Future<void> _loadAssessmentsForCategory(int categoryIndex) async {
    // If already loaded and cached, use cached data
    if (_categoryLoaded[categoryIndex] == true) {
      developer.log(
        'AssessmentPage: Using cached data for category $categoryIndex',
        name: 'AssessmentPage',
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    developer.log(
      'AssessmentPage: Loading assessments for category: $categoryIndex',
      name: 'AssessmentPage',
    );
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUserId == null) {
        developer.log(
          'AssessmentPage: No user ID available for loading assessments',
          name: 'AssessmentPage',
        );
        return;
      }

      List<Map<String, dynamic>> loadedAssessments = [];

      switch (categoryIndex) {
        case 0: // My Assessments
          loadedAssessments = await _loadMyAssessments();
          break;
        case 1: // Shared with me
          loadedAssessments = await _loadSharedAssessments();
          break;
        case 2: // Group assessments
          loadedAssessments = await _loadGroupAssessments();
          break;
        case 3: // Public assessments
          loadedAssessments = await _loadPublicAssessments();
          break;
      }

      developer.log(
        'AssessmentPage: Loaded ${loadedAssessments.length} assessments',
        name: 'AssessmentPage',
      );

      // Apply sorting to loaded assessments
      _sortAssessmentsList(loadedAssessments);

      // Fetch submission data for My Assessments and Shared categories
      if (categoryIndex == 0 || categoryIndex == 1) {
        await _fetchSubmissionDataForAssessments(loadedAssessments);
      } else if (categoryIndex == 2) {
        // For Group assessments, fetch the oldest submission
        await _fetchOldestSubmissionForGroupAssessments(loadedAssessments);
      }

      // Update the cache and state
      setState(() {
        _cachedAssessments[categoryIndex] = loadedAssessments;
        _categoryLoaded[categoryIndex] = true;
        _isLoading = false;
      });

      // Reset and start the animation for cards
      _cardsAnimationController.reset();
      _cardsAnimationController.forward();
    } catch (e) {
      developer.log(
        'AssessmentPage: Error loading assessments: $e',
        name: 'AssessmentPage',
        error: e,
      );
      setState(() {
        _cachedAssessments[categoryIndex] = [];
        _categoryLoaded[categoryIndex] = true;
        _isLoading = false;
      });
    }
  }

  // NEW METHOD: Fetch submission data for assessments
  Future<void> _fetchSubmissionDataForAssessments(
    List<Map<String, dynamic>> assessments,
  ) async {
    developer.log(
      'AssessmentPage: Fetching submission data for ${assessments.length} assessments',
      name: 'AssessmentPage',
    );

    for (var assessment in assessments) {
      try {
        final String assessmentId = assessment['id'];

        // Get submissions for this assessment by the current user
        final submissionsSnapshot =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('assessments')
                .doc(assessmentId)
                .collection('submissions')
                .orderBy('submittedAt', descending: true)
                .get();

        if (submissionsSnapshot.docs.isNotEmpty) {
          // Get the most recent submission
          final latestSubmission = submissionsSnapshot.docs.first.data();
          assessment['hasSubmission'] = true;
          assessment['submissionStatus'] =
              latestSubmission['status'] ?? 'in-progress';

          // Check if any submission is evaluated
          bool hasEvaluatedSubmission = false;
          int bestScore = 0;

          for (var doc in submissionsSnapshot.docs) {
            final submissionData = doc.data();
            if (submissionData['status'] == 'evaluated') {
              hasEvaluatedSubmission = true;
              int score = submissionData['totalScore'] ?? 0;
              if (score > bestScore) {
                bestScore = score;
              }
            }
          }

          assessment['hasEvaluatedSubmission'] = hasEvaluatedSubmission;
          if (hasEvaluatedSubmission) {
            assessment['bestScore'] = bestScore;
            assessment['totalPoints'] =
                assessment['totalPoints'] ?? 100; // Fallback to 100 if not set
          }
        } else {
          assessment['hasSubmission'] = false;
        }
      } catch (e) {
        developer.log(
          'AssessmentPage: Error fetching submissions for assessment ${assessment['id']}: $e',
          name: 'AssessmentPage',
          error: e,
        );
        assessment['hasSubmission'] = false;
      }
    }
  }

  // NEW METHOD: Fetch oldest submission for group assessments
  Future<void> _fetchOldestSubmissionForGroupAssessments(
    List<Map<String, dynamic>> assessments,
  ) async {
    developer.log(
      'AssessmentPage: Fetching oldest submission data for ${assessments.length} group assessments',
      name: 'AssessmentPage',
    );

    for (var assessment in assessments) {
      try {
        final String assessmentId = assessment['id'];
        final String groupId = assessment['groupId'];

        // Get submissions for this assessment by the current user
        final submissionsSnapshot = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('channels')
            .where('type', isEqualTo: 'assessment')
            .get()
            .then((channels) async {
              for (var channel in channels.docs) {
                final assessmentsSnapshot =
                    await channel.reference
                        .collection('assessments')
                        .doc(assessmentId)
                        .collection('submissions')
                        .where('userId', isEqualTo: _currentUserId)
                        .orderBy('startedAt')
                        .limit(1)
                        .get();

                if (assessmentsSnapshot.docs.isNotEmpty) {
                  return assessmentsSnapshot;
                }
              }
              return null;
            });

        if (submissionsSnapshot != null &&
            submissionsSnapshot.docs.isNotEmpty) {
          // Get the oldest submission
          final oldestSubmission = submissionsSnapshot.docs.first.data();
          assessment['hasSubmission'] = true;
          assessment['submissionStatus'] =
              oldestSubmission['status'] ?? 'in-progress';

          // If evaluated, get the score
          if (oldestSubmission['status'] == 'evaluated') {
            assessment['score'] = oldestSubmission['totalScore'] ?? 0;
            assessment['totalPoints'] =
                assessment['totalPoints'] ?? 100; // Fallback to 100 if not set
          }
        } else {
          assessment['hasSubmission'] = false;
        }
      } catch (e) {
        developer.log(
          'AssessmentPage: Error fetching group submission for assessment ${assessment['id']}: $e',
          name: 'AssessmentPage',
          error: e,
        );
        assessment['hasSubmission'] = false;
      }
    }
  }

  // Load assessments created by the current user
  Future<List<Map<String, dynamic>>> _loadMyAssessments() async {
    List<Map<String, dynamic>> myAssessments = [];

    try {
      // First get all assessments from user's subcollection
      final userAssessmentsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('assessments')
              .get();

      developer.log(
        'AssessmentPage: Found ${userAssessmentsSnapshot.docs.length} total assessments in user collection',
        name: 'AssessmentPage',
      );

      for (var doc in userAssessmentsSnapshot.docs) {
        final assessmentData = doc.data();
        final assessmentId = doc.id;

        // Get the full assessment data from main collection
        final mainAssessmentDoc =
            await _firestore.collection('assessments').doc(assessmentId).get();

        if (mainAssessmentDoc.exists) {
          final mainData = mainAssessmentDoc.data() ?? {};

          // Add to my assessments ONLY if creatorId matches current user
          if (mainData['creatorId'] == _currentUserId) {
            Map<String, dynamic> assessment = {
              'id': assessmentId,
              'title':
                  assessmentData['title'] ??
                  mainData['title'] ??
                  'Untitled Assessment',
              'description':
                  mainData['description'] ?? 'No description available',
              'createdAt': assessmentData['createdAt'] ?? mainData['createdAt'],
              'difficulty': mainData['difficulty'] ?? 'Medium',
              'totalPoints': mainData['totalPoints'] ?? 0,
              'sourceType': 'created',
              'madeByAI': mainData['madeByAI'] ?? false,
              'isPublic': mainData['isPublic'] ?? false,
              'status': 'created', // Default status
              'creatorId': mainData['creatorId'],
            };

            myAssessments.add(assessment);
            developer.log(
              'AssessmentPage: Added assessment ${assessment['title']} to my assessments',
              name: 'AssessmentPage',
            );
          }
        }
      }
    } catch (e) {
      developer.log(
        'AssessmentPage: Error loading my assessments: $e',
        name: 'AssessmentPage',
        error: e,
      );
    }

    return myAssessments;
  }

  // Load assessments shared with the current user
  Future<List<Map<String, dynamic>>> _loadSharedAssessments() async {
    List<Map<String, dynamic>> sharedAssessments = [];

    try {
      // Get assessments from user's collection that have wasSharedWithUser = true
      final userAssessmentsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('assessments')
              .where('wasSharedWithUser', isEqualTo: true)
              .get();

      developer.log(
        'AssessmentPage: Found ${userAssessmentsSnapshot.docs.length} assessments shared with user',
        name: 'AssessmentPage',
      );

      for (var doc in userAssessmentsSnapshot.docs) {
        final assessmentData = doc.data();
        final assessmentId = doc.id;

        // Get the full assessment data from main collection
        final mainAssessmentDoc =
            await _firestore.collection('assessments').doc(assessmentId).get();

        if (mainAssessmentDoc.exists) {
          final mainData = mainAssessmentDoc.data() ?? {};

          // Get creator info
          String creatorName = 'Unknown User';
          if (mainData['creatorId'] != null) {
            final creatorDoc =
                await _firestore
                    .collection('users')
                    .doc(mainData['creatorId'])
                    .get();

            if (creatorDoc.exists) {
              creatorName = creatorDoc.data()?['displayName'] ?? 'Unknown User';
            }
          }

          // Create the assessment object
          Map<String, dynamic> assessment = {
            'id': assessmentId,
            'title':
                assessmentData['title'] ??
                mainData['title'] ??
                'Untitled Assessment',
            'description':
                mainData['description'] ?? 'No description available',
            'createdAt': assessmentData['createdAt'] ?? mainData['createdAt'],
            'difficulty': mainData['difficulty'] ?? 'Medium',
            'totalPoints': mainData['totalPoints'] ?? 0,
            'sourceType': 'shared',
            'madeByAI': mainData['madeByAI'] ?? false,
            'isPublic': mainData['isPublic'] ?? false,
            'creatorId': mainData['creatorId'],
            'creatorName': creatorName,
            'wasSharedWithUser': true,
          };

          sharedAssessments.add(assessment);
          developer.log(
            'AssessmentPage: Added shared assessment ${assessment['title']}',
            name: 'AssessmentPage',
          );
        }
      }
    } catch (e) {
      developer.log(
        'AssessmentPage: Error loading shared assessments: $e',
        name: 'AssessmentPage',
        error: e,
      );
    }

    return sharedAssessments;
  }

  // Load assessments from groups
  Future<List<Map<String, dynamic>>> _loadGroupAssessments() async {
    List<Map<String, dynamic>> groupAssessments = [];

    try {
      // Get assessments from user's collection that have wasSharedInGroup = true
      final userAssessmentsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('assessments')
              .where('wasSharedInGroup', isEqualTo: true)
              .get();

      developer.log(
        'AssessmentPage: Found ${userAssessmentsSnapshot.docs.length} assessments shared in groups',
        name: 'AssessmentPage',
      );

      // Get all groups the user belongs to
      final userGroupsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('groups')
              .get();

      List<String> userGroupIds =
          userGroupsSnapshot.docs.map((doc) => doc.id).toList();

      developer.log(
        'AssessmentPage: User belongs to ${userGroupIds.length} groups',
        name: 'AssessmentPage',
      );

      if (userGroupIds.isEmpty) {
        return []; // No groups, so no group assessments
      }

      // Process each assessment shared in a group
      for (var doc in userAssessmentsSnapshot.docs) {
        final assessmentData = doc.data();
        final assessmentId = doc.id;

        // Get the full assessment data from main collection
        final mainAssessmentDoc =
            await _firestore.collection('assessments').doc(assessmentId).get();

        if (!mainAssessmentDoc.exists) continue;

        final mainData = mainAssessmentDoc.data() ?? {};

        // Check which of the user's groups have this assessment
        for (var groupId in userGroupIds) {
          // Check if this group is in the sharedWithGroups collection
          final groupShareDoc =
              await _firestore
                  .collection('assessments')
                  .doc(assessmentId)
                  .collection('sharedWithGroups')
                  .doc(groupId)
                  .get();

          if (groupShareDoc.exists) {
            final groupShareData = groupShareDoc.data() ?? {};

            // Get group name
            String groupName = 'Unknown Group';
            final groupDoc =
                userGroupsSnapshot.docs
                    .where((doc) => doc.id == groupId)
                    .firstOrNull;
            final groupData = groupDoc?.data();

            if (groupData != null) {
              groupName = groupData['name'] ?? 'Unknown Group';
            }

            // Create assessment object with group data
            Map<String, dynamic> assessment = {
              'id': assessmentId,
              'title':
                  assessmentData['title'] ??
                  mainData['title'] ??
                  'Untitled Assessment',
              'description':
                  mainData['description'] ?? 'No description available',
              'groupId': groupId,
              'groupName': groupName,
              'sourceType': 'group',
              'createdAt': assessmentData['createdAt'] ?? mainData['createdAt'],
              'difficulty': mainData['difficulty'] ?? 'Medium',
              'totalPoints': mainData['totalPoints'] ?? 0,
              'madeByAI': mainData['madeByAI'] ?? false,
              'startTime': groupShareData['startTime'],
              'endTime': groupShareData['endTime'],
              'hasTimer': groupShareData['hasTimer'] ?? false,
              'timerDuration': groupShareData['timerDuration'],
              'sharedBy': groupShareData['sharedBy'],
              'sharedAt': groupShareData['sharedAt'],
              'wasSharedInGroup': true,
            };

            // Avoid duplicate assessments (same assessment shared in multiple groups)
            if (!groupAssessments.any((item) => item['id'] == assessmentId)) {
              groupAssessments.add(assessment);
              developer.log(
                'AssessmentPage: Added group assessment ${assessment['title']} from group $groupName',
                name: 'AssessmentPage',
              );
            }

            // We found a match, no need to check other groups for this assessment
            break;
          }
        }
      }
    } catch (e) {
      developer.log(
        'AssessmentPage: Error loading group assessments: $e',
        name: 'AssessmentPage',
        error: e,
      );
    }

    return groupAssessments;
  }

  // Load public assessments
  Future<List<Map<String, dynamic>>> _loadPublicAssessments() async {
    List<Map<String, dynamic>> publicAssessments = [];

    try {
      // Query all public assessments
      final publicAssessmentsSnapshot =
          await _firestore
              .collection('assessments')
              .where('isPublic', isEqualTo: true)
              .limit(20)
              .get();

      developer.log(
        'AssessmentPage: Found ${publicAssessmentsSnapshot.docs.length} public assessments',
        name: 'AssessmentPage',
      );

      for (var doc in publicAssessmentsSnapshot.docs) {
        final assessmentData = doc.data();
        final assessmentId = doc.id;

        // Get creator info
        String creatorName = 'Unknown User';
        if (assessmentData['creatorId'] != null) {
          final creatorDoc =
              await _firestore
                  .collection('users')
                  .doc(assessmentData['creatorId'])
                  .get();

          if (creatorDoc.exists) {
            creatorName = creatorDoc.data()?['displayName'] ?? 'Unknown User';
          }
        }

        Map<String, dynamic> assessment = {
          'id': assessmentId,
          'title': assessmentData['title'] ?? 'Untitled Assessment',
          'description':
              assessmentData['description'] ?? 'No description available',
          'createdAt': assessmentData['createdAt'],
          'difficulty': assessmentData['difficulty'] ?? 'Medium',
          'totalPoints': assessmentData['totalPoints'] ?? 0,
          'creatorId': assessmentData['creatorId'],
          'creatorName': creatorName,
          'sourceType': 'public',
          'madeByAI': assessmentData['madeByAI'] ?? false,
          'rating': assessmentData['rating'] ?? 0.0,
          'isOwnedByCurrentUser': assessmentData['creatorId'] == _currentUserId,
        };

        publicAssessments.add(assessment);
        developer.log(
          'AssessmentPage: Added public assessment: ${assessment['title']}',
          name: 'AssessmentPage',
        );
      }
    } catch (e) {
      developer.log(
        'AssessmentPage: Error loading public assessments: $e',
        name: 'AssessmentPage',
        error: e,
      );
    }

    return publicAssessments;
  }

  // Sort assessments based on selected option
  void _sortAssessmentsList(List<Map<String, dynamic>> assessments) {
    developer.log(
      'AssessmentPage: Sorting assessments by $_sortOption',
      name: 'AssessmentPage',
    );

    switch (_sortOption) {
      case 'newest':
        assessments.sort((a, b) {
          if (a['createdAt'] == null || b['createdAt'] == null) return 0;
          return b['createdAt'].compareTo(a['createdAt']);
        });
        break;
      case 'oldest':
        assessments.sort((a, b) {
          if (a['createdAt'] == null || b['createdAt'] == null) return 0;
          return a['createdAt'].compareTo(b['createdAt']);
        });
        break;
      case 'difficulty':
        // Custom sort order for difficulty
        final difficultyOrder = {
          'Easy': 0,
          'Medium': 1,
          'Hard': 2,
          'Expert': 3,
        };
        assessments.sort((a, b) {
          final aDifficulty = (a['difficulty'] ?? 'Medium').toString();
          final bDifficulty = (b['difficulty'] ?? 'Medium').toString();
          return (difficultyOrder[aDifficulty] ?? 1).compareTo(
            difficultyOrder[bDifficulty] ?? 1,
          );
        });
        break;
      case 'points':
        assessments.sort((a, b) {
          final aPoints = a['totalPoints'] ?? 0;
          final bPoints = b['totalPoints'] ?? 0;
          return bPoints.compareTo(aPoints); // Higher points first
        });
        break;
      case 'rating':
        assessments.sort((a, b) {
          final aRating = a['rating'] ?? 0.0;
          final bRating = b['rating'] ?? 0.0;
          return bRating.compareTo(aRating); // Higher rating first
        });
        break;
    }
  }

  // Resort and refresh current category's assessments
  void _resortCurrentAssessments() {
    if (_cachedAssessments.containsKey(_selectedCategoryIndex)) {
      final assessments = _cachedAssessments[_selectedCategoryIndex] ?? [];
      _sortAssessmentsList(assessments);
      setState(() {
        _cachedAssessments[_selectedCategoryIndex] = assessments;
      });
    }
  }

  // Share assessment with user
  Future<void> _shareAssessment(
    String assessmentId,
    String assessmentTitle,
  ) async {
    developer.log(
      'AssessmentPage: Sharing assessment $assessmentId',
      name: 'AssessmentPage',
    );

    // Get current category color
    final Color categoryColor = _categories[_selectedCategoryIndex]['color'];

    // Show a beautiful snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 75, left: 20, right: 20),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.share, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Sharing "$assessmentTitle" - Coming soon!',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Navigate to create assessment
  void _navigateToCreateAssessment(String type) {
    developer.log(
      'AssessmentPage: Navigating to create assessment page with type: $type',
      name: 'AssessmentPage',
    );

    // Close the FAB menu
    setState(() {
      _isFabExpanded = false;
    });

    // Reset FAB animation
    _fabAnimationController.reverse();

    // Navigate to the create assessment page
    Future.delayed(const Duration(milliseconds: 200), () {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  CreateAssessmentPage(type: type),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      ).then((_) {
        // Reset cached data to force reload
        setState(() {
          _categoryLoaded[0] = false; // Reset "My Assessments" category
        });

        // Load assessments for the current category
        _loadAssessmentsForCategory(_selectedCategoryIndex);
      });
    });
  }

  // Choose a sort option
  void _chooseSortOption() {
    developer.log(
      'AssessmentPage: Opening sort options',
      name: 'AssessmentPage',
    );

    final Color categoryColor = _categories[_selectedCategoryIndex]['color'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.sort, color: categoryColor),
                      const SizedBox(width: 12),
                      Text(
                        'Sort Assessments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),

                // Sort options
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSortOption(
                        'newest',
                        'Newest First',
                        Icons.arrow_downward,
                        categoryColor,
                      ),
                      _buildSortOption(
                        'oldest',
                        'Oldest First',
                        Icons.arrow_upward,
                        categoryColor,
                      ),
                      _buildSortOption(
                        'difficulty',
                        'By Difficulty',
                        Icons.signal_cellular_alt,
                        categoryColor,
                      ),
                      _buildSortOption(
                        'points',
                        'Highest Points',
                        Icons.star,
                        categoryColor,
                      ),
                      _buildSortOption(
                        'rating',
                        'Highest Rating',
                        Icons.thumb_up,
                        categoryColor,
                      ),
                    ],
                  ),
                ),

                // Safe area padding
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build a sort option
  Widget _buildSortOption(
    String value,
    String label,
    IconData icon,
    Color categoryColor,
  ) {
    final bool isSelected = _sortOption == value;

    return InkWell(
      onTap: () {
        setState(() {
          _sortOption = value;
        });
        Navigator.pop(context);
        _resortCurrentAssessments();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected ? categoryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? categoryColor : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 18,
              ),
            ),

            const SizedBox(width: 16),

            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? categoryColor : Colors.black87,
              ),
            ),

            const Spacer(),

            // Selected indicator
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to format timestamps into readable dates
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Today, ${DateFormat('h:mm a').format(dateTime)}';
    } else if (date == yesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
    } else if (date == tomorrow) {
      return 'Tomorrow, ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
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
        return const Color(0xFF6C63FF); // Purple
    }
  }

  // Build bottom navigation bar
  Widget _buildBottomNavBar() {
    // Use the current category color for the nav bar
    final Color navBarColor = _categories[_selectedCategoryIndex]['color'];

    return Container(
      height: 55,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 25.0),
      decoration: BoxDecoration(
        color: navBarColor, // Dynamic color based on selected category
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
          _buildNavItem(Icons.bar_chart, true), // Bar chart icon is selected
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
          // Journal icon with navigation to JournalPage
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const JournalPage()),
              );
            },
            child: _buildNavItem(Icons.assessment, false),
          ),
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

  // Build a navigation item
  Widget _buildNavItem(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color:
            isSelected
                ? _categories[_selectedCategoryIndex]['color']
                : Colors.white,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    developer.log('AssessmentPage: Building UI', name: 'AssessmentPage');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Custom app bar
                  _buildAppBar(),

                  // Category selection
                  _buildCategorySelector(),

                  // Content area
                  Expanded(child: _buildPageView()),
                ],
              ),

              // Floating action button
              Positioned(
                right: 20,
                bottom:
                    100 +
                    MediaQuery.of(
                      context,
                    ).padding.bottom, // Adjusted for nav bar
                child: _buildFab(),
              ),

              // Bottom navigation bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomNavBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build app bar - MODIFIED: Removed back button
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Spacer (replaced back button)
          const SizedBox(width: 40),

          // App title
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: _categories[0]['color'],
              end: _categories[_selectedCategoryIndex]['color'],
            ),
            duration: const Duration(milliseconds: 300),
            builder: (context, color, child) {
              return Text(
                'Assessments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              );
            },
          ),

          // Sort button
          Container(
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _chooseSortOption,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.sort,
                    size: 20,
                    color: _categories[_selectedCategoryIndex]['color'],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build category selector
  Widget _buildCategorySelector() {
    final double itemWidth =
        MediaQuery.of(context).size.width / _categories.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Column(
        children: [
          // Category items
          SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_categories.length, (index) {
                final category = _categories[index];
                final bool isSelected = index == _selectedCategoryIndex;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();

                    // Only do something if selecting a different category
                    if (index != _selectedCategoryIndex) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });

                      // Animate to the selected page
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );

                      // Load data for the selected category if not already loaded
                      if (_categoryLoaded[index] != true) {
                        _loadAssessmentsForCategory(index);
                      }
                    }
                  },
                  child: AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: isSelected ? 16 : 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color:
                            isSelected
                                ? category['color']
                                : Colors.grey.shade600,
                      ),
                      child: Text(category['name']),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Indicator
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 3,
            child: Stack(
              children: [
                // Background line
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),

                // Animated indicator
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: _categoryIndicatorPosition + (itemWidth - 40) / 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    decoration: BoxDecoration(
                      color: _categories[_selectedCategoryIndex]['color'],
                      borderRadius: BorderRadius.circular(1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _categories[_selectedCategoryIndex]['color']
                              .withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
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
    );
  }

  // Build page view
  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      itemCount: _categories.length,
      onPageChanged: (index) {
        setState(() {
          _selectedCategoryIndex = index;
        });

        // Load data for the selected category if not already loaded
        if (_categoryLoaded[index] != true) {
          _loadAssessmentsForCategory(index);
        }
      },
      itemBuilder: (context, index) {
        final category = _categories[index];
        final List<Map<String, dynamic>> assessments =
            _cachedAssessments[index] ?? [];
        final bool isLoading = _isLoading && _selectedCategoryIndex == index;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child:
              isLoading
                  ? _buildLoadingState(category)
                  : assessments.isEmpty
                  ? _buildEmptyState(category)
                  : _buildAssessmentList(assessments, category),
        );
      },
    );
  }

  // Build loading state with shimmer effect
  Widget _buildLoadingState(Map<String, dynamic> category) {
    return ListView.builder(
      key: const ValueKey('loading'),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
              // Shimmer header
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: category['color'].withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),

              // Shimmer content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Container(
                      width: 200 + (index * 40 % 100),
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 250,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Badges
                    Row(
                      children: [
                        Container(
                          width: 100,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 150,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
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
      },
    );
  }

  // Build empty state
  Widget _buildEmptyState(Map<String, dynamic> category) {
    String message;
    String buttonText;

    switch (_categories.indexOf(category)) {
      case 0: // My Assessments
        message =
            'You haven\'t created any assessments yet.\nCreate one to get started!';
        buttonText = 'Create Assessment';
        break;
      case 1: // Shared
        message = 'No assessments have been shared with you yet.';
        buttonText = 'Find Friends';
        break;
      case 2: // Group
        message =
            'No group assessments available.\nJoin a group to see assessments.';
        buttonText = 'Join a Group';
        break;
      case 3: // Public
        message =
            'No public assessments available.\nExplore community assessments.';
        buttonText = 'Refresh';
        break;
      default:
        message = 'No assessments available.';
        buttonText = 'Create New';
    }

    return Container(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(seconds: 2),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: category['color'].withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category['illustration'],
                      size: 80,
                      color: category['color'],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 30),

            // Action button
            ElevatedButton(
              onPressed: () {
                final index = _categories.indexOf(category);
                if (index == 0) {
                  // For My Assessments, show FAB
                  setState(() {
                    _isFabExpanded = true;
                  });
                  _fabAnimationController.forward();
                } else if (index == 3) {
                  // For Public, refresh
                  setState(() {
                    _categoryLoaded[index] = false;
                  });
                  _loadAssessmentsForCategory(index);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: category['color'],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                elevation: 8,
                shadowColor: category['color'].withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Add bottom spacing
            SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ],
        ),
      ),
    );
  }

  // Build list of assessments
  Widget _buildAssessmentList(
    List<Map<String, dynamic>> assessments,
    Map<String, dynamic> category,
  ) {
    return ListView.builder(
      key: const ValueKey('list'),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: assessments.length,
      itemBuilder: (context, index) {
        return _buildAssessmentCard(assessments[index], category, index);
      },
    );
  }

  // Build assessment card - MODIFIED with submission status indicators
  Widget _buildAssessmentCard(
    Map<String, dynamic> assessment,
    Map<String, dynamic> category,
    int index,
  ) {
    final isAiGenerated = assessment['madeByAI'] == true;
    final String difficulty = assessment['difficulty'] ?? 'Medium';
    final Color difficultyColor = _getDifficultyColor(difficulty);
    final int points = assessment['totalPoints'] ?? 0;
    final Color categoryColor = category['color'];

    // Check if assessment is locked (start time in future)
    bool isLocked = false;
    String? lockReason;

    // Check start time for group assessments or assessments with a start time
    if (assessment['sourceType'] == 'group' ||
        assessment['startTime'] != null) {
      final startTime =
          assessment['startTime'] is Timestamp
              ? assessment['startTime'].toDate()
              : null;

      if (startTime != null && startTime.isAfter(DateTime.now())) {
        isLocked = true;
        lockReason =
            'Available on ${DateFormat('MMM d, h:mm a').format(startTime)}';
      }
    }

    // Determine button text and status based on submission status
    String buttonText = 'Attempt';
    Color statusColor = categoryColor;
    IconData statusIcon = Icons.play_arrow;

    if (assessment['hasSubmission'] == true) {
      final String status = assessment['submissionStatus'];

      switch (status) {
        case 'in-progress':
          buttonText = 'Continue';
          statusIcon = Icons.edit;
          statusColor = Colors.blue;
          break;
        case 'submitted':
          buttonText = 'View';
          statusIcon = Icons.check_circle;
          statusColor = Colors.orange;
          break;
        case 'evaluated':
          buttonText = 'Review';
          statusIcon = Icons.check_circle;
          statusColor = Colors.green;
          break;
        default:
        // Use defaults
      }
    }

    // Animated card appearance
    return AnimatedBuilder(
      animation: _cardsAnimationController,
      builder: (context, child) {
        // Calculate delay based on index
        final double delay = index * 0.1;
        final double start = delay;
        final double end = delay + 0.4;

        // Calculate current animation value
        final double t = _cardsAnimationController.value;
        double opacity = 0.0;
        double yOffset = 50.0;

        if (t >= start) {
          final double itemProgress = ((t - start) / (end - start)).clamp(
            0.0,
            1.0,
          );
          final double easeValue = Curves.easeOutCubic.transform(itemProgress);

          opacity = easeValue;
          yOffset = 50 * (1 - easeValue);
        }

        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, yOffset), child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          // Navigate to assessment detail
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      AssessmentDetailPage(assessmentId: assessment['id']),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                const begin = Offset(0.0, 0.1);
                const end = Offset.zero;
                const curve = Curves.easeOutCubic;
                var tween = Tween(
                  begin: begin,
                  end: end,
                ).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor, category['secondaryColor']],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Expanded(
                          child: Text(
                            assessment['title'] ?? 'Untitled Assessment',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // AI badge
                        if (isAiGenerated)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 2),
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
                                  size: 12,
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

                        // Lock badge
                        if (isLocked)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 2),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_clock,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Description
                    Text(
                      assessment['description'] ?? 'No description available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    // Badges row - difficulty, points, rating, score
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          // Difficulty badge
                          _buildBadge(
                            icon:
                                difficulty == 'Easy'
                                    ? Icons.sentiment_satisfied
                                    : difficulty == 'Medium'
                                    ? Icons.sentiment_neutral
                                    : difficulty == 'Hard'
                                    ? Icons.sentiment_dissatisfied
                                    : Icons.psychology,
                            label: difficulty,
                            color: difficultyColor,
                          ),

                          const SizedBox(width: 12),

                          // Points badge
                          _buildBadge(
                            icon: Icons.star,
                            label: '$points pts',
                            color: Colors.amber,
                          ),

                          // Rating badge if available
                          if (assessment['rating'] != null &&
                              assessment['rating'] > 0) ...[
                            const SizedBox(width: 12),
                            _buildBadge(
                              icon: Icons.thumb_up,
                              label: assessment['rating'].toStringAsFixed(1),
                              color: Colors.blue,
                            ),
                          ],

                          // Score badge if evaluated
                          if ((assessment['hasEvaluatedSubmission'] == true ||
                                  assessment['submissionStatus'] ==
                                      'evaluated') &&
                              (assessment['bestScore'] != null ||
                                  assessment['score'] != null)) ...[
                            const SizedBox(width: 12),
                            _buildBadge(
                              icon: Icons.emoji_events,
                              label:
                                  '${assessment['bestScore'] ?? assessment['score'] ?? 0}/${assessment['totalPoints']}',
                              color: Colors.green,
                            ),
                          ],

                          // Status badge if has submission
                          if (assessment['hasSubmission'] == true) ...[
                            const SizedBox(width: 12),
                            _buildBadge(
                              icon:
                                  assessment['submissionStatus'] ==
                                          'in-progress'
                                      ? Icons.edit
                                      : assessment['submissionStatus'] ==
                                          'submitted'
                                      ? Icons.check_circle_outline
                                      : Icons.verified,
                              label:
                                  assessment['submissionStatus'] ==
                                          'in-progress'
                                      ? 'In Progress'
                                      : assessment['submissionStatus'] ==
                                          'submitted'
                                      ? 'Submitted'
                                      : 'Evaluated',
                              color:
                                  assessment['submissionStatus'] ==
                                          'in-progress'
                                      ? Colors.blue
                                      : assessment['submissionStatus'] ==
                                          'submitted'
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Source info
                    _buildSourceInfo(assessment, categoryColor),

                    const SizedBox(height: 12),

                    // Footer - action buttons and information
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Due date or lock reason
                        Expanded(
                          child:
                              isLocked && lockReason != null
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.lock_clock,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          lockReason,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.amber,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                  : assessment['endTime'] != null
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.event,
                                        size: 14,
                                        color: Colors.red.shade400,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Due: ${_formatTimestamp(assessment['endTime'])}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.red.shade400,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  )
                                  : const SizedBox(),
                        ),

                        // Action buttons container
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View Submissions button (if any evaluated submissions)
                            if (assessment['hasEvaluatedSubmission'] == true)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      // Navigate to submissions view
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => AssessmentDetailPage(
                                                assessmentId: assessment['id'],
                                                initialTab:
                                                    1, // Submissions tab
                                              ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.assessment,
                                            size: 14,
                                            color: Colors.teal,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Results',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // Attempt/Continue button
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color:
                                    isLocked
                                        ? Colors.grey.shade300
                                        : statusColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow:
                                    isLocked
                                        ? []
                                        : [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap:
                                      isLocked
                                          ? null
                                          : () {
                                            // Navigate to attempt page
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        AssessmentDetailPage(
                                                          assessmentId:
                                                              assessment['id'],
                                                        ),
                                              ),
                                            );
                                          },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isLocked ? Icons.lock : statusIcon,
                                          size: 14,
                                          color:
                                              isLocked
                                                  ? Colors.grey.shade600
                                                  : Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isLocked ? 'Locked' : buttonText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isLocked
                                                    ? Colors.grey.shade600
                                                    : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Share button for ALL assessments
                            Container(
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap:
                                      () => _shareAssessment(
                                        assessment['id'],
                                        assessment['title'],
                                      ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.share,
                                          size: 14,
                                          color: categoryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Share',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: categoryColor,
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

  // Build a badge
  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Build source info
  Widget _buildSourceInfo(
    Map<String, dynamic> assessment,
    Color categoryColor,
  ) {
    IconData icon;
    String label;

    switch (assessment['sourceType']) {
      case 'created':
        icon = Icons.person;
        // Remove "Created by you" text
        label = '';
        break;
      case 'shared':
        icon = Icons.person;
        // Handle multiple users who shared the assessment
        if (assessment['sharedByUsers'] != null &&
            assessment['sharedByUsers'] is List &&
            (assessment['sharedByUsers'] as List).isNotEmpty) {
          final sharedUsers = assessment['sharedByUsers'] as List;
          final now = DateTime.now().millisecondsSinceEpoch;
          // Rotate through users based on time (change every 3 seconds)
          final currentIndex = (now ~/ 3000) % sharedUsers.length;
          label = 'By ${sharedUsers[currentIndex]['displayName'] ?? 'Unknown'}';
        } else {
          label = 'By ${assessment['creatorName'] ?? 'Unknown'}';
        }
        break;
      case 'group':
        icon = Icons.group;
        label = 'From ${assessment['groupName'] ?? 'Unknown Group'}';
        break;
      case 'public':
        icon = Icons.public;
        label = 'By ${assessment['creatorName'] ?? 'Unknown'}';
        break;
      default:
        icon = Icons.info;
        label = 'Unknown source';
    }

    // If label is empty, don't show the row at all
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: categoryColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Build floating action button
  Widget _buildFab() {
    // Available FAB options
    final List<Map<String, dynamic>> fabOptions = [
      {
        'icon': Icons.edit_document,
        'color': const Color(0xFF43E97B), // Green
        'label': 'Manual',
        'type': 'manual',
      },
      {
        'icon': Icons.picture_as_pdf,
        'color': const Color(0xFFFF6584), // Pink
        'label': 'From PDF',
        'type': 'pdf',
      },
      {
        'icon': Icons.auto_awesome,
        'color': const Color(0xFF6C63FF), // Purple
        'label': 'AI Generated',
        'type': 'ai',
      },
    ];

    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // FAB options
            ...fabOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final double startValue = index * 0.2;
              final double endValue = startValue + 0.2;

              // Calculate option animation progress
              double t =
                  (_fabAnimationController.value - startValue) /
                  (endValue - startValue);
              t = t.clamp(0.0, 1.0);

              // Apply curve to animation
              final double progress = Curves.easeOutCubic.transform(t);

              return Transform.translate(
                offset: Offset((1.0 - progress) * 50, 0),
                child: Opacity(
                  opacity: progress,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label
                        Material(
                          color: option['color'],
                          borderRadius: BorderRadius.circular(16),
                          elevation: 4,
                          shadowColor: option['color'].withOpacity(0.3),
                          child: InkWell(
                            onTap:
                                () =>
                                    _navigateToCreateAssessment(option['type']),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    option['icon'],
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    option['label'],
                                    style: const TextStyle(
                                      color: Colors.white,
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
            }).toList(),

            // Main FAB
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isFabExpanded = !_isFabExpanded;
                });

                if (_isFabExpanded) {
                  _fabAnimationController.forward();
                } else {
                  _fabAnimationController.reverse();
                }
              },
              child: Transform.rotate(
                angle:
                    _fabAnimationController.value *
                    0.75, // 135 degrees in radians when fully expanded
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _categories[_selectedCategoryIndex]['color'],
                        _categories[_selectedCategoryIndex]['secondaryColor'],
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _categories[_selectedCategoryIndex]['color']
                            .withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
