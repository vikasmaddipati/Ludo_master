import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'views/login_screen.dart';
import 'views/username_setup_screen.dart';
import 'views/home_screen.dart';
import 'services/accessibility_service.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Firebase initialization skipped/failed: $e");
  }

  // Pre-load dynamic API Server URLs
  try {
    await ApiService.initBaseUrl();
  } catch (e) {
    print("ApiService base URL load failed: $e");
  }

  // Pre-load accessibility user preferences from SharedPreferences
  try {
    await AccessibilityService.instance.initialize();
  } catch (e) {
    print("AccessibilityService pre-load skipped/failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ludo Master',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0F0B26),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/username_setup': (context) => const UsernameSetupScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}