import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _lastErrorTime; // Track when the last error was shown

  // Animation controller for transitions
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSigningIn = false;
  bool _isSigningUp = false;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
          if (mounted) {
            if (_isSigningUp && _errorMessage.isEmpty) {
              // Create a page route with a transition
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
            } else if (_isSigningIn) {
              // Create a page route with a transition
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          const LoginPage(),
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

  // Prevent error message spam by checking the time since last error
  void _setErrorWithDebounce(String message) {
    final now = DateTime.now();
    // Only show a new error if none exists or if the last error was shown more than 2 seconds ago
    if (_lastErrorTime == null ||
        now.difference(_lastErrorTime!).inSeconds >= 2) {
      setState(() {
        _errorMessage = message;
        _lastErrorTime = now;
      });
    }
  }

  Future<void> _signUpWithEmail() async {
    // If already loading, don't allow another request
    if (_isLoading) {
      return;
    }

    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    if (_emailController.text.isEmpty) {
      _setErrorWithDebounce('Please enter an email address');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      _setErrorWithDebounce('Please enter a password');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      _setErrorWithDebounce('Password must be at least 6 characters');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      _startSignUpAnimation();
    } on FirebaseAuthException catch (e) {
      // Use debounce function for errors
      if (e.code == 'weak-password') {
        _setErrorWithDebounce('The password provided is too weak');
      } else if (e.code == 'email-already-in-use') {
        _setErrorWithDebounce('An account already exists for that email');
      } else if (e.code == 'invalid-email') {
        _setErrorWithDebounce('Please enter a valid email address');
      } else {
        _setErrorWithDebounce('Error: ${e.message}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _setErrorWithDebounce('An error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Proper Google Sign In implementation
  Future<void> _signInWithGoogle() async {
    // If already loading, don't allow another request
    if (_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      // Begin interactive sign in process
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();

      // If the user canceled the sign-in flow, return early
      if (gUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Obtain auth details from Google
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      // Sign in with credential
      await _auth.signInWithCredential(credential);

      // Start animation for successful sign in
      _startSignUpAnimation();
    } on FirebaseAuthException catch (e) {
      _setErrorWithDebounce('Firebase error: ${e.message}');
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _setErrorWithDebounce('Error signing in with Google: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // GitHub sign in method (placeholder)
  void _signInWithGitHub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GitHub login coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Microsoft sign in method (placeholder)
  void _signInWithMicrosoft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Microsoft login coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startSignUpAnimation() {
    setState(() {
      _isSigningUp = true;
      _isLoading = false;
    });
    _animationController.forward(from: 0.0);
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

                        // SIGNUP title
                        const Text(
                          'SIGNUP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6A5CB5),
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Signup illustration - making it larger
                        SizedBox(
                          height:
                              screenHeight * 0.28, // About 28% of screen height
                          child: Center(
                            child: Image.asset(
                              'assets/images/signup2.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.image_not_supported,
                                      size: 100,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        // More space after image - increased
                        const SizedBox(height: 60),

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

                        // Form fields and buttons - now in an Expanded to take remaining space
                        Expanded(
                          child: Column(
                            children: [
                              // Email field
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
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    hintText: 'Email',
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
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Password field
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
                                  controller: _passwordController,
                                  obscureText: _obscureText,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFFA391C8),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 15,
                                        right: 10,
                                      ),
                                      child: Icon(
                                        Icons.lock,
                                        color: Color(0xFF6A5CB5),
                                        size: 22,
                                      ),
                                    ),
                                    suffixIcon: Padding(
                                      padding: const EdgeInsets.only(right: 15),
                                      child: IconButton(
                                        icon: Icon(
                                          _obscureText
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: const Color(0xFFA391C8),
                                          size: 22,
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
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Signup button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _signUpWithEmail,
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
                                            'SIGNUP',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Already have an Account text
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
                                        _isLoading
                                            ? null
                                            : _startSignInAnimation,
                                    child: const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        color: Color(0xFF6A3DE8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // OR divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey[300],
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
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

                              const SizedBox(height: 20),

                              // Social media buttons row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // GitHub button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _signInWithGitHub,
                                      borderRadius: BorderRadius.circular(25),
                                      splashColor: Colors.grey.withOpacity(0.1),
                                      child: Ink(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.code,
                                            color: Color(
                                              0xFF333333,
                                            ), // GitHub dark color
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 20),

                                  // Microsoft button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _signInWithMicrosoft,
                                      borderRadius: BorderRadius.circular(25),
                                      splashColor: Colors.grey.withOpacity(0.1),
                                      child: Ink(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.grid_view,
                                            color: Color(
                                              0xFF00A4EF,
                                            ), // Microsoft blue
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 20),

                                  // Google button with Material for better touch response
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _signInWithGoogle,
                                      borderRadius: BorderRadius.circular(25),
                                      splashColor: Colors.grey.withOpacity(0.1),
                                      child: Ink(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            'G',
                                            style: TextStyle(
                                              color: Colors.red[500],
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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

            // Animation circles for transitions - matching login page style
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
                        height: screenWidth,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB6C1), // Red circle for sign in
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                },
              ),

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
                        height: screenWidth,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6A3DE8), // Purple circle for sign up
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
