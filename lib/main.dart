import 'package:chatapp/services/auth/auth_gate.dart';
import 'package:chatapp/firebase_options.dart';
import 'package:chatapp/themes/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:page_transition/page_transition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SecureChat',
      home: const AuthGate(),
      theme: Provider.of<ThemeProvider>(context).themeData,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          default:
            return PageTransition(
              type: PageTransitionType.fade,
              child: const AuthGate(),
              settings: settings,
              duration: const Duration(milliseconds: 300),
            );
        }
      },
    );
  }
}
