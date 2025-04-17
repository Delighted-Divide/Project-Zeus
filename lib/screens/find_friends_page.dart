import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'user_profile_page.dart';
import 'friends_groups_page.dart';

class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  State<FindFriendsPage> createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
    ),
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentUserId;
  Set<String> _currentUserFriendIds = {};
  Map<String, String> _friendRequestStatuses = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSearchingByEmail = false;
  bool _showNoUsersFound = false;
  bool _hasMoreUsers = true;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _originalUsers = [];

  DocumentSnapshot? _lastDocument;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const int _usersPerPage = 25;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing FindFriendsPage');
    _initializeCurrentUser();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !_isLoading &&
          !_isLoadingMore &&
          _hasMoreUsers &&
          !_isSearchingByEmail) {
        _logger.d('Reached scroll threshold, loading more users');
        _loadMoreUsers();
      }
    });

    _searchController.addListener(() {
      if (!_isSearchingByEmail && _searchController.text.isNotEmpty) {
        _filterUsersByName(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _logger.d('Disposing FindFriendsPage resources');
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeCurrentUser() async {
    _logger.i('Initializing current user data');
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUserId = _auth.currentUser?.uid;
      _logger.d('Current user ID: $_currentUserId');

      if (_currentUserId != null) {
        _currentUserFriendIds = {};
        _friendRequestStatuses = {};

        _logger.d('Fetching current user\'s friends');
        final friendsSnapshot =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('friends')
                .get();

        for (var doc in friendsSnapshot.docs) {
          _currentUserFriendIds.add(doc.id);
        }
        _logger.d('Fetched ${_currentUserFriendIds.length} friends');

        _logger.d('Fetching friend requests');
        final requestsSnapshot =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('friendRequests')
                .get();

        for (var doc in requestsSnapshot.docs) {
          final data = doc.data();
          final userId = data['userId'] as String?;
          final type = data['type'] as String?;
          final status = data['status'] as String?;

          if (userId != null && type != null && status != null) {
            _friendRequestStatuses[userId] = '$type:$status';
          }
        }
        _logger.d('Fetched ${_friendRequestStatuses.length} friend requests');

        await _loadInitialUsers();
      } else {
        _logger.e('No current user found');
      }
    } catch (e) {
      _logger.e('Error initializing user: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitialUsers() async {
    _logger.i('Loading initial users');
    _users.clear();
    _originalUsers.clear();
    _lastDocument = null;
    _hasMoreUsers = true;

    try {
      final userGroupsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('groups')
              .get();

      List<String> userGroupIds =
          userGroupsSnapshot.docs.map((doc) => doc.id).toList();
      _logger.d('User is in ${userGroupIds.length} groups');

      if (userGroupIds.isNotEmpty) {
        await _loadUsersFromGroups(userGroupIds);
      } else {
        await _loadPublicUsers();
      }

      _originalUsers = List.from(_users);
    } catch (e) {
      _logger.e('Error loading initial users: $e');
    }
  }

  Future<void> _loadUsersFromGroups(List<String> groupIds) async {
    _logger.i('Loading users from ${groupIds.length} groups');
    try {
      for (String groupId in groupIds) {
        if (_users.length >= _usersPerPage) break;

        final groupMembersSnapshot =
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('members')
                .get();

        List<String> memberIds =
            groupMembersSnapshot.docs
                .map((doc) => doc.id)
                .where((id) => id != _currentUserId)
                .toList();
        _logger.d('Found ${memberIds.length} members in group $groupId');

        if (memberIds.isNotEmpty) {
          for (String memberId in memberIds) {
            if (_users.any((user) => user['id'] == memberId)) continue;

            if (_currentUserFriendIds.contains(memberId)) {
              _logger.d('Skipping user $memberId (already a friend)');
              continue;
            }

            final userDoc =
                await _firestore.collection('users').doc(memberId).get();
            final userData = userDoc.data();

            if (userData != null && userData['privacyLevel'] == 'public') {
              _users.add({
                'id': memberId,
                'displayName': userData['displayName'] ?? 'Unknown User',
                'photoURL': userData['photoURL'] ?? '',
                'email': userData['email'] ?? '',
                'status': userData['status'] ?? 'No status set',
                'userData': userData,
                'requestStatus': _friendRequestStatuses[memberId] ?? '',
              });

              _logger.d('Added group member $memberId to results');
            }

            if (_users.length >= _usersPerPage) break;
          }
        }
      }

      if (_users.length < _usersPerPage) {
        await _loadPublicUsers();
      } else {
        if (_users.isNotEmpty) {
          _lastDocument =
              await _firestore.collection('users').doc(_users.last['id']).get();
        }
      }
    } catch (e) {
      _logger.e('Error loading users from groups: $e');
    }
  }

  Future<void> _loadPublicUsers() async {
    _logger.i('Loading public users');
    try {
      Query query = _firestore
          .collection('users')
          .where('privacyLevel', isEqualTo: 'public')
          .where(FieldPath.documentId, isNotEqualTo: _currentUserId)
          .limit(_usersPerPage);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await query.get();
      _logger.d('Found ${querySnapshot.docs.length} public users');

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMoreUsers = false;
          if (_users.isEmpty) {
            _showNoUsersFound = true;
          }
        });
        return;
      }

      for (var doc in querySnapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final userId = doc.id;

        if (_users.any((user) => user['id'] == userId)) continue;

        if (_currentUserFriendIds.contains(userId)) {
          _logger.d('Skipping user $userId (already a friend)');
          continue;
        }

        _users.add({
          'id': userId,
          'displayName': userData['displayName'] ?? 'Unknown User',
          'photoURL': userData['photoURL'] ?? '',
          'email': userData['email'] ?? '',
          'status': userData['status'] ?? 'No status set',
          'userData': userData,
          'requestStatus': _friendRequestStatuses[userId] ?? '',
        });

        _logger.d('Added public user $userId to results');
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
      }
    } catch (e) {
      _logger.e('Error loading public users: $e');
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore || !_hasMoreUsers) return;

    _logger.i('Loading more users');
    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _loadPublicUsers();

      _originalUsers = List.from(_users);
    } catch (e) {
      _logger.e('Error loading more users: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _filterUsersByName(String query) {
    _logger.d('Filtering users by name: $query');
    if (query.isEmpty) {
      setState(() {
        _users = List.from(_originalUsers);
      });
      return;
    }

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

  Future<void> _searchUserByEmail() async {
    String email = _searchController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    _logger.i('Searching for user by email: $email');
    setState(() {
      _isLoading = true;
      _isSearchingByEmail = true;
      _showNoUsersFound = false;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

      if (querySnapshot.docs.isEmpty) {
        _logger.d('No user found with email: $email');
        setState(() {
          _users = [];
          _showNoUsersFound = true;
        });
        return;
      }

      List<Map<String, dynamic>> emailUsers = [];

      for (var doc in querySnapshot.docs) {
        if (doc.id == _currentUserId) continue;

        if (_currentUserFriendIds.contains(doc.id)) {
          _logger.d('Skipping user ${doc.id} (already a friend)');
          continue;
        }

        final userData = doc.data();
        final userId = doc.id;

        emailUsers.add({
          'id': userId,
          'displayName': userData['displayName'] ?? 'Unknown User',
          'photoURL': userData['photoURL'] ?? '',
          'email': userData['email'] ?? '',
          'status': userData['status'] ?? 'No status set',
          'userData': userData,
          'privacyLevel': userData['privacyLevel'] ?? 'private',
          'requestStatus': _friendRequestStatuses[userId] ?? '',
        });
      }

      _logger.d('Found ${emailUsers.length} users with email: $email');
      setState(() {
        _users = emailUsers;
        _showNoUsersFound = emailUsers.isEmpty;
      });
    } catch (e) {
      _logger.e('Error searching by email: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _logger.d('Clearing search');
    _searchController.clear();
    setState(() {
      _isSearchingByEmail = false;
      _showNoUsersFound = false;
      _users = List.from(_originalUsers);
    });
  }

  void _toggleEmailSearchMode(bool enabled) {
    _logger.i('Toggling email search mode: $enabled');
    setState(() {
      _isSearchingByEmail = enabled;
      _searchController.clear();

      if (enabled) {
        _users = [];
      } else {
        _users = List.from(_originalUsers);
      }
    });
    _searchFocusNode.requestFocus();
  }

  Future<void> _sendFriendRequest(String userId, String displayName) async {
    _logger.i('Sending friend request to user: $userId');
    try {
      final requestId = _firestore.collection('users').doc().id;

      final currentUserDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final currentUserData = currentUserDoc.data() ?? {};
      final currentUserName = currentUserData['displayName'] ?? 'Unknown User';
      final currentUserPhoto = currentUserData['photoURL'] ?? '';

      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('friendRequests')
          .doc(requestId)
          .set({
            'userId': userId,
            'displayName': displayName,
            'type': 'sent',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('friendRequests')
          .doc(requestId)
          .set({
            'userId': _currentUserId,
            'displayName': currentUserName,
            'photoURL': currentUserPhoto,
            'type': 'received',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _friendRequestStatuses[userId] = 'sent:pending';

        final index = _users.indexWhere((user) => user['id'] == userId);
        if (index != -1) {
          _users[index]['requestStatus'] = 'sent:pending';
          final origIndex = _originalUsers.indexWhere(
            (user) => user['id'] == userId,
          );
          if (origIndex != -1) {
            _originalUsers[origIndex]['requestStatus'] = 'sent:pending';
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to $displayName')),
      );
    } catch (e) {
      _logger.e('Error sending friend request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send friend request. Please try again.'),
        ),
      );
    }
  }

  ImageProvider _getImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/images/default_avatar.jpg');
    }

    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return AssetImage(path);
    }
  }

  Map<String, dynamic> _getRequestStatusInfo(String status) {
    if (status.isEmpty) {
      return {'text': '', 'color': Colors.transparent};
    }

    final parts = status.split(':');
    if (parts.length != 2) {
      return {'text': '', 'color': Colors.transparent};
    }

    final type = parts[0];
    final state = parts[1];

    if (type == 'sent' && state == 'pending') {
      return {'text': 'Request Sent', 'color': Colors.amber.shade700};
    } else if (type == 'sent' && state == 'declined') {
      return {'text': 'Request Declined', 'color': Colors.red.shade400};
    } else if (type == 'received' && state == 'pending') {
      return {'text': 'Requested You', 'color': Colors.purple.shade400};
    }

    return {'text': '', 'color': Colors.transparent};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFA07A), Color(0xFFFFDAB9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchSection(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'FIND FRIENDS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
          if (_isSearchingByEmail)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.black.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        elevation: 2,
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

  Widget _buildUsersList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _users.length + (_isLoadingMore || _hasMoreUsers ? 1 : 0),
      itemBuilder: (context, index) {
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
                    elevation: 3,
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

        final user = _users[index];
        final bool isPrivate = user['userData']['privacyLevel'] == 'private';
        final requestStatus = user['requestStatus'] as String? ?? '';
        final requestInfo = _getRequestStatusInfo(requestStatus);

        return GestureDetector(
          onTap: () {
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
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
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
                      Stack(
                        children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                      border: Border.all(
                                        color: Colors.grey.shade400,
                                        width: 0.5,
                                      ),
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
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F7FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFADD8E6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Color(0xFF4682B4),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      user['status'] ?? 'No status set',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF4682B4),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (requestInfo['text'] != '')
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: requestInfo['color'].withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: requestInfo['color'],
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 12,
                                      color: requestInfo['color'],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      requestInfo['text'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: requestInfo['color'],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (requestStatus.isEmpty)
                        GestureDetector(
                          onTap:
                              () => _sendFriendRequest(
                                user['id'],
                                user['displayName'],
                              ),
                          child: Container(
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
                                  color: const Color(
                                    0xFF80AB82,
                                  ).withOpacity(0.4),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isSearchingByEmail
                  ? 'Try entering a different email address'
                  : 'Try adjusting your search or check back later for new users',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
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
              elevation: 3,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
