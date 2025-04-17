import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'screens/startup_page.dart';
import 'package:firebase_database/firebase_database.dart';

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
      logger.i("Firebase database test write successful");
    } catch (e) {
      logger.e("Firebase database test failed", error: e);
    }

    runApp(const MyApp());
  } catch (e) {
    logger.e("Firebase initialization failed", error: e);
    runApp(const MyApp(firebaseInitialized: false));
  }
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  final bool directToDashboard;

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
      home:
          firebaseInitialized
              ? AuthWrapper(directToDashboard: directToDashboard)
              : const StartupPage(),
    );
  }
}
