import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinGroupPage extends StatefulWidget {
  const JoinGroupPage({super.key});

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // UI state
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreGroups = true;
  String _searchQuery = '';

  // Current user data
  String? _currentUserId;
  List<String> _userTags = [];

  // Groups data
  List<Map<String, dynamic>> _allGroups = [];
  List<Map<String, dynamic>> _filteredGroups = [];

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Constants
  static const int _groupsPerPage = 25;

  // Last document for pagination
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _initializeUserData();

    // Set up search controller listener
    _searchController.addListener(_onSearchChanged);

    // Set up scroll controller for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_isLoading &&
          !_isLoadingMore &&
          _hasMoreGroups) {
        _loadMoreGroups();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Initialize user data and load groups
  Future<void> _initializeUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUserId = _auth.currentUser?.uid;

      if (_currentUserId != null) {
        // Get user's tags
        final userDoc =
            await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data();

        if (userData != null && userData.containsKey('favTags')) {
          _userTags = List<String>.from(userData['favTags'] ?? []);
        }

        // Load initial groups
        await _loadInitialGroups();
      }
    } catch (e) {
      print('Error initializing user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load initial set of groups
  Future<void> _loadInitialGroups() async {
    try {
      // Create query for public groups
      Query query = _firestore
          .collection('groups')
          .where('settings.visibility', isEqualTo: 'public')
          .limit(_groupsPerPage);

      // Execute query
      final querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreGroups = false;
        });
        return;
      }

      // Process results
      List<Map<String, dynamic>> groups = [];

      for (var doc in querySnapshot.docs) {
        final groupData = doc.data() as Map<String, dynamic>;
        final groupId = doc.id;

        // Check if user is already a member
        final isMemberSnapshot =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('groups')
                .doc(groupId)
                .get();

        if (!isMemberSnapshot.exists) {
          // Calculate tag similarity score
          int tagSimilarity = 0;
          if (groupData.containsKey('tags') && _userTags.isNotEmpty) {
            List<String> groupTags = List<String>.from(groupData['tags'] ?? []);
            tagSimilarity =
                groupTags.where((tag) => _userTags.contains(tag)).length;
          }

          // Get member count
          int memberCount = 0;
          try {
            final membersSnapshot =
                await _firestore
                    .collection('groups')
                    .doc(groupId)
                    .collection('members')
                    .count()
                    .get();
            memberCount = membersSnapshot.count!;
          } catch (e) {
            // If count() is not available, fall back to getting all docs
            try {
              final membersSnapshot =
                  await _firestore
                      .collection('groups')
                      .doc(groupId)
                      .collection('members')
                      .get();
              memberCount = membersSnapshot.docs.length;
            } catch (e2) {
              print('Error getting member count alt method: $e2');
            }
          }

          // Add group to list
          groups.add({
            'id': groupId,
            'name': groupData['name'] ?? 'Unnamed Group',
            'description': groupData['description'] ?? '',
            'photoURL': groupData['photoURL'] ?? '',
            'tagSimilarity': tagSimilarity,
            'memberCount': memberCount,
            'settings': groupData['settings'] ?? {},
            'tags': groupData['tags'] ?? [],
            // Store fields to help with tag name display
            'tagNames': await _getTagNames(groupData['tags'] ?? []),
          });
        }
      }

      // Sort groups by tag similarity (descending) and then by member count (descending)
      groups.sort((a, b) {
        // First compare tag similarity
        int tagComparison = b['tagSimilarity'].compareTo(a['tagSimilarity']);
        if (tagComparison != 0) {
          return tagComparison;
        }
        // If tag similarity is the same, compare member count
        return b['memberCount'].compareTo(a['memberCount']);
      });

      // Save the last document for pagination
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }

      setState(() {
        _allGroups = groups;
        _filteredGroups = List.from(_allGroups);
      });
    } catch (e) {
      print('Error loading groups: $e');
    }
  }

  // Load more groups when scrolling
  Future<void> _loadMoreGroups() async {
    if (_isLoadingMore || !_hasMoreGroups) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Create query for more public groups
      Query query = _firestore
          .collection('groups')
          .where('settings.visibility', isEqualTo: 'public')
          .limit(_groupsPerPage);

      // Apply pagination if we have a last document
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      // Execute query
      final querySnapshot = await query.get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreGroups = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Process results
      List<Map<String, dynamic>> moreGroups = [];

      for (var doc in querySnapshot.docs) {
        final groupData = doc.data() as Map<String, dynamic>;
        final groupId = doc.id;

        // Check if user is already a member
        final isMemberSnapshot =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('groups')
                .doc(groupId)
                .get();

        if (!isMemberSnapshot.exists) {
          // Calculate tag similarity score
          int tagSimilarity = 0;
          if (groupData.containsKey('tags') && _userTags.isNotEmpty) {
            List<String> groupTags = List<String>.from(groupData['tags'] ?? []);
            tagSimilarity =
                groupTags.where((tag) => _userTags.contains(tag)).length;
          }

          // Get member count
          int memberCount = 0;
          try {
            final membersSnapshot =
                await _firestore
                    .collection('groups')
                    .doc(groupId)
                    .collection('members')
                    .count()
                    .get();
            memberCount = membersSnapshot.count!;
          } catch (e) {
            // If count() is not available, fall back to getting all docs
            try {
              final membersSnapshot =
                  await _firestore
                      .collection('groups')
                      .doc(groupId)
                      .collection('members')
                      .get();
              memberCount = membersSnapshot.docs.length;
            } catch (e2) {
              print('Error getting member count alt method: $e2');
            }
          }

          // Add group to list
          moreGroups.add({
            'id': groupId,
            'name': groupData['name'] ?? 'Unnamed Group',
            'description': groupData['description'] ?? '',
            'photoURL': groupData['photoURL'] ?? '',
            'tagSimilarity': tagSimilarity,
            'memberCount': memberCount,
            'settings': groupData['settings'] ?? {},
            'tags': groupData['tags'] ?? [],
            // Store fields to help with tag name display
            'tagNames': await _getTagNames(groupData['tags'] ?? []),
          });
        }
      }

      // Save the last document for pagination
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }

      // Add new groups to the list
      setState(() {
        _allGroups.addAll(moreGroups);
        _filterGroups(); // Apply any active filter
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more groups: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  // Get tag names for display
  Future<Map<String, String>> _getTagNames(List<dynamic> tagIds) async {
    Map<String, String> tagNames = {};

    for (var tagId in tagIds) {
      try {
        final tagDoc =
            await _firestore.collection('tags').doc(tagId.toString()).get();
        if (tagDoc.exists) {
          final tagData = tagDoc.data();
          if (tagData != null && tagData.containsKey('name')) {
            tagNames[tagId.toString()] = tagData['name'];
          } else {
            tagNames[tagId.toString()] = 'Unknown Tag';
          }
        } else {
          tagNames[tagId.toString()] = 'Unknown Tag';
        }
      } catch (e) {
        print('Error fetching tag name for $tagId: $e');
        tagNames[tagId.toString()] = 'Unknown Tag';
      }
    }

    return tagNames;
  }

  // Handle search changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterGroups();
    });
  }

  // Filter groups based on search query
  void _filterGroups() {
    if (_searchQuery.isEmpty) {
      _filteredGroups = List.from(_allGroups);
    } else {
      _filteredGroups =
          _allGroups
              .where(
                (group) => group['name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }
  }

  // Request to join a group
  Future<void> _requestToJoinGroup(String groupId, String groupName) async {
    if (_currentUserId == null) return;

    try {
      // Get the group settings
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupData = groupDoc.data();

      if (groupData == null) {
        throw Exception('Group not found');
      }

      // Check if approval is required
      final requiresApproval = groupData['settings']?['joinApproval'] ?? true;

      // Get current user data
      final userDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data();

      if (userData == null) {
        throw Exception('User data not found');
      }

      final String displayName = userData['displayName'] ?? 'Unknown User';
      final String photoURL = userData['photoURL'] ?? '';

      if (requiresApproval) {
        // Add to join requests
        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('joinRequests')
            .doc(_currentUserId)
            .set({
              'displayName': displayName,
              'photoURL': photoURL,
              'requestedAt': FieldValue.serverTimestamp(),
              'status': 'pending',
              'message': 'I would like to join this group',
            });

        // Add to sent group requests
        await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('sentGroupRequests')
            .doc(groupId)
            .set({
              'groupName': groupName,
              'photoURL': groupData['photoURL'] ?? '',
              'requestedAt': FieldValue.serverTimestamp(),
              'status': 'pending',
            });

        // Show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request to join $groupName has been sent'),
            backgroundColor: const Color(0xFF80AB82), // Green
          ),
        );
      } else {
        // Direct join without approval
        // Add user to group members
        await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(_currentUserId)
            .set({
              'displayName': displayName,
              'photoURL': photoURL,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });

        // Add group to user's groups
        await _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('groups')
            .doc(groupId)
            .set({
              'name': groupName,
              'photoURL': groupData['photoURL'] ?? '',
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });

        // Show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have joined $groupName'),
            backgroundColor: const Color(0xFF80AB82), // Green
          ),
        );

        // Remove from filtered list
        setState(() {
          _filteredGroups.removeWhere((group) => group['id'] == groupId);
          _allGroups.removeWhere((group) => group['id'] == groupId);
        });
      }
    } catch (e) {
      print('Error joining group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Salmon colored top section
          Container(
            color: const Color(0xFFFFA07A), // Salmon background
            child: SafeArea(
              bottom: false, // Don't add bottom padding
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  // Curved bottom edge
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
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredGroups.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupsList(),
          ),
        ],
      ),
    );
  }

  // Header with title and back button
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          const Spacer(),

          // Page title
          const Text(
            'JOIN GROUP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),

          const Spacer(),

          // Empty container for symmetry
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // Search bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search groups',
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: const Icon(Icons.search, color: Colors.black),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  // Groups list view
  Widget _buildGroupsList() {
    // Group by categories
    List<Map<String, dynamic>> similarTagGroups = [];
    List<Map<String, dynamic>> otherGroups = [];

    for (var group in _filteredGroups) {
      if (group['tagSimilarity'] > 0) {
        similarTagGroups.add(group);
      } else {
        otherGroups.add(group);
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      children: [
        // Shared interests section
        if (similarTagGroups.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Groups with Shared Interests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6A3DE8),
              ),
            ),
          ),
          ...similarTagGroups.map((group) => _buildGroupCard(group)).toList(),
          const SizedBox(height: 20),
        ],

        // Other groups section
        if (otherGroups.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'More Groups',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          ...otherGroups.map((group) => _buildGroupCard(group)).toList(),
        ],

        // Loading more indicator
        if (_isLoadingMore)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_hasMoreGroups)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: ElevatedButton(
                onPressed: _loadMoreGroups,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF80AB82),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.black, width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Load More Groups',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Individual group card
  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header with name, member count
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Group avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _getGroupColor(group['name']),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      group['name'].substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Group info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${group['memberCount']} members',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Join button
                GestureDetector(
                  onTap: () => _requestToJoinGroup(group['id'], group['name']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF80AB82), // Green
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: const Text(
                      'JOIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description (if available)
          if (group['description'] != null && group['description'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                group['description'],
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Tags and similarity
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags row
                if (group['tags'] != null && (group['tags'] as List).isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        (group['tags'] as List).map<Widget>((tagId) {
                          final String tagName =
                              group['tagNames']?[tagId.toString()] ??
                              tagId.toString();

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0E6FA), // Light purple
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tagName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6A5CB5),
                              ),
                            ),
                          );
                        }).toList(),
                  ),

                // Similarity badge if applicable
                if (group['tagSimilarity'] > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD6E0), // Light pink
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFB6C1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.sync_alt,
                          size: 14,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${group['tagSimilarity']} shared ${group['tagSimilarity'] == 1 ? 'interest' : 'interests'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Empty state when no groups are found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty
                ? 'No groups available to join'
                : 'No groups matching "$_searchQuery"',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA07A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Clear Search'),
            ),
        ],
      ),
    );
  }

  // Helper method to get a color based on the group name
  Color _getGroupColor(String name) {
    final List<Color> colors = [
      const Color(0xFF98D8C8), // Light teal
      const Color(0xFFF4A9A8), // Light coral
      const Color(0xFFD8BFD8), // Light purple
      const Color(0xFF80AB82), // Green
      const Color(0xFFB0C4DE), // Light steel blue
    ];

    // Use the first character of the name to determine color (consistent)
    final int index = name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length;

    return colors[index];
  }
}
