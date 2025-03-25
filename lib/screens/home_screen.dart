import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'dashboard.dart'; // Import the dashboard

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    // Get current user email
    _userEmail = _auth.currentUser?.email;
  }

  // Method to handle sign out
  Future<void> _signOut(BuildContext context) async {
    try {
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
    ).push(MaterialPageRoute(builder: (context) => const Dashboard()));
  }

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to the App!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // Display current user email if available
            Text(
              _userEmail != null
                  ? 'Logged in as: $_userEmail'
                  : 'Not logged in',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 40),

            // Dashboard navigation button - styled to be prominent
            ElevatedButton.icon(
              onPressed: _navigateToDashboard,
              icon: const Icon(Icons.dashboard),
              label: const Text('View Pet Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFFFFC857,
                ), // Match dashboard yellow
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
          ],
        ),
      ),
      // Add a floating action button that also navigates to dashboard
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToDashboard,
        backgroundColor: const Color(0xFFFFC857),
        foregroundColor: Colors.black87,
        tooltip: 'Pet Dashboard',
        child: const Icon(Icons.pets),
      ),
    );
  }
}
