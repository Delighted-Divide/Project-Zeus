import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'home_screen.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _lastErrorTime;
  bool _isCompleting = false;

  // Animation controller for transitions
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(begin: 0, end: 30).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _isCompleting) {
            // Navigate to home screen
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const HomeScreen(),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Prevent error message spam by checking the time since last error
  void _setErrorWithDebounce(String message) {
    final now = DateTime.now();
    if (_lastErrorTime == null ||
        now.difference(_lastErrorTime!).inSeconds >= 2) {
      setState(() {
        _errorMessage = message;
        _lastErrorTime = now;
      });
    }
  }

  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _setErrorWithDebounce('Error selecting image: $e');
    }
  }

  // Show image source selection dialog
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Save image to local app directory with the desired structure
  Future<String> _saveProfileImage(File imageFile, String userId) async {
    try {
      // Get application documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();

      // Create the structure: profile_pics/user_id
      final Directory profilePicsDir = Directory(
        '${appDocDir.path}/profile_pics/$userId',
      );
      if (!await profilePicsDir.exists()) {
        await profilePicsDir.create(recursive: true);
      }

      // Generate file name with original extension
      final String fileName = 'profile${path.extension(imageFile.path)}';
      final String localPath = '${profilePicsDir.path}/$fileName';

      // Copy the file to the new location
      await imageFile.copy(localPath);

      print('Image saved at: $localPath');
      return localPath;
    } catch (e) {
      print('Error saving image: $e');
      throw Exception('Failed to save profile image: $e');
    }
  }

  // Complete profile setup
  Future<void> _completeProfileSetup() async {
    // If already loading, don't allow another request
    if (_isLoading) {
      return;
    }

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    // Validate input
    if (_nameController.text.isEmpty) {
      _setErrorWithDebounce('Please enter your name');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get current user
      final User? user = _auth.currentUser;
      if (user == null) {
        _setErrorWithDebounce('User not found. Please sign in again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Prepare user data
      String? photoURL;

      // Save image if selected
      if (_selectedImage != null) {
        try {
          photoURL = await _saveProfileImage(_selectedImage!, user.uid);
        } catch (e) {
          _setErrorWithDebounce('Failed to save profile image: $e');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Set up user data in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'userId': user.uid,
        'displayName': _nameController.text.trim(),
        'email': user.email,
        'photoURL': photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'settings': {'notificationsEnabled': true, 'theme': 'light'},
      });

      // Update user profile in Firebase Auth
      await user.updateDisplayName(_nameController.text.trim());

      // Start animation and navigate to home screen
      setState(() {
        _isCompleting = true;
        _isLoading = false;
      });
      _animationController.forward(from: 0.0);
    } catch (e) {
      _setErrorWithDebounce('An error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        height: screenHeight,
        width: screenWidth,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Status bar placeholder
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 40, color: Colors.transparent),
            ),

            // Background purple circle in top left
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB6C1), // Light pink
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Background purple circle in bottom right
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0E6FA), // Light purple
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: SingleChildScrollView(
                child: SizedBox(
                  height:
                      screenHeight -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),

                        // Profile Setup title
                        const Text(
                          'COMPLETE YOUR PROFILE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6A5CB5),
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Profile picture selection
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF0E6FA),
                              border: Border.all(
                                color: const Color(0xFF6A3DE8),
                                width: 2,
                              ),
                              image:
                                  _selectedImage != null
                                      ? DecorationImage(
                                        image: FileImage(_selectedImage!),
                                        fit: BoxFit.cover,
                                      )
                                      : null,
                            ),
                            child:
                                _selectedImage == null
                                    ? const Icon(
                                      Icons.add_a_photo,
                                      size: 40,
                                      color: Color(0xFF6A3DE8),
                                    )
                                    : null,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Add photo text
                        Text(
                          _selectedImage == null
                              ? 'Add Profile Photo'
                              : 'Change Photo',
                          style: const TextStyle(
                            color: Color(0xFF6A3DE8),
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Error message
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Form fields and buttons - in an Expanded to take remaining space
                        Expanded(
                          child: Column(
                            children: [
                              // Name field
                              Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF0E6FA,
                                  ), // Light purple
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    hintText: 'Full Name',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFA391C8),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: Padding(
                                      padding: EdgeInsets.only(
                                        left: 15,
                                        right: 10,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Color(0xFF6A5CB5),
                                        size: 22,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Complete button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _completeProfileSetup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFF6A3DE8,
                                    ), // Bright purple
                                    disabledBackgroundColor: const Color(
                                      0xFFA391C8,
                                    ), // Lighter purple when disabled
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Text(
                                            'COMPLETE SETUP',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                ),
                              ),

                              const Spacer(), // Push the home indicator to the bottom
                              // Bottom home indicator
                              Container(
                                width: 80,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Animation circle for transition
            if (_isCompleting)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Positioned(
                    bottom: -80,
                    right: -80,
                    child: Transform.scale(
                      scale: _animation.value,
                      child: Container(
                        width: screenWidth,
                        height: screenWidth,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6A3DE8), // Purple circle
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
