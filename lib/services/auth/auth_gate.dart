import "package:chatapp/services/auth/login_or_register.dart";
import "package:chatapp/pages/home_page.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // User is logged in
            return const HomePage(); // <-- DODAN const
          } else {
            // User is NOT logged in
            return const LoginOrRegister();
          }
        },
      ),
    );
  }
}
