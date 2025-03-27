import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'startup_page.dart';
import 'home_screen.dart';
import 'dashboard.dart';

class AuthWrapper extends StatelessWidget {
  final bool directToDashboard;

  // Option to directly navigate to dashboard for authenticated users
  AuthWrapper({super.key, this.directToDashboard = false});

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
          // No need to set current user ID for chat service anymore
          // Since we're now using Firebase Auth directly

          // Now proceed with navigation
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
