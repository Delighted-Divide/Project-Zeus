import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'signup_page.dart';
import 'friends_groups_page.dart';
import 'dummy_data_generator.dart'; // Import our new dummy data generator

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
  bool _isGeneratingDummyData = false; // Track dummy data generation progress

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
            // User doesn't exist in Firestore yet
            // We'll let them use the Generate Dummy Data button to set up data
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Welcome! Use the Generate Dummy Data button to set up your account.',
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
            }
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

  // Generate dummy data for all collections
  Future<void> _generateDummyData() async {
    if (_isGeneratingDummyData) {
      return; // Don't allow multiple simultaneous generations
    }

    setState(() {
      _isGeneratingDummyData = true;
    });

    try {
      // Use the DummyDataGenerator to create all dummy data
      final generator = DummyDataGenerator(context);
      await generator.generateAllDummyData();

      // Refresh user data after generation
      await _initializeUser();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dummy data generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error generating dummy data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating dummy data: $e'),
            backgroundColor: Colors.red,
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

              const SizedBox(height: 24),

              // Generate Dummy Data Button (NEW)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingDummyData ? null : _generateDummyData,
                  icon:
                      _isGeneratingDummyData
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Icon(Icons.data_usage),
                  label: Text(
                    _isGeneratingDummyData
                        ? 'Generating Data...'
                        : 'Generate Dummy Data',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50), // Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),

              // Help text for dummy data generation
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Text(
                  'The button above will generate dummy data for all collections in the database, '
                  'including users, groups, assessments, and tags. It will create the proper '
                  'relationships between entities and ensure consistent data across collections.',
                  style: TextStyle(fontSize: 14, color: Colors.blue),
                  textAlign: TextAlign.center,
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
