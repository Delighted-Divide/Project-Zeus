import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:logger/logger.dart';
import 'dart:io';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late AnimationController _animationController;

  String? _currentUserId;
  Map<String, dynamic>? _userData;
  List<String> _userTags = [];
  List<Map<String, dynamic>> _userGroups = [];
  String? _profileImageUrl;

  bool _isLoading = true;
  bool _isSendingRequest = false;

  bool _hasAlreadySentRequest = false;
  bool _receivedPendingRequest = false;
  bool _userRejectedMyRequest = false;
  bool _iRejectedUserRequest = false;
  bool _areFriends = false;

  static const Map<String, Color> colors = {
    'background': Color(0xFFF5F7FA),
    'primary': Color(0xFF6B8DE3),
    'primaryDark': Color(0xFF4B64DA),
    'secondary': Color(0xFFF2994A),
    'secondaryDark': Color(0xFFE77E23),
    'accent': Color(0xFF6FCF97),
    'accentDark': Color(0xFF4BB543),
    'accent2': Color(0xFFBB6BD9),
    'groupColor': Color(0xFF4ECDC4),
    'text': Color(0xFF2D3748),
    'textLight': Color(0xFF718096),
    'divider': Color(0xFFEDF2F7),
    'error': Color(0xFFE53E3E),
    'inactive': Color(0xFFCBD5E0),
    'white': Colors.white,
    'transparent': Colors.transparent,
  };

  @override
  void initState() {
    super.initState();
    _logger.i("Initializing UserProfilePage for userId: ${widget.userId}");

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _initializeUserData();
  }

  @override
  void dispose() {
    _logger.d("Disposing UserProfilePage resources");
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    _logger.d("Starting initialization of user data");

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _currentUserId = _auth.currentUser?.uid;
      _logger.d("Current user ID: $_currentUserId");

      if (_currentUserId == null) {
        throw Exception('No user signed in');
      }

      final userDoc =
          await _firestore.collection('users').doc(widget.userId).get();

      if (!userDoc.exists) {
        _logger.e("User document does not exist");
        throw Exception('User not found');
      }

      final data = userDoc.data() as Map<String, dynamic>;
      _logger.d("User data retrieved successfully");

      await Future.wait([
        _getProfileImage(data['photoURL']),
        _loadUserTags(data),
        _checkRelationshipStatus(),
        if (data['privacyLevel'] != 'private')
          _loadUserGroups()
        else
          Future.value(),
      ]);

      if (!mounted) return;

      setState(() {
        _userData = data;
        _isLoading = false;
      });

      _animationController.forward();
      _logger.i("User profile data loaded successfully");
    } catch (e) {
      _logger.e("Error loading user data", error: e);

      if (mounted) {
        Navigator.of(context).pop();
        _showSnackbar('Error loading profile', isError: true);
      }
    }
  }

  Future<void> _getProfileImage(String? photoURL) async {
    _logger.d("Getting profile image. URL: $photoURL");

    if (photoURL != null && photoURL.isNotEmpty) {
      _logger.d("Validating provided photo URL");

      try {
        final response = await imageUrlIsValid(photoURL);
        if (response) {
          _logger.d("Provided URL is valid");
          if (!mounted) return;
          setState(() {
            _profileImageUrl = photoURL;
          });
          return;
        } else {
          _logger.w("Provided URL is invalid or inaccessible");
        }
      } catch (e) {
        _logger.w("Error validating image URL", error: e);
      }
    }

    try {
      _logger.d("Getting random profile image from storage");

      final storageRef = _storage.ref().child('profile_pics');
      final listResult = await storageRef.listAll();

      if (listResult.items.isEmpty) {
        _logger.w("No profile images found in storage");
        return;
      }

      _logger.d("Found ${listResult.items.length} profile images in storage");

      final randomIndex = math.Random().nextInt(listResult.items.length);
      final randomImageRef = listResult.items[randomIndex];
      _logger.d(
        "Selected random image at index $randomIndex: ${randomImageRef.name}",
      );

      final downloadURL = await randomImageRef.getDownloadURL();
      _logger.d("Got download URL: $downloadURL");

      if (!mounted) return;
      setState(() {
        _profileImageUrl = downloadURL;
      });
    } catch (e) {
      _logger.e("Error getting random profile image", error: e);
    }
  }

  Future<bool> imageUrlIsValid(String url) async {
    try {
      final client = HttpClient();
      final request = await client.headUrl(Uri.parse(url));
      final response = await request.close();
      client.close();

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      _logger.w("URL validation error", error: e);
      return false;
    }
  }

  Future<void> _loadUserTags(Map<String, dynamic> userData) async {
    _logger.d("Loading user tags");

    final List<dynamic> tagIdsDynamic = userData['favTags'] ?? [];
    final List<String> tagIds = tagIdsDynamic.cast<String>();
    _logger.d("Found ${tagIds.length} tag IDs");

    if (tagIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _userTags = [];
      });
      return;
    }

    try {
      final List<String> tagNames = [];

      final chunks = _chunkList(tagIds, 10);

      for (final chunk in chunks) {
        final futures = chunk.map((tagId) async {
          try {
            final tagDoc = await _firestore.collection('tags').doc(tagId).get();
            if (tagDoc.exists) {
              final tagData = tagDoc.data();
              return tagData?['name'] as String? ?? tagId;
            } else {
              return tagId;
            }
          } catch (e) {
            _logger.e("Error fetching tag $tagId", error: e);
            return tagId;
          }
        });

        final results = await Future.wait(futures);
        tagNames.addAll(results);
      }

      if (!mounted) return;
      setState(() {
        _userTags = tagNames;
      });
      _logger.d("Loaded ${_userTags.length} tags");
    } catch (e) {
      _logger.e("Error loading tags", error: e);
    }
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, math.min(i + chunkSize, list.length)));
    }
    return chunks;
  }

  Future<void> _checkRelationshipStatus() async {
    _logger.d("Checking relationship status with user ${widget.userId}");

    try {
      if (_currentUserId == widget.userId) {
        _logger.d("Viewing own profile, skipping relationship check");
        return;
      }

      final friendDoc =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('friends')
              .doc(widget.userId)
              .get();

      if (friendDoc.exists) {
        _logger.d("Users are already friends");
        if (!mounted) return;
        setState(() {
          _areFriends = true;
          _hasAlreadySentRequest = false;
          _userRejectedMyRequest = false;
          _receivedPendingRequest = false;
          _iRejectedUserRequest = false;
        });
        return;
      }

      bool hasSentRequest = false;
      bool wasRejected = false;
      bool hasReceivedRequest = false;
      bool didReject = false;

      try {
        final relationHistoryDoc =
            await _firestore
                .collection('relationshipHistory')
                .doc('${_currentUserId}_${widget.userId}')
                .get();

        if (relationHistoryDoc.exists) {
          final data = relationHistoryDoc.data();
          if (data != null &&
              data['status'] == 'declined' &&
              data['initiator'] == _currentUserId) {
            _logger.d("Found declined relationship in history");
            wasRejected = true;
          }
        }
      } catch (e) {
        _logger.w("Error checking relationship history", error: e);
      }

      final sentRequestsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('friendRequests')
              .where('userId', isEqualTo: widget.userId)
              .where('type', isEqualTo: 'sent')
              .get();

      _logger.d("Found ${sentRequestsSnapshot.docs.length} sent requests");

      for (final doc in sentRequestsSnapshot.docs) {
        final status = doc.data()['status'] as String?;

        if (status == 'pending') {
          hasSentRequest = true;
          _logger.d("Found pending sent request");
        } else if (status == 'declined') {
          wasRejected = true;
          _logger.d("Found declined sent request");
        }
      }

      final receivedRequestsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('friendRequests')
              .where('userId', isEqualTo: widget.userId)
              .where('type', isEqualTo: 'received')
              .get();

      _logger.d(
        "Found ${receivedRequestsSnapshot.docs.length} received requests",
      );

      for (final doc in receivedRequestsSnapshot.docs) {
        final status = doc.data()['status'] as String?;

        if (status == 'pending') {
          hasReceivedRequest = true;
          _logger.d("Found pending received request");
        } else if (status == 'declined') {
          didReject = true;
          _logger.d("Found declined received request");
        }
      }

      try {
        final userMetadataDoc =
            await _firestore
                .collection('users')
                .doc(_currentUserId)
                .collection('metadata')
                .doc('friendRequestHistory')
                .get();

        if (userMetadataDoc.exists) {
          final data = userMetadataDoc.data();
          final rejectedList = data?['rejectedBy'] as List<dynamic>? ?? [];

          if (rejectedList.contains(widget.userId)) {
            _logger.d("Found user ID in rejected list in metadata");
            wasRejected = true;
          }
        }
      } catch (e) {
        _logger.w("Error checking user metadata", error: e);
      }

      if (!mounted) return;
      setState(() {
        _hasAlreadySentRequest = hasSentRequest;
        _userRejectedMyRequest = wasRejected;
        _receivedPendingRequest = hasReceivedRequest;
        _iRejectedUserRequest = didReject;
      });

      _logger.d(
        "Final relationship status: Friends=$_areFriends, SentRequest=$_hasAlreadySentRequest, UserRejected=$_userRejectedMyRequest",
      );
    } catch (e) {
      _logger.e("Error checking relationship status", error: e);
    }
  }

  Future<void> _loadUserGroups() async {
    _logger.d("Loading user groups");
    try {
      final userGroupsSnapshot =
          await _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('groups')
              .limit(3)
              .get();

      _logger.d("Found ${userGroupsSnapshot.docs.length} groups");

      final List<Map<String, dynamic>> groups = [];
      final List<Future<void>> groupFutures = [];

      for (final doc in userGroupsSnapshot.docs) {
        final groupData = doc.data();
        final groupId = groupData['groupId'] as String? ?? doc.id;

        groupFutures.add(
          (() async {
            try {
              final groupDoc =
                  await _firestore.collection('groups').doc(groupId).get();
              if (!groupDoc.exists) return;

              final fullGroupData = groupDoc.data();
              if (fullGroupData == null) return;

              final membersSnapshot =
                  await _firestore
                      .collection('groups')
                      .doc(groupId)
                      .collection('members')
                      .count()
                      .get();

              final memberCount = membersSnapshot.count;
              _logger.v("Group '$groupId' has $memberCount members");

              final groupInfo = {
                'id': groupId,
                'name':
                    groupData['name'] ??
                    fullGroupData['name'] ??
                    'Unnamed Group',
                'photoURL':
                    groupData['photoURL'] ?? fullGroupData['photoURL'] ?? '',
                'memberCount': memberCount,
                'role': groupData['role'] ?? 'member',
              };

              groups.add(groupInfo);
            } catch (e) {
              _logger.e("Error fetching group $groupId", error: e);
            }
          })(),
        );

        if (groups.length >= 3) break;
      }

      await Future.wait(groupFutures);

      if (!mounted) return;
      setState(() {
        _userGroups = groups;
      });

      _logger.d("Successfully loaded ${_userGroups.length} groups");
    } catch (e) {
      _logger.e("Error loading user groups", error: e);
    }
  }

  Future<void> _handleFriendRequest() async {
    _logger.d("Handling friend request action");

    if (_userRejectedMyRequest) {
      _logger.w(
        "BLOCKED: User previously rejected our request, cannot send new one",
      );
      return;
    }

    if (_isSendingRequest || _areFriends || _hasAlreadySentRequest) {
      _logger.d(
        "Cannot process request: already in progress, already friends, or already sent",
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSendingRequest = true;
    });

    try {
      if (_receivedPendingRequest || _iRejectedUserRequest) {
        _logger.d(
          "Has pending/rejected received request, accepting instead of sending new one",
        );
        await _acceptFriendRequest();
        return;
      }

      if (_userRejectedMyRequest) {
        _logger.d("User previously rejected our request, cannot send new one");
        if (!mounted) return;
        setState(() {
          _isSendingRequest = false;
        });
        return;
      }

      await _sendFriendRequest();
    } catch (e) {
      _logger.e("Error handling friend request", error: e);
      _showSnackbar('Failed to process friend request', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isSendingRequest = false;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    _logger.d("Sending friend request to user ${widget.userId}");

    try {
      final currentUserDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final currentUserData = currentUserDoc.data();

      if (currentUserData == null) {
        throw Exception('Current user data not found');
      }

      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('friendRequests')
          .add({
            'userId': widget.userId,
            'displayName': _userData?['displayName'] ?? 'Unknown User',
            'photoURL': _userData?['photoURL'] ?? '',
            'type': 'sent',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

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

      if (!mounted) return;
      setState(() {
        _hasAlreadySentRequest = true;
      });

      _showSnackbar(
        'Friend request sent to ${_userData?['displayName'] ?? 'user'}',
      );
      _logger.i("Successfully sent friend request");
    } catch (e) {
      _logger.e("Error sending friend request", error: e);
      throw e;
    }
  }

  Future<void> _acceptFriendRequest() async {
    _logger.d("Accepting friend request from user ${widget.userId}");

    try {
      await _deleteExistingRequests();

      final currentUserDoc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final currentUserData = currentUserDoc.data();

      if (currentUserData == null) {
        throw Exception('Current user data not found');
      }

      final timestamp = FieldValue.serverTimestamp();

      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('friends')
          .doc(widget.userId)
          .set({
            'displayName': _userData?['displayName'] ?? 'Unknown User',
            'photoURL': _userData?['photoURL'] ?? '',
            'becameFriendsAt': timestamp,
            'status': 'active',
          });

      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('friends')
          .doc(_currentUserId)
          .set({
            'displayName': currentUserData['displayName'] ?? 'Unknown User',
            'photoURL': currentUserData['photoURL'] ?? '',
            'becameFriendsAt': timestamp,
            'status': 'active',
          });

      if (!mounted) return;
      setState(() {
        _areFriends = true;
        _receivedPendingRequest = false;
        _iRejectedUserRequest = false;
        _hasAlreadySentRequest = false;
        _userRejectedMyRequest = false;
      });

      _showSnackbar(
        'You are now friends with ${_userData?['displayName'] ?? 'user'}!',
      );
      _logger.i("Successfully accepted friend request");
    } catch (e) {
      _logger.e("Error accepting friend request", error: e);
      throw e;
    }
  }

  Future<void> _deleteExistingRequests() async {
    _logger.d("Deleting existing friend requests");

    try {
      final receivedRequestsSnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('friendRequests')
              .where('userId', isEqualTo: widget.userId)
              .get();

      final sentRequestsSnapshot =
          await _firestore
              .collection('users')
              .doc(widget.userId)
              .collection('friendRequests')
              .where('userId', isEqualTo: _currentUserId)
              .get();

      final batch = _firestore.batch();

      for (final doc in receivedRequestsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      for (final doc in sentRequestsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _logger.d("Deleted all existing friend requests");
    } catch (e) {
      _logger.e("Error deleting existing requests", error: e);
      throw e;
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    _logger.d("Showing snackbar: $message, isError: $isError");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors['error'] : colors['primary'],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _logger.d("WillPopScope triggered, navigating back");
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: colors['background'],
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: colors['transparent'],
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: colors['white']!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: BackButton(
                color: colors['white'],
                onPressed: () {
                  _logger.d("Back button pressed, navigating back");
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ),
        body:
            _isLoading
                ? _buildLoadingView()
                : SafeArea(top: false, child: _buildProfileContent()),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
            width: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(colors['primary']!),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Profile...',
            style: TextStyle(
              color: colors['text'],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: [_buildProfileHeader(), _buildProfileBody()]),
    );
  }

  Widget _buildProfileHeader() {
    final bool isActive = _userData?['isActive'] ?? false;
    final bool isPrivate = _userData?['privacyLevel'] == 'private';
    final String statusText = _userData?['status'] ?? '';

    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors['primary']!, colors['primaryDark']!],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: WavePainter())),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colors['background'],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors['white']!, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child:
                            _profileImageUrl != null
                                ? Image.network(
                                  _profileImageUrl!,
                                  fit: BoxFit.cover,
                                  width: 110,
                                  height: 110,
                                  errorBuilder: (_, __, ___) {
                                    _logger.w(
                                      "Error loading profile image, showing placeholder",
                                    );
                                    return Icon(
                                      Icons.person,
                                      color: colors['white'],
                                      size: 50,
                                    );
                                  },
                                )
                                : Icon(
                                  Icons.person,
                                  color: colors['white'],
                                  size: 50,
                                ),
                      ),
                    ),

                    if (!isPrivate)
                      Positioned(
                        bottom: 3,
                        right: 3,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? colors['accent']
                                    : colors['inactive'],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors['white']!,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  _userData?['displayName'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                statusText.isNotEmpty
                    ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors['white'],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: colors['primary'],
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: colors['text'],
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileBody() {
    final bool isPrivate = _userData?['privacyLevel'] == 'private';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentUserId != widget.userId) _buildFriendRequestButton(),

          const SizedBox(height: 24),

          if (_userData?['bio'] != null &&
              _userData!['bio'].toString().isNotEmpty)
            _buildBioSection(),

          _buildInterestsSection(),

          if (!isPrivate) _buildGroupsSection(),
        ],
      ),
    );
  }

  Widget _buildFriendRequestButton() {
    final bool isCompletelyDisabled = _userRejectedMyRequest || _areFriends;

    final bool isClickable =
        !isCompletelyDisabled &&
        (_canSendFriendRequest() ||
            _receivedPendingRequest ||
            _iRejectedUserRequest);
    final buttonText = _getFriendButtonText();
    final buttonIcon = _getFriendButtonIcon();
    final buttonGradient = _getFriendButtonGradient();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: buttonGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getFriendButtonColor().withOpacity(
              isCompletelyDisabled ? 0.15 : 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: colors['transparent'],
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              isClickable && !_isSendingRequest ? _handleFriendRequest : null,
          splashColor: isCompletelyDisabled ? Colors.transparent : null,
          highlightColor: isCompletelyDisabled ? Colors.transparent : null,
          child: Opacity(
            opacity: isCompletelyDisabled ? 0.7 : 1.0,
            child: Center(
              child:
                  _isSendingRequest
                      ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors['white']!,
                          ),
                        ),
                      )
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(buttonIcon, color: colors['white'], size: 22),
                          const SizedBox(width: 12),
                          Text(
                            buttonText,
                            style: TextStyle(
                              color: colors['white'],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colors['white'],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: colors['accent2'],
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'About Me',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors['text'],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Icon(
                      Icons.format_quote,
                      color: colors['accent2']!.withOpacity(0.2),
                      size: 20,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      _userData!['bio'],
                      style: TextStyle(
                        fontSize: 15,
                        color: colors['text'],
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Icon(
                        Icons.format_quote,
                        color: colors['accent2']!.withOpacity(0.2),
                        size: 20,
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
  }

  Widget _buildInterestsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colors['white'],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.interests_rounded,
                  color: colors['secondary'],
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Interests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors['text'],
                  ),
                ),
                const Spacer(),
                if (_userTags.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors['secondary']!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_userTags.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors['secondary'],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            _userTags.isEmpty
                ? _buildEmptySection('No interests added yet')
                : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _userTags.map((tag) => _buildTagItem(tag)).toList(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagItem(String tag) {
    final Color tagColor = _getTagColor(tag);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tagColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag, size: 14, color: tagColor),
          const SizedBox(width: 6),
          Text(
            tag,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors['text'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors['white'],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group_rounded,
                  color: colors['groupColor'],
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Groups',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors['text'],
                  ),
                ),
                const Spacer(),
                if (_userGroups.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors['groupColor']!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_userGroups.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors['groupColor'],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            _userGroups.isEmpty
                ? _buildEmptySection('No groups joined yet')
                : Column(
                  children:
                      _userGroups
                          .map((group) => _buildGroupItem(group))
                          .toList(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupItem(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors['groupColor']!.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colors['groupColor']!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                group['photoURL'] != null &&
                        group['photoURL'].toString().isNotEmpty
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        group['photoURL'],
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Icon(
                              Icons.group_rounded,
                              color: colors['groupColor'],
                              size: 26,
                            ),
                      ),
                    )
                    : Icon(
                      Icons.group_rounded,
                      color: colors['groupColor'],
                      size: 26,
                    ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['name'] ?? 'Unnamed Group',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors['text'],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${group['memberCount'] ?? '?'} members',
                  style: TextStyle(fontSize: 13, color: colors['textLight']),
                ),
              ],
            ),
          ),

          if (group['role'] == 'admin')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors['groupColor']!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors['groupColor']!.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Admin',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors['groupColor'],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 24,
            color: colors['textLight']!.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: colors['textLight'],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getTagColor(String tag) {
    final List<Color> tagColors = [
      colors['primary']!,
      colors['secondary']!,
      colors['accent']!,
      colors['accent2']!,
    ];

    final int hash = tag.hashCode.abs();
    final int colorIndex = hash % tagColors.length;

    return tagColors[colorIndex];
  }

  Color _getFriendButtonColor() {
    if (_areFriends) {
      return colors['accent']!;
    } else if (_hasAlreadySentRequest) {
      return colors['secondary']!;
    } else if (_userRejectedMyRequest) {
      return Colors.grey;
    } else if (_receivedPendingRequest || _iRejectedUserRequest) {
      return colors['primary']!;
    } else {
      return colors['primary']!;
    }
  }

  List<Color> _getFriendButtonGradient() {
    if (_areFriends) {
      return [colors['accent']!, colors['accentDark']!];
    } else if (_hasAlreadySentRequest) {
      return [colors['secondary']!, colors['secondaryDark']!];
    } else if (_userRejectedMyRequest) {
      return [Colors.grey.shade500, Colors.grey.shade600];
    } else if (_receivedPendingRequest || _iRejectedUserRequest) {
      return [colors['primary']!, colors['primaryDark']!];
    } else {
      return [colors['primary']!, colors['primaryDark']!];
    }
  }

  IconData _getFriendButtonIcon() {
    if (_areFriends) {
      return Icons.check_rounded;
    } else if (_hasAlreadySentRequest) {
      return Icons.hourglass_bottom_rounded;
    } else if (_userRejectedMyRequest) {
      return Icons.block_rounded;
    } else if (_receivedPendingRequest) {
      return Icons.check_circle_rounded;
    } else if (_iRejectedUserRequest) {
      return Icons.replay_rounded;
    } else {
      return Icons.person_add_alt_rounded;
    }
  }

  String _getFriendButtonText() {
    if (_areFriends) {
      return 'Friends';
    } else if (_hasAlreadySentRequest) {
      return 'Request Sent';
    } else if (_userRejectedMyRequest) {
      return 'Not Available';
    } else if (_receivedPendingRequest) {
      return 'Accept Request';
    } else if (_iRejectedUserRequest) {
      return 'Reconsider Request';
    } else {
      return 'Send Friend Request';
    }
  }

  bool _canSendFriendRequest() {
    if (_areFriends) return false;
    if (_isSendingRequest) return false;
    if (_hasAlreadySentRequest) return false;
    if (_userRejectedMyRequest) return false;

    return true;
  }

  bool _isNotAvailable() {
    return _userRejectedMyRequest;
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.6,
      size.width * 0.5,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.8,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);
    path2.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.9,
      size.width * 0.5,
      size.height * 0.8,
    );
    path2.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.7,
      size.width,
      size.height * 0.8,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
