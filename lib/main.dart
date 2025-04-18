// lib/main.dart
import 'package:chatapp/services/auth/auth_gate.dart';
import 'package:chatapp/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cryptiq',
      home: const AuthGate(),
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E88E5),
          onPrimary: Colors.white,
          secondary: Color(0xFFE3F2FD),
          tertiary: Color(0xFFBBDEFB),
          surface: Colors.white,
          error: Colors.redAccent,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E88E5),
          iconTheme: IconThemeData(color: Color(0xFF1E88E5)),
        ),
      ),
    );
  }
}