import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'startup_page.dart';
import 'home_screen.dart';
import 'dashboard.dart';

// This wrapper handles authentication state and provides initial routing
class AuthWrapper extends StatelessWidget {
  final bool directToDashboard;

  // Option to directly navigate to dashboard for authenticated users
  const AuthWrapper({super.key, this.directToDashboard = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to auth state changes
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the connection state is still loading, show a loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6A3DE8), // Purple spinner to match theme
              ),
            ),
          );
        }

        // Check if user is authenticated or not
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in
          if (directToDashboard) {
            // Send directly to dashboard if requested
            return const Dashboard();
          } else {
            // Otherwise send to home screen
            return const HomeScreen();
          }
        } else {
          // User is NOT logged in - send to startup page
          return const StartupPage();
        }
      },
    );
  }
}
