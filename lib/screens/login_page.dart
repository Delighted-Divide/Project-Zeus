import 'package:flutter/material.dart';
import './signup_page.dart';
import './home_screen.dart';

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

  // Animation controller for circle animations
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSigningUp = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Animation for the circle expansion
    _animation = Tween<double>(begin: 0, end: 30).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen for animation completion
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Wait a moment before navigating to ensure animation completes visually
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            if (_isSigningUp) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const SignupPage()),
              );
            } else if (_isLoggingIn) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
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

  void _startSignUpAnimation() {
    setState(() {
      _isSigningUp = true;
    });
    _animationController.forward(from: 0.0);
  }

  // Replace the _login() method with this:
  void _login() {
    // Start animation first
    setState(() {
      _isLoggingIn = true;
    });
    _animationController.forward(from: 0.0);
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

                // Purple circle in the top-right corner
                Positioned(
                  top: -80,
                  right: -80,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6D8FA), // Light purple
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Pink circle in the bottom-left corner
                Positioned(
                  bottom: -80,
                  left: -80,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD6E0), // Light pink
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        // LOGIN title
                        const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Image section
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: screenWidth * 0.8, // 80% of screen width
                              height:
                                  screenHeight * 0.3, // 30% of screen height
                              child: Image.asset(
                                'assets/images/login.png',
                                fit: BoxFit.contain,
                                // If image doesn't load, show placeholder
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Use a person with laptop icon similar to the provided image
                                      Icon(
                                        Icons.laptop_mac,
                                        size: 80,
                                        color: Colors.deepPurple,
                                      ),
                                      const SizedBox(height: 20),
                                      Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Login illustration',
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
                            color: const Color(
                              0xFFE6D8FA,
                            ), // Light purple background
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
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
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE6D8FA,
                            ), // Light purple background
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF6A3DE8,
                            ), // Deep purple
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Don't have an account text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Don\'t have an Account? ',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: _startSignUpAnimation,
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFF6A3DE8), // Deep purple
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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

          // Purple circle for sign up transition animation
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
                      height:
                          screenWidth, // Using width to make a perfect circle
                      decoration: const BoxDecoration(
                        color: Color(0xFF6A3DE8), // Deep purple
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
                        color: Color(0xFF6A3DE8), // Deep purple
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
