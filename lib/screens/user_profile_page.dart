import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current user ID
  String? _currentUserId;

  // User data
  Map<String, dynamic>? _userData;
  List<String> _userTags = [];
  List<Map<String, dynamic>> _userGroups = [];

  // UI state
  bool _isLoading = true;
  bool _isSendingRequest = false;
  bool _hasAlreadySentRequest = false;
  bool _receivedPendingRequest = false;
  bool _previouslyRejected = false;
  bool _areFriends = false;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  // Initialize user data
  Future<void> _initializeUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUserId = _auth.currentUser?.uid;

      if (_currentUserId != null) {
        // Get user data
        final userDoc =
            await _firestore.collection('users').doc(widget.userId).get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;

          // Get tags data
          List<String> tagIds = List<String>.from(data['favTags'] ?? []);

          // Load tag names
          if (tagIds.isNotEmpty) {
            for (String tagId in tagIds) {
              try {
                final tagDoc =
                    await _firestore.collection('tags').doc(tagId).get();
                if (tagDoc.exists) {
                  final tagData = tagDoc.data();
                  if (tagData != null && tagData.containsKey('name')) {
                    _userTags.add(tagData['name']);
                  } else {
                    _userTags.add(tagId); // Fallback to ID if name not found
                  }
                }
              } catch (e) {
                print('Error fetching tag $tagId: $e');
              }
            }
          }

          // Check if a friend request has already been sent
          final sentRequestsSnapshot =
              await _firestore
                  .collection('users')
                  .doc(widget.userId)
                  .collection('friendRequests')
                  .where('userId', isEqualTo: _currentUserId)
                  .get();

          // Check for pending received requests
          final receivedRequestsSnapshot =
              await _firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .collection('friendRequests')
                  .where('userId', isEqualTo: widget.userId)
                  .get();

          // Check for any rejections (from sent requests)
          bool wasRejected = false;
          for (var doc in sentRequestsSnapshot.docs) {
            if (doc.data()['status'] == 'declined') {
              wasRejected = true;
              break;
            }
          }

          // Check if they are already friends
          final friendsSnapshot =
              await _firestore
                  .collection('users')
                  .doc(_currentUserId)
                  .collection('friends')
                  .doc(widget.userId)
                  .get();

          // Get groups data if privacy allows
          if (data['privacyLevel'] != 'private') {
            await _loadUserGroups();
          }

          setState(() {
            _userData = data;
            _hasAlreadySentRequest = sentRequestsSnapshot.docs.any(
              (doc) => doc.data()['status'] == 'pending',
            );
            _previouslyRejected = wasRejected;
            _receivedPendingRequest = receivedRequestsSnapshot.docs.any(
              (doc) => doc.data()['status'] == 'pending',
            );
            _areFriends = friendsSnapshot.exists;
            _isLoading = false;
          });
        } else {
          // User not found
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('User not found')));
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load user groups
  Future<void> _loadUserGroups() async {
    try {
      // Get user's groups
      final userGroupsSnapshot =
          await _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('groups')
              .limit(3)
              .get();

      List<Map<String, dynamic>> groups = [];

      for (var doc in userGroupsSnapshot.docs) {
        final groupData = doc.data();
        final groupId = groupData['groupId'] as String? ?? doc.id;

        // Get group details from main collection
        try {
          final groupDoc =
              await _firestore.collection('groups').doc(groupId).get();
          if (groupDoc.exists) {
            final fullGroupData = groupDoc.data();
            if (fullGroupData != null) {
              // Get member count
              final membersSnapshot =
                  await _firestore
                      .collection('groups')
                      .doc(groupId)
                      .collection('members')
                      .get();

              groups.add({
                'id': groupId,
                'name':
                    groupData['name'] ??
                    fullGroupData['name'] ??
                    'Unnamed Group',
                'photoURL':
                    groupData['photoURL'] ?? fullGroupData['photoURL'] ?? '',
                'memberCount': membersSnapshot.docs.length,
                'role': groupData['role'] ?? 'member',
              });
            }
          }
        } catch (e) {
          print('Error fetching group $groupId: $e');
        }

        if (groups.length >= 3) break; // Limit to 3 groups
      }

      setState(() {
        _userGroups = groups;
      });
    } catch (e) {
      print('Error loading user groups: $e');
    }
  }

  // Send friend request
  Future<void> _sendFriendRequest() async {
    if (_isSendingRequest ||
        _hasAlreadySentRequest ||
        _areFriends ||
        _previouslyRejected)
      return;

    setState(() {
      _isSendingRequest = true;
    });

    try {
      // If received a pending request, accept it instead of sending a new one
      if (_receivedPendingRequest) {
        await _acceptReceivedRequest();
        return;
      }

      // Get current user data for denormalization
      final currentUserDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final currentUserData = currentUserDoc.data();

      if (currentUserData != null) {
        // Create a friend request in the recipient's collection
        await _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('friendRequests')
            .add({
              'userId': _currentUserId,
              'displayName': currentUserData['displayName'] ?? 'Unknown User',
              'photoURL': currentUserData['photoURL'] ?? '',
              'type': 'received',
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });

        setState(() {
          _hasAlreadySentRequest = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Friend request sent to ${_userData?['displayName'] ?? 'user'}',
            ),
            backgroundColor: const Color(0xFF80AB82),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error sending friend request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send friend request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingRequest = false;
      });
    }
  }

  // Accept a received friend request
  Future<void> _acceptReceivedRequest() async {
    try {
      // Find the pending request
      final requestsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('friendRequests')
              .where('userId', isEqualTo: widget.userId)
              .where('status', isEqualTo: 'pending')
              .get();

      if (requestsSnapshot.docs.isEmpty) {
        throw Exception('No pending request found');
      }

      final requestDoc = requestsSnapshot.docs.first;

      // Update the request status
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('friendRequests')
          .doc(requestDoc.id)
          .update({'status': 'accepted'});

      // Add to current user's friends collection
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('friends')
          .doc(widget.userId)
          .set({
            'displayName': _userData?['displayName'] ?? 'Unknown User',
            'photoURL': _userData?['photoURL'] ?? '',
            'becameFriendsAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      // Get current user data
      final currentUserDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final currentUserData = currentUserDoc.data();

      // Add current user to other user's friends collection
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .doc(_currentUserId)
          .set({
            'displayName': currentUserData?['displayName'] ?? 'Unknown User',
            'photoURL': currentUserData?['photoURL'] ?? '',
            'becameFriendsAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });

      setState(() {
        _areFriends = true;
        _receivedPendingRequest = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are now friends with ${_userData?['displayName'] ?? 'user'}!',
          ),
          backgroundColor: const Color(0xFF80AB82),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print('Error accepting friend request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept friend request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      try {
        return FileImage(File(path));
      } catch (e) {
        return const AssetImage('assets/images/default_avatar.jpg');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildProfileContent(),
    );
  }

  // Main profile content
  Widget _buildProfileContent() {
    if (_userData == null) {
      return const Center(child: Text('User data not available'));
    }

    return CustomScrollView(
      slivers: [
        // App bar with profile header
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFFFFA07A), // Salmon color
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(background: _buildProfileHeader()),
        ),

        // Profile content
        SliverToBoxAdapter(child: _buildMainContent()),
      ],
    );
  }

  // Profile header with background and image
  Widget _buildProfileHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFA07A), Color(0xFFFFD6E0)],
            ),
          ),
        ),

        // Decorative shapes
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
        ),

        Positioned(
          bottom: 10,
          left: -40,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Profile info
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
          ),
        ),

        // User image and name
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundImage: _getImageProvider(_userData!['photoURL']),
                  ),
                ),

                const SizedBox(height: 16),

                // User name
                Flexible(
                  child: Text(
                    _userData!['displayName'] ?? 'Unknown User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black12,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Main profile content
  Widget _buildMainContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Friend request button
          const SizedBox(height: 24),
          _buildFriendRequestButton(),

          const SizedBox(height: 32),

          // Interests section
          Row(
            children: const [
              Icon(Icons.interests, color: Color(0xFF80AB82)),
              SizedBox(width: 8),
              Text(
                'Interests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Interest tags
          _userTags.isEmpty
              ? _buildEmptySection('No interests listed')
              : _buildInterestTags(),

          const SizedBox(height: 32),

          // Groups section (visible only if not private)
          if (_userData!['privacyLevel'] != 'private') ...[
            Row(
              children: const [
                Icon(Icons.group, color: Color(0xFFF4A9A8)), // Light coral
                SizedBox(width: 8),
                Text(
                  'Groups',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _userGroups.isEmpty
                ? _buildEmptySection('No groups to show')
                : _buildGroupsList(),

            const SizedBox(height: 32),
          ],

          // Space at the bottom
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Friend request button or status
  Widget _buildFriendRequestButton() {
    // Already friends
    if (_areFriends) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF80AB82), Color(0xFF98D8C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF80AB82).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Friends',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Request already sent
    if (_hasAlreadySentRequest) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB347).withOpacity(0.9), // Orange
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB347).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.schedule, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Request Sent',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Previously rejected - can't send another request
    if (_previouslyRejected) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.do_not_disturb, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Not Available',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Received pending request - accept directly
    if (_receivedPendingRequest) {
      return Center(
        child: GestureDetector(
          onTap: _isSendingRequest ? null : _sendFriendRequest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF80AB82), Color(0xFF98D8C8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF80AB82).withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child:
                _isSendingRequest
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Accept Friend Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      );
    }

    // Normal send request button
    return Center(
      child: GestureDetector(
        onTap: _isSendingRequest ? null : _sendFriendRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFA07A), Color(0xFFFFD6E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFA07A).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child:
              _isSendingRequest
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.person_add, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Send Friend Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  // Interest tags
  Widget _buildInterestTags() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          _userTags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getRandomTagColor(),
                    _getRandomTagColor().withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            );
          }).toList(),
    );
  }

  // Groups list
  Widget _buildGroupsList() {
    return Column(
      children:
          _userGroups.map((group) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Group avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _getGroupColor(group),
                    ),
                    child: const Center(
                      child: Icon(Icons.group, color: Colors.white, size: 28),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Group details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['name'] ?? 'Unnamed Group',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group['memberCount'] ?? '?'} members',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Role badge
                  if (group['role'] == 'admin')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA07A).withOpacity(0.2),
                        border: Border.all(color: const Color(0xFFFFA07A)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFFA07A),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
    );
  }

  // Empty section placeholder
  Widget _buildEmptySection(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  // Helper to get a random color for tags
  Color _getRandomTagColor() {
    final List<Color> colors = [
      const Color(0xFFFFD6E0), // Light pink
      const Color(0xFFF0E6FA), // Light purple
      const Color(0xFFE6F0FA), // Light blue
      const Color(0xFFE6FAF0), // Light mint
      const Color(0xFFFAF0E6), // Light peach
      const Color(0xFFD6FFE0), // Light green
    ];

    final randomIndex = DateTime.now().microsecondsSinceEpoch % colors.length;
    return colors[randomIndex];
  }

  // Helper to get group color
  Color _getGroupColor(Map<String, dynamic> group) {
    final List<Color> colors = [
      const Color(0xFF98D8C8), // Light teal
      const Color(0xFFF4A9A8), // Light coral
      const Color(0xFFD8BFD8), // Light purple
      const Color(0xFF80AB82), // Green
      const Color(0xFFB0C4DE), // Light steel blue
    ];

    // Use the first character of the group name to determine color (consistent)
    final String name = (group['name'] as String?) ?? 'Group';
    final int index = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;

    return colors[index];
  }
}
