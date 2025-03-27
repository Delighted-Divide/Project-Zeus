import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_page.dart';
import 'friends_groups_page.dart';

class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  State<FindFriendsPage> createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user ID and favorites
  String? _currentUserId;
  List<String> _currentUserFavTags = [];

  // UI state
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSearchingByEmail = false;
  bool _showNoUsersFound = false;
  bool _hasMoreUsers = true;

  // List of users to display
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _originalUsers =
      []; // Keep original list for filtering

  // Last document for pagination
  DocumentSnapshot? _lastDocument;

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Constants
  static const int _usersPerPage = 25;

  @override
  void initState() {
    super.initState();
    _initializeCurrentUser();

    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_isLoading &&
          !_isLoadingMore &&
          _hasMoreUsers &&
          !_isSearchingByEmail) {
        _loadMoreUsers();
      }
    });

    // Add listener to search controller for filtering
    _searchController.addListener(() {
      if (!_isSearchingByEmail && _searchController.text.isNotEmpty) {
        _filterUsersByName(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Initialize current user and load their data
  Future<void> _initializeCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUserId = _auth.currentUser?.uid;

      if (_currentUserId != null) {
        // Get current user's favorite tags
        final userDoc =
            await _firestore.collection('users').doc(_currentUserId).get();
        final userData = userDoc.data();

        if (userData != null && userData.containsKey('favTags')) {
          _currentUserFavTags = List<String>.from(userData['favTags'] ?? []);
        }

        // Load initial users
        await _loadInitialUsers();
      }
    } catch (e) {
      print('Error initializing user: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load initial set of users
  Future<void> _loadInitialUsers() async {
    _users.clear();
    _originalUsers.clear();
    _lastDocument = null;
    _hasMoreUsers = true;

    try {
      // Get a list of groups the user is in
      final userGroupsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('groups')
              .get();

      List<String> userGroupIds =
          userGroupsSnapshot.docs.map((doc) => doc.id).toList();

      // If the user is in groups, find other members with public profiles
      if (userGroupIds.isNotEmpty) {
        await _loadUsersFromGroups(userGroupIds);
      } else {
        // If no groups, load public users directly
        await _loadPublicUsers();
      }

      // Store original users list for filtering
      _originalUsers = List.from(_users);
    } catch (e) {
      print('Error loading initial users: $e');
    }
  }

  // Load users from the user's groups
  Future<void> _loadUsersFromGroups(List<String> groupIds) async {
    try {
      for (String groupId in groupIds) {
        // Skip if we already have 25+ users
        if (_users.length >= _usersPerPage) break;

        // Get group members
        final groupMembersSnapshot =
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('members')
                .get();

        // Get user IDs from the group
        List<String> memberIds =
            groupMembersSnapshot.docs
                .map((doc) => doc.id)
                .where((id) => id != _currentUserId) // Exclude current user
                .toList();

        // Load public user profiles from these members
        if (memberIds.isNotEmpty) {
          for (String memberId in memberIds) {
            // Skip if this user is already in our list
            if (_users.any((user) => user['id'] == memberId)) continue;

            final userDoc =
                await _firestore.collection('users').doc(memberId).get();
            final userData = userDoc.data();

            if (userData != null &&
                userData['privacyLevel'] == 'public' &&
                !_users.any((user) => user['id'] == memberId)) {
              // Calculate similarity score based on tags
              int similarityScore = 0;
              if (userData.containsKey('favTags') &&
                  _currentUserFavTags.isNotEmpty) {
                List<String> userTags = List<String>.from(
                  userData['favTags'] ?? [],
                );
                similarityScore =
                    userTags
                        .where((tag) => _currentUserFavTags.contains(tag))
                        .length;
              }

              // Add user to list with similarity score
              _users.add({
                'id': memberId,
                'displayName': userData['displayName'] ?? 'Unknown User',
                'photoURL': userData['photoURL'] ?? '',
                'email': userData['email'] ?? '',
                'similarityScore': similarityScore,
                'userData': userData,
              });
            }

            // Break if we have enough users
            if (_users.length >= _usersPerPage) break;
          }
        }
      }

      // If we still need more users, load public users
      if (_users.length < _usersPerPage) {
        await _loadPublicUsers();
      } else {
        // Sort users by similarity score
        _users.sort(
          (a, b) => (b['similarityScore'] as int).compareTo(
            a['similarityScore'] as int,
          ),
        );

        // Save the last document for pagination
        if (_users.isNotEmpty) {
          _lastDocument =
              await _firestore.collection('users').doc(_users.last['id']).get();
        }
      }
    } catch (e) {
      print('Error loading users from groups: $e');
    }
  }

  // Load public users directly
  Future<void> _loadPublicUsers() async {
    try {
      // Create a base query for public users
      Query query = _firestore
          .collection('users')
          .where('privacyLevel', isEqualTo: 'public')
          .where(FieldPath.documentId, isNotEqualTo: _currentUserId)
          .limit(_usersPerPage);

      // Apply pagination if we have a last document
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      // Execute the query
      final querySnapshot = await query.get();

      // Handle case where no more users are found
      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreUsers = false;
          if (_users.isEmpty) {
            _showNoUsersFound = true;
          }
        });
        return;
      }

      // Process user documents
      for (var doc in querySnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final userId = doc.id;

        // Skip if this user is already in our list
        if (_users.any((user) => user['id'] == userId)) continue;

        // Calculate similarity score based on tags
        int similarityScore = 0;
        if (userData.containsKey('favTags') && _currentUserFavTags.isNotEmpty) {
          List<String> userTags = List<String>.from(userData['favTags'] ?? []);
          similarityScore =
              userTags.where((tag) => _currentUserFavTags.contains(tag)).length;
        }

        // Add user to list with similarity score
        _users.add({
          'id': userId,
          'displayName': userData['displayName'] ?? 'Unknown User',
          'photoURL': userData['photoURL'] ?? '',
          'email': userData['email'] ?? '',
          'similarityScore': similarityScore,
          'userData': userData,
        });
      }

      // Sort users by similarity score
      _users.sort(
        (a, b) => (b['similarityScore'] as int).compareTo(
          a['similarityScore'] as int,
        ),
      );

      // Save the last document for pagination
      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }
    } catch (e) {
      print('Error loading public users: $e');
    }
  }

  // Load more users when scrolling
  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMoreUsers) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Load more public users
      await _loadPublicUsers();

      // Update the original users list
      _originalUsers = List.from(_users);
    } catch (e) {
      print('Error loading more users: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  // Filter users by name as typing
  void _filterUsersByName(String query) {
    if (query.isEmpty) {
      // Reset to original list if query is empty
      setState(() {
        _users = List.from(_originalUsers);
      });
      return;
    }

    // Simple local filtering based on the name
    setState(() {
      _users =
          _originalUsers
              .where(
                (user) => user['displayName'].toString().toLowerCase().contains(
                  query.toLowerCase(),
                ),
              )
              .toList();

      _showNoUsersFound = _users.isEmpty;
    });
  }

  // Search for a user by exact email
  Future<void> _searchUserByEmail() async {
    String email = _searchController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearchingByEmail = true;
      _showNoUsersFound = false;
    });

    try {
      // Search for user with the exact email (regardless of privacy level)
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _users = [];
          _showNoUsersFound = true;
        });
        return;
      }

      List<Map<String, dynamic>> emailUsers = [];

      for (var doc in querySnapshot.docs) {
        if (doc.id == _currentUserId) continue;

        final userData = doc.data();
        final userId = doc.id;

        int similarityScore = 0;
        if (userData.containsKey('favTags') && _currentUserFavTags.isNotEmpty) {
          List<String> userTags = List<String>.from(userData['favTags'] ?? []);
          similarityScore =
              userTags.where((tag) => _currentUserFavTags.contains(tag)).length;
        }

        emailUsers.add({
          'id': userId,
          'displayName': userData['displayName'] ?? 'Unknown User',
          'photoURL': userData['photoURL'] ?? '',
          'email': userData['email'] ?? '',
          'similarityScore': similarityScore,
          'userData': userData,
          'privacyLevel': userData['privacyLevel'] ?? 'private',
        });
      }

      setState(() {
        _users = emailUsers;
        _showNoUsersFound = emailUsers.isEmpty;
      });
    } catch (e) {
      print('Error searching by email: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Clear search and reset to initial state
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearchingByEmail = false;
      _showNoUsersFound = false;
      _users = List.from(_originalUsers);
    });
  }

  // Toggle email search mode
  void _toggleEmailSearchMode(bool enabled) {
    setState(() {
      _isSearchingByEmail = enabled;
      _searchController.clear();

      if (enabled) {
        // Clear the user list when switching to email mode
        _users = [];
      } else {
        // Restore original users list when switching back to name mode
        _users = List.from(_originalUsers);
      }
    });
    // Re-focus search field
    _searchFocusNode.requestFocus();
  }

  // Helper method to get image provider with fallback
  ImageProvider _getImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/images/default_avatar.jpg');
    }

    // Check if it's a network image or asset image
    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return AssetImage(path);
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
              bottom: false, // No bottom padding
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchSection(),
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
                    : _showNoUsersFound
                    ? _buildNoUsersFound()
                    : _buildUsersList(),
          ),
        ],
      ),
    );
  }

  // Header with page title and back button
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
            'FIND FRIENDS',
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

  // Search bar section
  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Search bar row
          Row(
            children: [
              // Main search field
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText:
                            _isSearchingByEmail
                                ? 'Enter exact email'
                                : 'Search by name',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.black,
                                  ),
                                  onPressed: _clearSearch,
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        if (_isSearchingByEmail) {
                          _searchUserByEmail();
                        }
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Email search toggle button
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color:
                      _isSearchingByEmail
                          ? const Color(0xFF80AB82)
                          : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.email,
                    color: _isSearchingByEmail ? Colors.white : Colors.black,
                  ),
                  onPressed: () => _toggleEmailSearchMode(!_isSearchingByEmail),
                  tooltip:
                      _isSearchingByEmail
                          ? 'Switch to name search'
                          : 'Switch to email search',
                ),
              ),
            ],
          ),

          // Email search mode instructions
          if (_isSearchingByEmail)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF80AB82),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Enter the exact email address and tap search',
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ),
                    TextButton(
                      onPressed: _searchUserByEmail,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF80AB82),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Users list widget
  Widget _buildUsersList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _users.length + (_isLoadingMore || _hasMoreUsers ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end
        if (index == _users.length) {
          return _isLoadingMore
              ? Container(
                height: 80,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16.0),
                child: const CircularProgressIndicator(),
              )
              : _hasMoreUsers
              ? Container(
                height: 80,
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _loadMoreUsers,
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
                  child: const Text('Load More'),
                ),
              )
              : const SizedBox.shrink();
        }

        // Get the user data for this index
        final user = _users[index];
        final bool isPrivate = user['userData']['privacyLevel'] == 'private';

        // Build user card
        return GestureDetector(
          onTap: () {
            // Navigate to user profile page
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UserProfilePage(userId: user['id']),
              ),
            );
          },
          child: Container(
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
            child: Stack(
              children: [
                // Background decoration on bottom-right
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E6FA).withOpacity(0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(60),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // User avatar with decorative border
                      Stack(
                        children: [
                          // Decorative circle behind avatar
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFA07A),
                                width: 2,
                              ),
                            ),
                          ),
                          // Avatar
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1,
                                ),
                                image: DecorationImage(
                                  image: _getImageProvider(user['photoURL']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // User info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name row with privacy indicator
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user['displayName'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                if (isPrivate)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Private',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Common interests badges
                            if (user['similarityScore'] > 0 &&
                                !_isSearchingByEmail)
                              Wrap(
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFFD6E0,
                                      ), // Light pink
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFFFB6C1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '${user['similarityScore']} common ${user['similarityScore'] == 1 ? 'interest' : 'interests'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Add friend button
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF80AB82), Color(0xFF98D8C8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF80AB82).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // No users found message
  Widget _buildNoUsersFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
              border: Border.all(
                color: const Color(0xFFFFA07A).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(Icons.search_off, size: 70, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            _isSearchingByEmail
                ? 'No user found with this email'
                : 'No users found',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isSearchingByEmail
                ? 'Try entering a different email address'
                : 'Try adjusting your search criteria',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.refresh),
            label: const Text('Clear Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA07A),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.black, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
