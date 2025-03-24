import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login/Signup Pages',
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Roboto'),
      // You can choose which page to show initially
      // home: const LoginPage(), // Use this to start with Login
      home: const SignupPage(), // Use this to start with Signup
    );
  }
}

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

  // Animation controller for circle animations
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isSigningIn = false;
  bool _isSigningUp = false;

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
            if (_isSigningUp) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else if (_isSigningIn) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
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

  void _startSignUpAnimation() {
    // For testing purposes, allow signup without validation
    // In production, uncomment the validation check
    /*
    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      setState(() {
        _isSigningUp = true;
      });
      _animationController.forward(from: 0.0);
    }
    */

    // For testing:
    setState(() {
      _isSigningUp = true;
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                            color: const Color(0xFFF0E6FA),
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

                        // Signup Button
                        ElevatedButton(
                          onPressed: _startSignUpAnimation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF6A3DE8,
                            ), // Brighter purple
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
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
                              onTap: _startSignInAnimation,
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
                              onTap: () {},
                              size: 30,
                            ),
                            const SizedBox(width: 30),
                            SocialButton(
                              icon: Icons.chat_bubble,
                              color: Colors.blue.shade300,
                              onTap: () {},
                              size: 30,
                            ),
                            const SizedBox(width: 30),
                            Container(
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

class SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const SocialButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Icon(icon, color: color, size: size),
    );
  }
}

// Temporary home screen for navigation after animation
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: const Color(0xFF6A3DE8),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to the App!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const SignupPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A3DE8),
              ),
              child: const Text('Back to Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
