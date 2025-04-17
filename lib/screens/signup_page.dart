import 'dart:io';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_page.dart';
import 'profile_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

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
  DateTime? _lastErrorTime;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSigningIn = false;
  bool _isSigningUp = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    if (!_isEmailSignup && _googleUserInfo != null) {
                      return ProfileSetupPage(
                        prefillName: _googleUserInfo!['displayName'],
                        prefillPhotoURL: _googleUserInfo!['photoURL'],
                      );
                    }
                    return const ProfileSetupPage();
                  },
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

  bool _isEmailSignup = false;
  Map<String, String>? _googleUserInfo;

  Future<void> _signUpWithEmail() async {
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

      _isEmailSignup = true;

      _startSignUpAnimation();
    } on FirebaseAuthException catch (e) {
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

  Future<void> _signInWithGoogle() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();

      if (gUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        _googleUserInfo = {
          'displayName': gUser.displayName ?? '',
          'photoURL': gUser.photoUrl ?? '',
          'email': gUser.email,
        };

        await _firestore.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'email': gUser.email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _isEmailSignup = false;

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

  void _signInWithGitHub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('GitHub login coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final safeAreaTop = mediaQuery.padding.top;
    final safeAreaBottom = mediaQuery.padding.bottom;
    final availableHeight = screenHeight - safeAreaTop - safeAreaBottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        height: screenHeight,
        width: screenWidth,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB6C1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0E6FA),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: availableHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
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
                        SizedBox(
                          height: availableHeight * 0.25,
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
                        const SizedBox(height: 30),
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
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E6FA),
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
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E6FA),
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
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signUpWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A3DE8),
                              disabledBackgroundColor: const Color(0xFFA391C8),
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
                              onTap: _isLoading ? null : _startSignInAnimation,
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
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
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
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.code,
                                      color: Color(0xFF333333),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
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
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.grid_view,
                                      color: Color(0xFF00A4EF),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
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
                                        color: Colors.black.withOpacity(0.1),
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
                        const SizedBox(height: 30),
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
                          color: Color(0xFFFFB6C1),
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
                          color: Color(0xFF6A3DE8),
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
