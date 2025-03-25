import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'signup_page.dart';
import 'dashboard.dart';
import 'friends_groups_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userEmail;
  bool _isLoading = true;
  String? _userName;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  // Initialize user and check if they already exist in Firestore
  Future<void> _initializeUser() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        // Set email from authentication
        _userEmail = currentUser.email;

        // Check if user already exists in Firestore
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();

        if (!userDoc.exists) {
          // Check if email already exists in the system
          final QuerySnapshot existingEmailQuery =
              await _firestore
                  .collection('users')
                  .where('email', isEqualTo: currentUser.email)
                  .limit(1)
                  .get();

          if (existingEmailQuery.docs.isEmpty) {
            // User doesn't exist in Firestore yet, create their profile and dummy users
            await _createUserProfile(currentUser);
          } else {
            // Email already exists but with a different UID
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('An account with this email already exists'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } else {
          // User already exists, fetch their display name and profile image path
          final userData = userDoc.data();
          if (userData != null) {
            _userName = userData['displayName'];
            _profileImagePath = userData['photoURL'];

            // If we have a photoURL value from Firestore, check if the file exists
            if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
              print('Found profile image path: $_profileImagePath');
              final file = File(_profileImagePath!);
              if (!await file.exists()) {
                print(
                  'Profile image file does not exist at path: $_profileImagePath',
                );
                _profileImagePath = null;
              }
            }
          }
        }
      }

      // Update UI
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up user profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Get the location where profile images are stored
  Future<String> _getProfileImagesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      return '${directory.path}/profile_pics/${currentUser.uid}';
    }

    return '${directory.path}/profile_pics';
  }

  // Create a new user profile in Firestore with all required collections
  Future<void> _createUserProfile(User user) async {
    try {
      // Generate a random display name if none provided
      final displayName =
          user.displayName ??
          'User${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
      final originalUserEmail = user.email ?? 'unknown@example.com';
      final originalUserId = user.uid;

      // Batch write for better performance
      WriteBatch batch = _firestore.batch();

      // 1. Create original user document
      // The document ID matches the Authentication uid
      final originalUserRef = _firestore
          .collection('users')
          .doc(originalUserId);
      batch.set(originalUserRef, {
        'displayName': displayName,
        'email': originalUserEmail,
        'photoURL': user.photoURL ?? '', // Use empty string if no photoURL
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'settings': {'notificationsEnabled': true, 'theme': 'light'},
        // Store the auth UID in the document as well for reference
        'authId': originalUserId,
      });

      // Store the display name for UI
      _userName = displayName;

      // 2. Create dummy users (5 users)
      // NOTE: In a real app, these users would need real Firebase Authentication accounts
      // We're creating them in Firestore only for demonstration purposes
      final List<Map<String, dynamic>> dummyUsers = [];
      final List<String> dummyUserIds = [];

      // Create email base from original email
      final String emailBase = originalUserEmail.split('@')[0];
      final String emailDomain =
          originalUserEmail.contains('@')
              ? '@${originalUserEmail.split('@')[1]}'
              : '@example.com';

      // Create 5 dummy users with consistent UIDs (simulating Firebase Auth UIDs)
      // In a real app, these would be created via Firebase Authentication first
      for (int i = 1; i <= 5; i++) {
        final dummyEmail = '$emailBase$i$emailDomain';
        final dummyDisplayName = 'DummyUser$i';

        // Create a deterministic ID to simulate a Firebase Auth UID
        // In production, you would use the actual Firebase Auth UID
        // Format: "auth_" + sanitized email + fixed string to ensure consistency
        final String sanitizedEmail = dummyEmail
            .replaceAll('@', '_')
            .replaceAll('.', '_');
        final dummyUserId = 'auth_${sanitizedEmail}_dummy';
        dummyUserIds.add(dummyUserId);

        final dummyUserRef = _firestore.collection('users').doc(dummyUserId);

        batch.set(dummyUserRef, {
          'displayName': dummyDisplayName,
          'email': dummyEmail,
          'photoURL': null,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'settings': {'notificationsEnabled': true, 'theme': 'light'},
          // Store a fake authId that would match if these were real Auth users
          'authId': dummyUserId,
        });

        dummyUsers.add({
          'id': dummyUserId,
          'displayName': dummyDisplayName,
          'email': dummyEmail,
        });
      }

      // 3. Make the first 3 dummy users friends with the original user
      for (int i = 0; i < 3; i++) {
        final dummyUserId = dummyUserIds[i];
        final dummyUser = dummyUsers[i];

        // A. Add dummy user to original user's friends subcollection
        final originalUserFriendRef = originalUserRef
            .collection('friends')
            .doc(dummyUserId);
        batch.set(originalUserFriendRef, {
          'status': 'active',
          'displayName': dummyUser['displayName'],
          'photoURL': null,
          'becameFriendsAt': FieldValue.serverTimestamp(),
          'lastInteractionAt': FieldValue.serverTimestamp(),
        });

        // B. Add original user to dummy user's friends subcollection
        final dummyUserRef = _firestore.collection('users').doc(dummyUserId);
        final dummyUserFriendRef = dummyUserRef
            .collection('friends')
            .doc(originalUserId);
        batch.set(dummyUserFriendRef, {
          'status': 'active',
          'displayName': displayName,
          'photoURL': user.photoURL,
          'becameFriendsAt': FieldValue.serverTimestamp(),
          'lastInteractionAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Make the 4th dummy user send a friend request to the original user
      final fourthDummyUserId = dummyUserIds[3];
      final fourthDummyUser = dummyUsers[3];

      // A. Add request to original user's friendRequests subcollection (received)
      final originalUserFriendRequestRef =
          originalUserRef.collection('friendRequests').doc();
      batch.set(originalUserFriendRequestRef, {
        'userId': fourthDummyUserId,
        'displayName': fourthDummyUser['displayName'],
        'photoURL': null,
        'type': 'received',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // B. Add request to 4th dummy user's friendRequests subcollection (sent)
      final fourthDummyUserRef = _firestore
          .collection('users')
          .doc(fourthDummyUserId);
      final fourthDummyUserFriendRequestRef =
          fourthDummyUserRef.collection('friendRequests').doc();
      batch.set(fourthDummyUserFriendRequestRef, {
        'userId': originalUserId,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'type': 'sent',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Original user sends a friend request to the 5th dummy user
      final fifthDummyUserId = dummyUserIds[4];
      final fifthDummyUser = dummyUsers[4];

      // A. Add request to original user's friendRequests subcollection (sent)
      final originalUserSentRequestRef =
          originalUserRef.collection('friendRequests').doc();
      batch.set(originalUserSentRequestRef, {
        'userId': fifthDummyUserId,
        'displayName': fifthDummyUser['displayName'],
        'photoURL': null,
        'type': 'sent',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // B. Add request to 5th dummy user's friendRequests subcollection (received)
      final fifthDummyUserRef = _firestore
          .collection('users')
          .doc(fifthDummyUserId);
      final fifthDummyUserFriendRequestRef =
          fifthDummyUserRef.collection('friendRequests').doc();
      batch.set(fifthDummyUserFriendRequestRef, {
        'userId': originalUserId,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'type': 'received',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 6. Create "Odd" group by first dummy user
      final oddGroupRef = _firestore.collection('groups').doc('odd_group');
      batch.set(oddGroupRef, {
        'name': 'Odd Group',
        'description': 'A group for odd-numbered users',
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': dummyUserIds[0], // First dummy user
        'photoURL': null,
        'settings': {'visibility': 'private', 'joinApproval': true},
      });

      // Add members to odd group (dummy users 1, 3, 5)
      for (int i = 0; i < 5; i += 2) {
        // 0, 2, 4 indices (dummy users 1, 3, 5)
        final memberId = dummyUserIds[i];

        // Add user as member of odd group
        final oddGroupMemberRef = oddGroupRef
            .collection('members')
            .doc(memberId);
        batch.set(oddGroupMemberRef, {
          'displayName': dummyUsers[i]['displayName'],
          'photoURL': null,
          'role': i == 0 ? 'admin' : 'member', // First dummy user is admin
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActiveInGroup': FieldValue.serverTimestamp(),
        });
      }

      // 7. Create "Even" group by original user
      final evenGroupRef = _firestore.collection('groups').doc('even_group');
      batch.set(evenGroupRef, {
        'name': 'Even Group',
        'description': 'A group for even-numbered users',
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': originalUserId, // Original user
        'photoURL': null,
        'settings': {'visibility': 'private', 'joinApproval': true},
      });

      // Add members to even group (original user and dummy users 2, 4)
      // First add original user as admin
      final evenGroupOriginalMemberRef = evenGroupRef
          .collection('members')
          .doc(originalUserId);
      batch.set(evenGroupOriginalMemberRef, {
        'displayName': displayName,
        'photoURL': user.photoURL,
        'role': 'admin', // Original user is admin
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActiveInGroup': FieldValue.serverTimestamp(),
      });

      // Add dummy users 2 and 4 (indices 1 and 3)
      for (int i = 1; i < 5; i += 2) {
        // 1, 3 indices (dummy users 2, 4)
        // Skip dummy user 2 (index 1) as per requirements
        if (i == 1) continue;

        final memberId = dummyUserIds[i];

        // Add user as member of even group
        final evenGroupMemberRef = evenGroupRef
            .collection('members')
            .doc(memberId);
        batch.set(evenGroupMemberRef, {
          'displayName': dummyUsers[i]['displayName'],
          'photoURL': null,
          'role': 'member',
          'joinedAt': FieldValue.serverTimestamp(),
          'lastActiveInGroup': FieldValue.serverTimestamp(),
        });
      }

      // 8. Send group invite to dummy user 2 for Even group
      final secondDummyUserId = dummyUserIds[1]; // Dummy user 2

      // A. Add to dummy user 2's groupInvites subcollection
      final secondDummyUserRef = _firestore
          .collection('users')
          .doc(secondDummyUserId);
      final secondDummyUserGroupInviteRef =
          secondDummyUserRef.collection('groupInvites').doc();
      batch.set(secondDummyUserGroupInviteRef, {
        'groupId': 'even_group',
        'groupName': 'Even Group',
        'invitedBy': originalUserId,
        'inviterName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // B. Add to Even group's pendingInvites subcollection
      final evenGroupPendingInviteRef = evenGroupRef
          .collection('pendingInvites')
          .doc(secondDummyUserId);
      batch.set(evenGroupPendingInviteRef, {
        'displayName': dummyUsers[1]['displayName'],
        'invitedBy': originalUserId,
        'invitedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Commit the batch
      await batch.commit();

      print('User profile and dummy data created successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'User profile created with dummy friends and groups!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating user profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to handle sign out
  Future<void> _signOut(BuildContext context) async {
    try {
      // Update lastActive timestamp before signing out
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully signed out'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to signup page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignupPage()),
      );
    } catch (e) {
      // Show error message if sign out fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Navigate to dashboard
  void _navigateToDashboard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const FriendsGroupsPage()));
  }

  // Create a document in Firestore
  Future<void> _uploadSampleDocument() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Create a sample document for the user
      final docRef = await _firestore.collection('documents').add({
        'title': 'Sample Study Material',
        'ownerId': currentUser.uid,
        'fileURL': 'https://example.com/sample.pdf',
        'mimeType': 'application/pdf',
        'size': 1024 * 1024, // 1MB
        'uploadedAt': FieldValue.serverTimestamp(),
        'description': 'This is a sample document for demonstration',
        'tags': ['sample', 'math', 'tutorial'],
      });

      // Use the document to create a sample assessment
      await _firestore
          .collection('assessments')
          .add({
            'title': 'Sample Quiz - Introduction',
            'creatorId': currentUser.uid,
            'sourceDocumentId': docRef.id,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'description': 'A sample quiz generated from your document',
            'difficulty': 'medium',
            'estimatedDuration': 15, // minutes
            'isPublic': false,
            'sharedWithUserIds': [],
            'sharedWithGroupIds': [],
            'totalPoints': 20,
          })
          .then((assessmentRef) async {
            // Add sample questions to the assessment
            await assessmentRef.collection('questions').add({
              'questionType': 'multiple-choice',
              'questionText': 'What is the main topic of this document?',
              'options': [
                'Mathematics',
                'Physics',
                'Computer Science',
                'Biology',
              ],
              'points': 5,
              'position': 1,
            });

            await assessmentRef.collection('questions').add({
              'questionType': 'short-answer',
              'questionText':
                  'Explain the concept of variables in your own words.',
              'points': 10,
              'position': 2,
            });

            // Add sample answers to the assessment
            await assessmentRef.collection('answers').add({
              'questionId':
                  '1', // This would normally reference the actual question ID
              'answerType': 'multiple-choice',
              'answerText': 'Mathematics',
              'aiEvaluationCriteria': {'exactMatch': true},
            });

            await assessmentRef.collection('answers').add({
              'questionId':
                  '2', // This would normally reference the actual question ID
              'answerType': 'short-answer',
              'answerText':
                  'A variable is a container that stores a value which can be changed during program execution.',
              'aiEvaluationCriteria': {
                'keyTerms': ['container', 'stores', 'value', 'changed'],
                'semanticSimilarityThreshold': 0.7,
              },
            });
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample document and assessment created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating sample content: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating sample content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show profile image storage information
  Future<void> _showProfileImageInfo() async {
    if (_profileImagePath == null || _profileImagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No profile image found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final dirPath = await _getProfileImagesDirectory();

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Profile Image Information'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Image is stored at:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      _profileImagePath!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Directory for all profile images:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      dirPath,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting profile image info: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: const Color(0xFF6A3DE8),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: const Color(0xFF6A3DE8),
        actions: [
          // Sign Out Button in AppBar
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Profile picture section
              Center(
                child: Column(
                  children: [
                    // Profile image with border
                    GestureDetector(
                      onTap: _showProfileImageInfo,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6A3DE8),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child:
                              _profileImagePath != null &&
                                      _profileImagePath!.isNotEmpty
                                  ? Image.file(
                                    File(_profileImagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print(
                                        'Error loading profile image: $error',
                                      );
                                      return Container(
                                        color: const Color(0xFFF0E6FA),
                                        child: const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Color(0xFF6A3DE8),
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    color: const Color(0xFFF0E6FA),
                                    child: const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Color(0xFF6A3DE8),
                                    ),
                                  ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Username display
                    if (_userName != null)
                      Text(
                        _userName!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6A3DE8),
                        ),
                      ),

                    const SizedBox(height: 6),

                    // Email display
                    if (_userEmail != null)
                      Text(
                        _userEmail!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Profile image info button
                    if (_profileImagePath != null &&
                        _profileImagePath!.isNotEmpty)
                      TextButton.icon(
                        onPressed: _showProfileImageInfo,
                        icon: const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFF6A3DE8),
                        ),
                        label: const Text(
                          'View Image Info',
                          style: TextStyle(
                            color: Color(0xFF6A3DE8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Divider(),

              const SizedBox(height: 24),

              const Text(
                'Welcome to Grade Genie!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Dashboard navigation button
              ElevatedButton.icon(
                onPressed: _navigateToDashboard,
                icon: const Icon(Icons.dashboard),
                label: const Text('View Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC857),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),

              const SizedBox(height: 20),

              // Create Sample Document Button
              ElevatedButton.icon(
                onPressed: _uploadSampleDocument,
                icon: const Icon(Icons.upload_file),
                label: const Text('Create Sample Document & Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Back to signup button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const SignupPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A3DE8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Back to Sign Up'),
              ),

              const SizedBox(height: 20),
              // Sign Out Button
              ElevatedButton(
                onPressed: () => _signOut(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Sign Out'),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      // Add a floating action button that also navigates to dashboard
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToDashboard,
        backgroundColor: const Color(0xFFFFC857),
        foregroundColor: Colors.black87,
        tooltip: 'Dashboard',
        child: const Icon(Icons.school),
      ),
    );
  }
}
