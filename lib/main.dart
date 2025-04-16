import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'screens/startup_page.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://attempt1-314eb-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      final ref = db.ref("test");
      await ref.set({"test": true, "timestamp": DateTime.now().toString()});
      print("Firebase database test write successful");
    } catch (e) {
      print("Firebase database test failed: $e");
    }

    // Run the app
    runApp(const MyApp());
  } catch (e) {
    // Run app without Firebase (will show startup page)
    runApp(const MyApp(firebaseInitialized: false));
  }
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  final bool directToDashboard;

  // Constructor with optional parameters
  const MyApp({
    super.key,
    this.firebaseInitialized = true,
    this.directToDashboard = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Grade Genie',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      // Use the appropriate home widget based on Firebase initialization status
      home:
          firebaseInitialized
              ? AuthWrapper(directToDashboard: directToDashboard)
              : const StartupPage(),
    );
  }
}

// You can enable direct-to-dashboard mode by running:
// runApp(const MyApp(directToDashboard: true));
