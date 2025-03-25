import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _lastErrorTime; // Track when the last error was shown
  bool _showForgotPassword = false; // Track if forgot password UI is shown

  // Animation controller for transitions
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSigningUp = false;
  bool _isLoggingIn = false;

  // Flag to track successful authentication
  bool _authSuccess = false;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controller for reset password email
  final TextEditingController _resetEmailController = TextEditingController();

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
            if (_isSigningUp) {
              // Create a page route with a transition
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          const SignupPage(),
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
            } else if (_isLoggingIn && _authSuccess) {
              // Create a page route with a smooth transition when auth is successful
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
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 500),
                ),
              );
            } else if (_isLoggingIn && !_authSuccess) {
              // Reset animation if authentication failed
              setState(() {
                _isLoggingIn = false;
              });
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
    _resetEmailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _startSignUpAnimation() {
    setState(() {
      _isSigningUp = true;
    });
    _animationController.forward(from: 0.0);
  }

  // Toggle forgot password UI
  void _toggleForgotPassword() {
    setState(() {
      _showForgotPassword = !_showForgotPassword;
      if (_showForgotPassword) {
        _resetEmailController.text =
            _emailController.text; // Pre-fill with current email
      }
    });
  }

  // Handle password reset request
  Future<void> _sendPasswordResetEmail() async {
    if (_resetEmailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      await _auth.sendPasswordResetEmail(
        email: _resetEmailController.text.trim(),
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
          backgroundColor: Color(0xFF6A3DE8),
        ),
      );

      // Close the forgot password UI
      setState(() {
        _showForgotPassword = false;
        _isLoading = false;
      });
    } catch (e) {
      String message = 'Failed to send password reset email';
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          message = 'No user found with this email address';
        } else if (e.code == 'invalid-email') {
          message = 'Please enter a valid email address';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );

      setState(() {
        _isLoading = false;
      });
    }
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

  // Login method
  Future<void> _login() async {
    // Clear any previous errors
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    // Basic validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _setErrorWithDebounce('Please enter both email and password');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Attempt to sign in with Firebase
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Authentication successful, start the animation
      setState(() {
        _authSuccess = true;
        _isLoggingIn = true;
      });
      _animationController.forward(from: 0.0);
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      if (e.code == 'user-not-found') {
        _setErrorWithDebounce('No user found with this email');
      } else if (e.code == 'wrong-password') {
        _setErrorWithDebounce('Incorrect password');
      } else if (e.code == 'invalid-email') {
        _setErrorWithDebounce('Invalid email format');
      } else if (e.code == 'user-disabled') {
        _setErrorWithDebounce('This account has been disabled');
      } else if (e.code == 'too-many-requests') {
        _setErrorWithDebounce(
          'Too many failed login attempts. Please try again later',
        );
      } else {
        _setErrorWithDebounce('Login error: ${e.message}');
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Handle other errors
      _setErrorWithDebounce('An unexpected error occurred: $e');
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
            // Background purple circle in top right
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6D8FA), // Light purple
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Background pink circle in bottom left
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD6E0), // Light pink
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

                        // LOGIN title
                        const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6A5CB5),
                            letterSpacing: 1.2,
                          ),
                        ),

                        // Login illustration - Increased height for larger image
                        SizedBox(
                          height:
                              screenHeight *
                              0.35, // Increased to 35% of screen height
                          child: Center(
                            child: Image.asset(
                              'assets/images/login2.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.laptop_mac,
                                      size: 100,
                                      color: Colors.deepPurple,
                                    ),
                                    const SizedBox(height: 20),
                                    const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Login illustration',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        // Increased spacing after image to push fields further down
                        const SizedBox(height: 80),

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

                        // Forgot password UI
                        if (_showForgotPassword) _buildForgotPasswordUI(),

                        // Main login form when not showing forgot password
                        if (!_showForgotPassword) _buildLoginForm(),

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
                ),
              ),
            ),

            // Animation circles for transitions - matching signup page style
            if (_isSigningUp)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Positioned(
                    bottom: -80,
                    left: -80,
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

            if (_isLoggingIn)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Positioned(
                    top: -80,
                    right: -80,
                    child: Transform.scale(
                      scale: _animation.value,
                      child: Container(
                        width: screenWidth,
                        height: screenWidth,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6A3DE8), // Purple circle for login
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

  // Login form UI
  Widget _buildLoginForm() {
    return Expanded(
      flex: 4,
      child: Column(
        children: [
          // Email field
          Container(
            width: double.infinity,
            height: 55,
            decoration: BoxDecoration(
              color: const Color(0xFFE6D8FA), // Light purple
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
                  padding: EdgeInsets.only(left: 15, right: 10),
                  child: Icon(Icons.person, color: Color(0xFF6A5CB5), size: 22),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 18),
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
              color: const Color(0xFFE6D8FA), // Light purple
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
                  padding: EdgeInsets.only(left: 15, right: 10),
                  child: Icon(Icons.lock, color: Color(0xFF6A5CB5), size: 22),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
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
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A3DE8), // Purple
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
                        'LOGIN',
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

          // Don't have an Account text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Don\'t have an Account? ',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              GestureDetector(
                onTap: _isLoading ? null : _startSignUpAnimation,
                child: const Text(
                  'Sign up',
                  style: TextStyle(
                    color: Color(0xFF6A3DE8),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Forgot Password button with improved UI
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _toggleForgotPassword,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF6A3DE8), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.lock_reset, size: 18, color: Color(0xFF6A3DE8)),
                    SizedBox(width: 8),
                    Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF6A3DE8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Forgot password UI
  Widget _buildForgotPasswordUI() {
    return Expanded(
      flex: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A3DE8),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _toggleForgotPassword,
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Text(
              'Enter your email address and we will send you instructions to reset your password.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 20),

            // Email field for password reset
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: TextField(
                controller: _resetEmailController,
                decoration: const InputDecoration(
                  hintText: 'Email',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.email, color: Color(0xFF6A3DE8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 18),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),

            const SizedBox(height: 20),

            // Send button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendPasswordResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A3DE8),
                  disabledBackgroundColor: const Color(0xFFA391C8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
                          'SEND RESET LINK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 15),

            // Back to login option
            TextButton.icon(
              onPressed: _toggleForgotPassword,
              icon: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Color(0xFF6A3DE8),
              ),
              label: const Text(
                'Back to Login',
                style: TextStyle(color: Color(0xFF6A3DE8), fontSize: 14),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ],
        ),
      ),
    );
  }
}
