import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'journal_page.dart';
import 'dashboard.dart';
import 'chat_page.dart';
import 'find_friends_page.dart';
import 'create_group_page.dart';
import 'join_group_page.dart';

class FriendsGroupsPage extends StatefulWidget {
  const FriendsGroupsPage({super.key});

  @override
  State<FriendsGroupsPage> createState() => _FriendsGroupsPageState();
}

class _FriendsGroupsPageState extends State<FriendsGroupsPage> {
  int _selectedTabIndex = 0; // 0: Friends, 1: Groups, 2: Requests
  bool _showGroupInvites =
      false; // Toggle between friend requests and group invites

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user ID
  String? _currentUserId;

  // Stream data
  Stream<QuerySnapshot>? _friendsStream;
  Stream<QuerySnapshot>? _groupsStream;
  Stream<QuerySnapshot>? _friendRequestsStream;
  Stream<QuerySnapshot>? _groupInvitesStream;

  @override
  void initState() {
    super.initState();
    _initializeCurrentUser();
  }

  @override
  void dispose() {
    // Make sure to clean up any resources when the widget is removed
    super.dispose();
  }

  // Initialize current user and setup streams
  Future<void> _initializeCurrentUser() async {
    _currentUserId = _auth.currentUser?.uid;
    if (_currentUserId != null) {
      _setupStreams();
    }
  }

  // Setup all data streams based on the Firestore schema
  void _setupStreams() {
    if (_currentUserId == null) return;

    // Friends collection - users who are friends with the current user
    _friendsStream =
        _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('friends')
            .snapshots();

    // Groups the user is a member of - from user's groups subcollection
    _groupsStream =
        _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('groups')
            .snapshots();

    // Received friend requests - using friendRequests subcollection
    _friendRequestsStream =
        _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('friendRequests')
            .where('type', isEqualTo: 'received')
            .where('status', isEqualTo: 'pending')
            .snapshots();

    // Group invites - using groupInvites subcollection
    _groupInvitesStream =
        _firestore
            .collection('users')
            .doc(_currentUserId)
            .collection('groupInvites')
            .where('status', isEqualTo: 'pending')
            .snapshots();

    // Force UI refresh after streams are set up
    if (mounted) {
      setState(() {});
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
            color: const Color(
              0xFFFFA07A,
            ), // Salmon background to match journal page
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabSelector(),
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
            child: Container(
              color: Colors.white,
              child: _buildSelectedTabContent(),
            ),
          ),
        ],
      ),
      // Bottom navigation bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Header with page title
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: const Text(
        'FRIENDS & GROUPS',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  // Tab selector for Friends, Groups, and Requests
  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            _buildTabButton(0, 'Friends'),
            _buildTabButton(1, 'Groups'),
            _buildTabButton(2, 'Requests'),
          ],
        ),
      ),
    );
  }

  // Individual tab button
  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color:
                    isSelected ? Colors.black : Colors.black.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Content for the selected tab
  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildFriendsTab();
      case 1:
        return _buildGroupsTab();
      case 2:
        return _buildRequestsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // Friends tab content
  Widget _buildFriendsTab() {
    if (_currentUserId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Please sign in to view friends',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _friendsStream,
      builder: (context, snapshot) {
        // Always show content inside a SingleChildScrollView for consistency
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Your Friends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // Show loading, error, or content as appropriate
              if (snapshot.connectionState == ConnectionState.waiting)
                _buildLoadingIndicator()
              else if (snapshot.hasError)
                _buildErrorMessage('Error loading friends: ${snapshot.error}')
              else if ((snapshot.data?.docs.length ?? 0) == 0)
                _buildEmptyFriendsMessage()
              else
                ...snapshot.data!.docs.map((doc) {
                  // Build individual friend cards
                  final friendData = doc.data() as Map<String, dynamic>;
                  final friendId = doc.id;

                  // Get friend's display name and photo from the friends subcollection
                  final displayName =
                      friendData['displayName'] ?? 'Unknown User';
                  final photoURL =
                      friendData['photoURL'] ??
                      'assets/images/default_avatar.jpg';

                  // Get befriended timestamp
                  final becameFriendsAt = friendData['becameFriendsAt'];
                  final lastActive =
                      becameFriendsAt != null
                          ? 'Friends since ${_formatLastActive(becameFriendsAt)}'
                          : 'Unknown';

                  return _buildFriendCard({
                    'id': friendId,
                    'name': displayName,
                    'avatar': photoURL,
                    'lastActive': lastActive,
                  });
                }).toList(),

              // Always show the Find Friends button (crucial for new users!)
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const FindFriendsPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA07A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Find More Friends',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper widgets for the friends tab
  Widget _buildLoadingIndicator() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildErrorMessage(String errorMessage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFriendsMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No friends yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Use the button below to find new friends',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Icon(Icons.arrow_downward, size: 24, color: Colors.grey[500]),
        ],
      ),
    );
  }

  // Groups tab content
  Widget _buildGroupsTab() {
    if (_currentUserId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Please sign in to view groups',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _groupsStream,
      builder: (context, snapshot) {
        // Always show content inside a SingleChildScrollView for consistency
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Your Groups',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // Show loading, error, or content as appropriate
              if (snapshot.connectionState == ConnectionState.waiting)
                _buildLoadingIndicator()
              else if (snapshot.hasError)
                _buildErrorMessage('Error loading groups: ${snapshot.error}')
              else if ((snapshot.data?.docs.length ?? 0) == 0)
                _buildEmptyGroupsMessage()
              else
                Column(
                  children:
                      snapshot.data!.docs.map((doc) {
                        // Build individual group cards
                        final groupData = doc.data() as Map<String, dynamic>;

                        // Use the document ID directly as the group ID
                        final groupId = doc.id;
                        final groupName = groupData['name'] ?? 'Unnamed Group';
                        final photoURL =
                            groupData['photoURL'] ??
                            'assets/images/default_group.jpg';
                        final joinedAt = groupData['joinedAt'];
                        final role = groupData['role'] ?? 'member';

                        return _buildGroupCard({
                          'id': groupId,
                          'name': groupName,
                          'avatar': photoURL,
                          'members':
                              0, // Default to 0, we'll fetch this separately
                          'role': role,
                          'lastActive':
                              joinedAt != null
                                  ? 'Joined ${_formatLastActive(joinedAt)}'
                                  : 'Unknown',
                        });
                      }).toList(),
                ),

              // Always show the Groups action buttons (crucial for new users!)
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const JoinGroupPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF80AB82),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Join a Group',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CreateGroupPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD8BFD8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Create Group',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper widget for the groups tab
  Widget _buildEmptyGroupsMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'You\'re not in any groups yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Join an existing group or create a new one',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Icon(Icons.arrow_downward, size: 24, color: Colors.grey[500]),
        ],
      ),
    );
  }

  // Show a coming soon snackbar for features not yet implemented
  void _showComingSoonSnackBar(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Requests tab content
  Widget _buildRequestsTab() {
    if (_currentUserId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Please sign in to view requests',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Request type toggle button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showGroupInvites = false;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            !_showGroupInvites
                                ? const Color(0xFFFFA07A)
                                : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(23),
                          bottomLeft: Radius.circular(23),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Friend Requests',
                          style: TextStyle(
                            fontWeight:
                                !_showGroupInvites
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: double.infinity,
                  color: Colors.black,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showGroupInvites = true;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            _showGroupInvites
                                ? const Color(0xFFFFA07A)
                                : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(23),
                          bottomRight: Radius.circular(23),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Group Invites',
                          style: TextStyle(
                            fontWeight:
                                _showGroupInvites
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Use IndexedStack to maintain both list states
          IndexedStack(
            index: _showGroupInvites ? 1 : 0,
            children: [_buildFriendRequestsList(), _buildGroupInvitesList()],
          ),
        ],
      ),
    );
  }

  // Build the list of friend requests
  Widget _buildFriendRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _friendRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 100,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorMessage(
            'Error loading requests: ${snapshot.error}',
          );
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_disabled,
                  size: 50,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No friend requests received',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children:
              requests.map((doc) {
                final requestData = doc.data() as Map<String, dynamic>;
                final requestId = doc.id;

                // Get sender information with safer type handling
                String userId = '';
                try {
                  userId = requestData['userId'] as String? ?? '';
                } catch (e) {
                  print('Error parsing userId: $e');
                }

                final displayName =
                    requestData['displayName'] ?? 'Unknown User';
                final photoURL =
                    requestData['photoURL'] ??
                    'assets/images/default_avatar.jpg';
                final createdAt = requestData['createdAt'];

                return _buildReceivedRequestCard({
                  'id': requestId,
                  'userId': userId,
                  'name': displayName,
                  'avatar': photoURL,
                  'sentAt':
                      createdAt != null
                          ? _formatLastActive(createdAt)
                          : 'Recently',
                });
              }).toList(),
        );
      },
    );
  }

  // Build the list of group invites
  Widget _buildGroupInvitesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _groupInvitesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 100,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorMessage(
            'Error loading group invites: ${snapshot.error}',
          );
        }

        final invites = snapshot.data?.docs ?? [];

        if (invites.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No pending group invites',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children:
              invites.map((doc) {
                final inviteData = doc.data() as Map<String, dynamic>;
                final inviteId = doc.id;

                // Get group information with null safety
                final groupId = inviteData['groupId'] as String? ?? '';
                final groupName = inviteData['groupName'] ?? 'Unknown Group';
                final inviterName = inviteData['inviterName'] ?? 'Unknown User';
                final createdAt = inviteData['createdAt'];

                return _buildGroupInviteCard({
                  'id': inviteId,
                  'groupId': groupId,
                  'name': groupName,
                  'inviterName': inviterName,
                  'avatar':
                      'assets/images/default_group.jpg', // Default group image
                  'sentAt':
                      createdAt != null
                          ? _formatLastActive(createdAt)
                          : 'Recently',
                });
              }).toList(),
        );
      },
    );
  }

  // Friend card UI with chat navigation
  Widget _buildFriendCard(Map<String, dynamic> friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
              image: DecorationImage(
                image: _getImageProvider(friend['avatar']),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  friend['lastActive'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Message button with navigation to ChatPage
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => ChatPage(
                        friendName: friend['name'],
                        friendAvatar: friend['avatar'],
                        friendId: friend['id'],
                      ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF4A9A8), // Light coral from dashboard
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.message, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // Group card UI
  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          // Group avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 1),
              image: DecorationImage(
                image: _getImageProvider(group['avatar']),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Group details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${group['members']} members · ${group['lastActive']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (group['role'] == 'admin')
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          // Enter group button
          GestureDetector(
            onTap: () {
              // TODO: Implement navigation to the group detail page
              _showComingSoonSnackBar('Group details');
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF98D8C8), // Light teal from dashboard
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Received friend request card
  Widget _buildReceivedRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1),
                  image: DecorationImage(
                    image: _getImageProvider(request['avatar']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sent ${request['sentAt']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      () => _handleFriendRequest(
                        request['id'],
                        request['userId'],
                        'accept',
                      ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF80AB82),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      () => _handleFriendRequest(
                        request['id'],
                        request['userId'],
                        'decline',
                      ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Group invite card
  Widget _buildGroupInviteCard(Map<String, dynamic> invite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Group avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Square with rounded corners for groups
                  border: Border.all(color: Colors.black, width: 1),
                  image: DecorationImage(
                    image: _getImageProvider(invite['avatar']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Group name and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Invited by ${invite['inviterName']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      'Received ${invite['sentAt']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      () => _handleGroupInvite(
                        invite['id'],
                        invite['groupId'],
                        'accept',
                      ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF80AB82),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Join Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      () => _handleGroupInvite(
                        invite['id'],
                        invite['groupId'],
                        'decline',
                      ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Empty state widget (for places where we need a simpler empty state)
  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Bottom navigation bar
  Widget _buildBottomNavBar() {
    return Container(
      height: 55,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 25.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA07A),
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
          _buildNavItem(Icons.bar_chart, false),
          _buildNavItem(Icons.access_time, false),
          // Home icon with navigation back to Dashboard
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
            },
            child: _buildNavItem(Icons.home, false),
          ),
          // Journal icon with navigation to Journal page
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const JournalPage()),
              );
            },
            child: _buildNavItem(Icons.assessment, false),
          ),
          _buildNavItem(Icons.person_outline, true), // Person icon is selected
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

  // Helper methods
  // Format last active timestamp to a readable format
  String _formatLastActive(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime lastActiveTime;

    if (timestamp is Timestamp) {
      lastActiveTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      lastActiveTime = timestamp;
    } else {
      return 'Unknown';
    }

    final now = DateTime.now();
    final difference = now.difference(lastActiveTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastActiveTime.day}/${lastActiveTime.month}/${lastActiveTime.year}';
    }
  }

  // Get image provider with fallback for errors
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

  // Friend request handling methods
  Future<void> _handleFriendRequest(
    String requestId,
    String userId,
    String action,
  ) async {
    if (_currentUserId == null) return;

    try {
      // Update the request status in friendRequests collection
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('friendRequests')
          .doc(requestId)
          .update({'status': action == 'accept' ? 'accepted' : 'declined'});

      if (action == 'accept') {
        // Get the user data for the friend
        final userSnapshot =
            await _firestore.collection('users').doc(userId).get();
        final userData = userSnapshot.data();

        if (userData != null) {
          // Add to current user's friends collection
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('friends')
              .doc(userId)
              .set({
                'displayName': userData['displayName'] ?? 'Unknown User',
                'photoURL': userData['photoURL'],
                'becameFriendsAt': FieldValue.serverTimestamp(),
                'status': 'active',
              });

          // Get current user's data
          final currentUserSnapshot =
              await _firestore.collection('users').doc(_currentUserId).get();
          final currentUserData = currentUserSnapshot.data();

          if (currentUserData != null) {
            // Add current user to friend's friends collection
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('friends')
                .doc(_currentUserId)
                .set({
                  'displayName':
                      currentUserData['displayName'] ?? 'Unknown User',
                  'photoURL': currentUserData['photoURL'],
                  'becameFriendsAt': FieldValue.serverTimestamp(),
                  'status': 'active',
                });

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'You are now friends with ${userData['displayName'] ?? 'this user'}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      }
    } catch (error) {
      print('Error handling friend request: $error');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing friend request: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle group invite (accept or decline)
  Future<void> _handleGroupInvite(
    String inviteId,
    String groupId,
    String action,
  ) async {
    if (_currentUserId == null) return;

    try {
      // Update the invite status
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('groupInvites')
          .doc(inviteId)
          .update({'status': action == 'accept' ? 'accepted' : 'declined'});

      if (action == 'accept') {
        // Get group details
        final groupSnapshot =
            await _firestore.collection('groups').doc(groupId).get();
        final groupData = groupSnapshot.data();

        if (groupData != null) {
          // Add user to group's members subcollection
          await _firestore
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .doc(_currentUserId)
              .set({
                'displayName': _auth.currentUser?.displayName ?? 'Unknown User',
                'photoURL': _auth.currentUser?.photoURL,
                'role': 'member', // Default role for invited members
                'joinedAt': FieldValue.serverTimestamp(),
              });

          // Add group to user's groups subcollection without the "groupId" field
          // since the document ID itself is the group ID
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('groups')
              .doc(groupId)
              .set({
                'name': groupData['name'] ?? 'Unnamed Group',
                'photoURL': groupData['photoURL'],
                'role': 'member',
                'joinedAt': FieldValue.serverTimestamp(),
              });

          // Remove from group's pendingInvites if it exists there
          try {
            await _firestore
                .collection('groups')
                .doc(groupId)
                .collection('pendingInvites')
                .doc(_currentUserId)
                .delete();
          } catch (e) {
            // Ignore if not found
          }

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You have joined ${groupData['name'] ?? 'the group'}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (error) {
      print('Error handling group invite: $error');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing group invite: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
