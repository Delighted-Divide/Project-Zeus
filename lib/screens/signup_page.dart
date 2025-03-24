import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/social_button.dart';
import 'home_screen.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firestore instance for user data
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Animation controller for circle animations
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSigningIn = false;
  bool _isSigningUp = false;

  // Flag to track if authentication was successful
  bool _authSuccess = false;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller with longer duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Increase the animation values to ensure full screen coverage
    _animation = Tween<double>(begin: 0, end: 30).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen for animation completion
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Wait a moment before navigating to ensure animation completes visually
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            if (_isSigningIn) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            } else if (_isSigningUp && _authSuccess) {
              // Only navigate to home screen if authentication was successful
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else if (_isSigningUp && !_authSuccess) {
              // Reset the animation if authentication failed
              setState(() {
                _isSigningUp = false;
              });
              // No navigation happens if authentication failed
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startSignInAnimation() {
    setState(() {
      _isSigningIn = true;
    });
    _animationController.forward(from: 0.0);
  }

  // Method to handle signup process
  void _handleSignUp() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      // If validation fails, show error and don't proceed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check your inputs and try again'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set loading state before attempting authentication
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Attempt authentication BEFORE starting the animation
    bool authResult = await _signUp();

    // Only start the animation if authentication was successful
    if (authResult) {
      setState(() {
        _authSuccess = true;
        _isSigningUp = true;
      });
      _animationController.forward(from: 0.0);
    } else {
      // If authentication failed, reset loading state
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Firebase signup method - returns success or failure
  Future<bool> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Email and password cannot be empty";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
      return false;
    }

    try {
      // Create user with email and password
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Save additional user data to Firestore
      await _saveUserData(userCredential.user!.uid);

      // Authentication succeeded
      return true;
    } on FirebaseAuthException catch (e) {
      // Handle different Firebase Auth errors
      if (e.code == 'weak-password') {
        _errorMessage = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        _errorMessage = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = 'The email address is not valid.';
      } else {
        _errorMessage = 'An error occurred: ${e.message}';
      }

      // Show error in snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );

      // Authentication failed
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';

      // Show generic error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );

      // Authentication failed
      return false;
    }
  }

  // Method to save user data to Firestore
  Future<void> _saveUserData(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'email': _emailController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  // Method to handle social signins
  Future<void> _signInWithSocial(String provider) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      UserCredential? userCredential;

      // Handle different social providers
      if (provider == 'google') {
        // Sign in with Google
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else if (provider == 'facebook') {
        // Sign in with Facebook
        final FacebookAuthProvider facebookProvider = FacebookAuthProvider();
        userCredential = await _auth.signInWithPopup(facebookProvider);
      } else {
        // For other providers, show not implemented message
        setState(() {
          _isLoading = false;
          _errorMessage = '$provider sign-in not implemented yet.';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
        return;
      }

      // Save user data if login was successful
      if (userCredential.user != null) {
        await _saveUserData(userCredential.user!.uid);

        // Set success flag and start animation
        setState(() {
          _authSuccess = true;
          _isSigningUp = true;
        });
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Social login failed: ${e.toString()}';
      });

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen dimensions
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: screenHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Status bar placeholder
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 40,
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '10:16',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.network_cell,
                              color: Colors.grey[700],
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.battery_full,
                              color: Colors.grey[700],
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Pink circle in the top-left corner
                Positioned(
                  top: -80,
                  left: -80,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB6C1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Purple circle in the bottom-right corner
                Positioned(
                  bottom: -80,
                  right: -80,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0E6FA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Camera dot at the top
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                    ),
                  ),
                ),

                // Main content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          // SIGNUP title
                          const Text(
                            'SIGNUP',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          // Error message if any
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Image - using the Stack alternative approach
                          Expanded(
                            child: Center(
                              child: SizedBox(
                                width: screenWidth * 0.8, // 80% of screen width
                                height:
                                    screenHeight * 0.3, // 30% of screen height
                                child: Image.asset(
                                  'assets/images/signup.png',
                                  fit: BoxFit.contain,
                                  // If image still doesn't load, add error builder
                                  errorBuilder: (context, error, stackTrace) {
                                    return Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.image,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Image not available',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          // Email Field
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0E6FA),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                hintText: 'Email',
                                hintStyle: TextStyle(color: Colors.grey),
                                prefixIcon: Padding(
                                  padding: EdgeInsets.only(left: 15, right: 10),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.deepPurple,
                                    size: 24,
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                errorStyle: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0E6FA),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscureText,
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: const TextStyle(color: Colors.grey),
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(left: 15, right: 10),
                                  child: Icon(
                                    Icons.lock,
                                    color: Colors.deepPurple,
                                    size: 24,
                                  ),
                                ),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 15),
                                  child: IconButton(
                                    icon: Icon(
                                      _obscureText
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey,
                                      size: 24,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureText = !_obscureText;
                                      });
                                    },
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                errorStyle: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                              enabled: !_isLoading,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Signup Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF6A3DE8,
                              ), // Brighter purple
                              disabledBackgroundColor: Colors.grey,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      'SIGNUP',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 18),

                          // Already have an account text
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an Account? ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap:
                                    _isLoading ? null : _startSignInAnimation,
                                child: const Text(
                                  'Sign in',
                                  style: TextStyle(
                                    color: Color(
                                      0xFF6A3DE8,
                                    ), // Matching button color
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // OR with lines
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'OR',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // Social media buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SocialButton(
                                icon: Icons.facebook,
                                color: Colors.blue,
                                onTap:
                                    _isLoading
                                        ? null
                                        : () => _signInWithSocial('facebook'),
                                size: 30,
                              ),
                              const SizedBox(width: 30),
                              SocialButton(
                                icon: Icons.chat_bubble,
                                color: Colors.blue.shade300,
                                onTap:
                                    _isLoading
                                        ? null
                                        : () {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Twitter/X sign-in not implemented yet',
                                              ),
                                            ),
                                          );
                                        },
                                size: 30,
                              ),
                              const SizedBox(width: 30),
                              GestureDetector(
                                onTap:
                                    _isLoading
                                        ? null
                                        : () => _signInWithSocial('google'),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  child: const Center(
                                    child: Text(
                                      "G",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 70),
                        ],
                      ),
                    ),
                  ),
                ),

                // Home indicator line at bottom
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Red circle for sign in transition animation (improved positioning and size)
          if (_isSigningIn)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  top: -80,
                  left: -80,
                  child: Transform.scale(
                    scale: _animation.value,
                    child: Container(
                      width: screenWidth,
                      height:
                          screenWidth, // Using width to make a perfect circle
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB6C1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),

          // Purple circle for sign up transition animation (improved positioning and size)
          if (_isSigningUp)
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
                      height:
                          screenWidth, // Using width to make a perfect circle
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(
                          255,
                          106,
                          61,
                          232,
                        ), // Use the button color for consistency
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
