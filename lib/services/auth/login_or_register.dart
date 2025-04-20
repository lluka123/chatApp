import "package:chatapp/pages/login_page.dart";
import "package:chatapp/pages/register_page.dart";
import "package:flutter/material.dart";

class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  // Na začetku prikaži stran za prijavo
  bool showLoginPage = true;

  // Preklop za menjavo med stranmi za prijavo in registracijo
  void togglePage() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginPage(onTap: togglePage);
    } else {
      return RegisterPage(onTap: togglePage);
    }
  }
}
