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
import 'assessment_conditions_page.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;

  late final PageController _pageController;

  late final AnimationController _fabAnimationController;
  late final AnimationController _cardsAnimationController;
  late final AnimationController _categoryAnimationController;

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'My Assessments',
      'icon': Icons.edit_document,
      'color': const Color(0xFF6C63FF),
      'secondaryColor': const Color(0xFF8B81FF),
      'illustration': Icons.assignment_outlined,
    },
    {
      'name': 'Shared',
      'icon': Icons.share,
      'color': const Color(0xFFFF6584),
      'secondaryColor': const Color(0xFFFF8FAA),
      'illustration': Icons.share_outlined,
    },
    {
      'name': 'Group',
      'icon': Icons.groups,
      'color': const Color(0xFF43E97B),
      'secondaryColor': const Color(0xFF7DEEA2),
      'illustration': Icons.group_outlined,
    },
    {
      'name': 'Public',
      'icon': Icons.public,
      'color': const Color(0xFFFF9E40),
      'secondaryColor': const Color(0xFFFFBC7D),
      'illustration': Icons.public_outlined,
    },
  ];

  int _selectedCategoryIndex = 0;
  double _categoryIndicatorPosition = 0.0;
  bool _isFabExpanded = false;
  bool _isLoading = true;

  Map<int, List<Map<String, dynamic>>> _cachedAssessments = {};
  Map<int, bool> _categoryLoaded = {};

  String _sortOption = 'newest';
  final List<String> _sortOptions = [
    'newest',
    'oldest',
    'difficulty',
    'points',
    'rating',
  ];

  String _filterOption = 'all';
  final List<String> _filterOptions = [
    'all',
    'in-progress',
    'submitted',
    'evaluated',
  ];

  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    developer.log('AssessmentPage: Initializing state', name: 'AssessmentPage');

    _pageController = PageController(
      initialPage: _selectedCategoryIndex,
      viewportFraction: 1.0,
    );

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

    _categoryAnimationController.value = 1.0;

    _initializeCurrentUser();

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

  void _updateCategoryIndicator() {
    final double page = _pageController.page ?? 0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = screenWidth / _categories.length;

    setState(() {
      _categoryIndicatorPosition = page * itemWidth;
    });
  }

  Future<void> _initializeCurrentUser() async {
    developer.log(
      'AssessmentPage: Initializing current user',
      name: 'AssessmentPage',
    );

    try {
      _currentUserId = _auth.currentUser?.uid;
      developer.log(
        'AssessmentPage: Current user ID: $_currentUserId',
        name: 'AssessmentPage',
      );

      if (_currentUserId != null) {
        await _loadAssessmentsForCategory(_selectedCategoryIndex);
      } else {
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

  Future<void> _loadAssessmentsForCategory(int categoryIndex) async {
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
        case 0:
          loadedAssessments = await _loadMyAssessments();
          break;
        case 1:
          loadedAssessments = await _loadSharedAssessments();
          break;
        case 2:
          loadedAssessments = await _loadGroupAssessments();
          break;
        case 3:
          loadedAssessments = await _loadPublicAssessments();
          break;
      }

      developer.log(
        'AssessmentPage: Loaded ${loadedAssessments.length} assessments',
        name: 'AssessmentPage',
      );

      _sortAssessmentsList(loadedAssessments);

      _filterAssessmentsList(loadedAssessments);

      if (categoryIndex == 0 || categoryIndex == 1) {
        await _fetchSubmissionDataForAssessments(loadedAssessments);
      } else if (categoryIndex == 2) {
        await _fetchOldestSubmissionForGroupAssessments(loadedAssessments);
      }

      setState(() {
        _cachedAssessments[categoryIndex] = loadedAssessments;
        _categoryLoaded[categoryIndex] = true;
        _isLoading = false;
      });

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
          final latestSubmission = submissionsSnapshot.docs.first.data();
          assessment['hasSubmission'] = true;
          assessment['submissionStatus'] =
              latestSubmission['status'] ?? 'in-progress';

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
            assessment['totalPoints'] = assessment['totalPoints'] ?? 100;
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
          final oldestSubmission = submissionsSnapshot.docs.first.data();
          assessment['hasSubmission'] = true;
          assessment['submissionStatus'] =
              oldestSubmission['status'] ?? 'in-progress';

          if (oldestSubmission['status'] == 'evaluated') {
            assessment['score'] = oldestSubmission['totalScore'] ?? 0;
            assessment['totalPoints'] = assessment['totalPoints'] ?? 100;
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

  Future<List<Map<String, dynamic>>> _loadMyAssessments() async {
    List<Map<String, dynamic>> myAssessments = [];

    try {
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

        final mainAssessmentDoc =
            await _firestore.collection('assessments').doc(assessmentId).get();

        if (mainAssessmentDoc.exists) {
          final mainData = mainAssessmentDoc.data() ?? {};

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
              'status': 'created',
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

  Future<List<Map<String, dynamic>>> _loadSharedAssessments() async {
    List<Map<String, dynamic>> sharedAssessments = [];

    try {
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

        final mainAssessmentDoc =
            await _firestore.collection('assessments').doc(assessmentId).get();

        if (mainAssessmentDoc.exists) {
          final mainData = mainAssessmentDoc.data() ?? {};

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

  Future<List<Map<String, dynamic>>> _loadGroupAssessments() async {
    List<Map<String, dynamic>> groupAssessments = [];

    try {
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
        return [];
      }

      for (var doc in userAssessmentsSnapshot.docs) {
        final assessmentData = doc.data();
        final assessmentId = doc.id;

        final mainAssessmentDoc =
            await _firestore.collection('assessments').doc(assessmentId).get();

        if (!mainAssessmentDoc.exists) continue;

        final mainData = mainAssessmentDoc.data() ?? {};

        for (var groupId in userGroupIds) {
          final groupShareDoc =
              await _firestore
                  .collection('assessments')
                  .doc(assessmentId)
                  .collection('sharedWithGroups')
                  .doc(groupId)
                  .get();

          if (groupShareDoc.exists) {
            final groupShareData = groupShareDoc.data() ?? {};

            String groupName = 'Unknown Group';
            final groupDoc =
                userGroupsSnapshot.docs
                    .where((doc) => doc.id == groupId)
                    .firstOrNull;
            final groupData = groupDoc?.data();

            if (groupData != null) {
              groupName = groupData['name'] ?? 'Unknown Group';
            }

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

            if (!groupAssessments.any((item) => item['id'] == assessmentId)) {
              groupAssessments.add(assessment);
              developer.log(
                'AssessmentPage: Added group assessment ${assessment['title']} from group $groupName',
                name: 'AssessmentPage',
              );
            }

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

  Future<List<Map<String, dynamic>>> _loadPublicAssessments() async {
    List<Map<String, dynamic>> publicAssessments = [];

    try {
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
          return bPoints.compareTo(aPoints);
        });
        break;
      case 'rating':
        assessments.sort((a, b) {
          final aRating = a['rating'] ?? 0.0;
          final bRating = b['rating'] ?? 0.0;
          return bRating.compareTo(aRating);
        });
        break;
    }
  }

  void _filterAssessmentsList(List<Map<String, dynamic>> assessments) {
    if (_filterOption == 'all') {
      return;
    }

    developer.log(
      'AssessmentPage: Filtering assessments by $_filterOption',
      name: 'AssessmentPage',
    );

    assessments.removeWhere((assessment) {
      final String status = assessment['submissionStatus'] ?? '';
      return status != _filterOption;
    });
  }

  void _resortCurrentAssessments() {
    if (_cachedAssessments.containsKey(_selectedCategoryIndex)) {
      final assessments = _cachedAssessments[_selectedCategoryIndex] ?? [];
      _sortAssessmentsList(assessments);
      _filterAssessmentsList(assessments);
      setState(() {
        _cachedAssessments[_selectedCategoryIndex] = assessments;
      });
    }
  }

  Future<void> _shareAssessment(
    String assessmentId,
    String assessmentTitle,
  ) async {
    developer.log(
      'AssessmentPage: Sharing assessment $assessmentId',
      name: 'AssessmentPage',
    );

    final Color categoryColor = _categories[_selectedCategoryIndex]['color'];

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

  void _navigateToCreateAssessment(String type) {
    developer.log(
      'AssessmentPage: Navigating to create assessment page with type: $type',
      name: 'AssessmentPage',
    );

    setState(() {
      _isFabExpanded = false;
    });

    _fabAnimationController.reverse();

    Future.delayed(const Duration(milliseconds: 200), () {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) =>
                  CreateAssessmentPage(),
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
        setState(() {
          _categoryLoaded[0] = false;
        });

        _loadAssessmentsForCategory(_selectedCategoryIndex);
      });
    });
  }

  void _chooseSortOption() {
    developer.log(
      'AssessmentPage: Opening sort/filter options',
      name: 'AssessmentPage',
    );

    final Color categoryColor = _categories[_selectedCategoryIndex]['color'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  _currentTabIndex = 0;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color:
                                          _currentTabIndex == 0
                                              ? categoryColor
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sort,
                                      color:
                                          _currentTabIndex == 0
                                              ? categoryColor
                                              : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Sort',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _currentTabIndex == 0
                                                ? categoryColor
                                                : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  _currentTabIndex = 1;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color:
                                          _currentTabIndex == 1
                                              ? categoryColor
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.filter_list,
                                      color:
                                          _currentTabIndex == 1
                                              ? categoryColor
                                              : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Filter',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _currentTabIndex == 1
                                                ? categoryColor
                                                : Colors.grey,
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

                    const SizedBox(height: 16),
                    const Divider(height: 1),

                    _currentTabIndex == 0
                        ? _buildSortOptionsView(categoryColor)
                        : _buildFilterOptionsView(categoryColor, setModalState),

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOptionsView(Color categoryColor) {
    return Padding(
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
    );
  }

  Widget _buildFilterOptionsView(
    Color categoryColor,
    StateSetter setModalState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterOption(
            'all',
            'All Assessments',
            Icons.all_inclusive,
            categoryColor,
            setModalState,
          ),
          _buildFilterOption(
            'in-progress',
            'In Progress',
            Icons.edit,
            categoryColor,
            setModalState,
          ),
          _buildFilterOption(
            'submitted',
            'Submitted',
            Icons.check_circle_outline,
            categoryColor,
            setModalState,
          ),
          _buildFilterOption(
            'evaluated',
            'Evaluated/Finished',
            Icons.verified,
            categoryColor,
            setModalState,
          ),
        ],
      ),
    );
  }

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

            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? categoryColor : Colors.black87,
              ),
            ),

            const Spacer(),

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

  Widget _buildFilterOption(
    String value,
    String label,
    IconData icon,
    Color categoryColor,
    StateSetter setModalState,
  ) {
    final bool isSelected = _filterOption == value;

    return InkWell(
      onTap: () {
        setModalState(() {
          _filterOption = value;
        });

        setState(() {
          _filterOption = value;
        });

        Navigator.pop(context);

        setState(() {
          _categoryLoaded[_selectedCategoryIndex] = false;
        });
        _loadAssessmentsForCategory(_selectedCategoryIndex);
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

            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? categoryColor : Colors.black87,
              ),
            ),

            const Spacer(),

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

  Widget _buildBottomNavBar() {
    final Color navBarColor = _categories[_selectedCategoryIndex]['color'];

    return Container(
      height: 55,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 25.0),
      decoration: BoxDecoration(
        color: navBarColor,
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
          _buildNavItem(Icons.bar_chart, true),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AILearningPage()),
              );
            },
            child: _buildNavItem(Icons.access_time, false),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
            },
            child: _buildNavItem(Icons.home, false),
          ),
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
              Column(
                children: [
                  _buildAppBar(),

                  _buildCategorySelector(),

                  Expanded(child: _buildPageView()),
                ],
              ),

              Positioned(
                right: 20,
                bottom: 100 + MediaQuery.of(context).padding.bottom,
                child: _buildFab(),
              ),

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

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),

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
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort,
                        size: 20,
                        color: _categories[_selectedCategoryIndex]['color'],
                      ),
                      if (_filterOption != 'all') ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _categories[_selectedCategoryIndex]['color'],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final double itemWidth =
        MediaQuery.of(context).size.width / _categories.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Column(
        children: [
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

                    if (index != _selectedCategoryIndex) {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });

                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );

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

          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 3,
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),

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

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      itemCount: _categories.length,
      onPageChanged: (index) {
        setState(() {
          _selectedCategoryIndex = index;
        });

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

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 200 + (index * 40 % 100),
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),

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

  Widget _buildEmptyState(Map<String, dynamic> category) {
    String message;
    String buttonText;

    switch (_categories.indexOf(category)) {
      case 0:
        message =
            'You haven\'t created any assessments yet.\nCreate one to get started!';
        buttonText = 'Create Assessment';
        break;
      case 1:
        message = 'No assessments have been shared with you yet.';
        buttonText = 'Find Friends';
        break;
      case 2:
        message =
            'No group assessments available.\nJoin a group to see assessments.';
        buttonText = 'Join a Group';
        break;
      case 3:
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

            ElevatedButton(
              onPressed: () {
                final index = _categories.indexOf(category);
                if (index == 0) {
                  setState(() {
                    _isFabExpanded = true;
                  });
                  _fabAnimationController.forward();
                } else if (index == 3) {
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

            SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ],
        ),
      ),
    );
  }

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
    final String sourceType = assessment['sourceType'] ?? '';

    bool isLocked = false;
    String? lockReason;

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

    String buttonText = 'Attempt';
    Color statusColor = categoryColor;
    IconData statusIcon = Icons.play_arrow;

    if (assessment['hasSubmission'] == true) {
      final String status = assessment['submissionStatus'] ?? '';

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
      }
    }

    return AnimatedBuilder(
      animation: _cardsAnimationController,
      builder: (context, child) {
        final double delay = index * 0.1;
        final double start = delay;
        final double end = delay + 0.4;

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

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
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

                          _buildBadge(
                            icon: Icons.star,
                            label: '$points pts',
                            color: Colors.amber,
                          ),

                          if (assessment['rating'] != null &&
                              assessment['rating'] > 0) ...[
                            const SizedBox(width: 12),
                            _buildBadge(
                              icon: Icons.thumb_up,
                              label: assessment['rating'].toStringAsFixed(1),
                              color: Colors.blue,
                            ),
                          ],

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

                    _buildSourceInfo(assessment, categoryColor),

                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => AssessmentDetailPage(
                                                assessmentId: assessment['id'],
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
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (
                                                      context,
                                                    ) => AssessmentConditionsPage(
                                                      assessmentId:
                                                          assessment['id'],
                                                      groupName:
                                                          assessment['sourceType'] ==
                                                                  'group'
                                                              ? assessment['groupName']
                                                              : null,
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

                            if (sourceType != 'group')
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

  Widget _buildSourceInfo(
    Map<String, dynamic> assessment,
    Color categoryColor,
  ) {
    IconData icon;
    String label;

    switch (assessment['sourceType']) {
      case 'created':
        icon = Icons.person;
        label = '';
        break;
      case 'shared':
        icon = Icons.person;
        if (assessment['sharedByUsers'] != null &&
            assessment['sharedByUsers'] is List &&
            (assessment['sharedByUsers'] as List).isNotEmpty) {
          final sharedUsers = assessment['sharedByUsers'] as List;
          final now = DateTime.now().millisecondsSinceEpoch;
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

  Widget _buildFab() {
    final List<Map<String, dynamic>> fabOptions = [
      {
        'icon': Icons.edit_document,
        'color': const Color(0xFF43E97B),
        'label': 'Manual',
        'type': 'manual',
      },
      {
        'icon': Icons.picture_as_pdf,
        'color': const Color(0xFFFF6584),
        'label': 'From PDF',
        'type': 'pdf',
      },
      {
        'icon': Icons.auto_awesome,
        'color': const Color(0xFF6C63FF),
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
            ...fabOptions.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final double startValue = index * 0.2;
              final double endValue = startValue + 0.2;

              double t =
                  (_fabAnimationController.value - startValue) /
                  (endValue - startValue);
              t = t.clamp(0.0, 1.0);

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
                angle: _fabAnimationController.value * 0.75,
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
