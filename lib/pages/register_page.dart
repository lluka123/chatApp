import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/components/my_button.dart";
import "package:chatapp/components/my_textfield.dart";
import "package:flutter/material.dart";

class RegisterPage extends StatelessWidget {
  // Email and Password Text controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // onTap to go to login page
  final void Function()? onTap;

  RegisterPage({super.key, required this.onTap});

  // Login Method
  void register(BuildContext context) {
    final authService = AuthService();

    if (_passwordController.text == _confirmPasswordController.text) {
      try {
        authService.signUpWithEmailPassword(
          _emailController.text,
          _passwordController.text,
        );
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(title: Text(e.toString())),
        );
      }
    } else {
      showDialog(
        context: context,
        builder:
            (context) => const AlertDialog(
              title: Padding(
                padding: EdgeInsets.all(10),
                child: Text("Passwords don't match!"),
              ),
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //logo
            Icon(
              Icons.message,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),

            const SizedBox(height: 50),

            //welcome back
            Text(
              "Let's create an account for you",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 25),

            //email textfield
            MyTextField(
              hintText: "Email",
              obscureText: false,
              controller: _emailController,
            ),

            const SizedBox(height: 10),

            //pw textfield
            MyTextField(
              hintText: "Password",
              obscureText: true,
              controller: _passwordController,
            ),

            const SizedBox(height: 10),

            //confirm pw textfield
            MyTextField(
              hintText: "Confirm Password",
              obscureText: true,
              controller: _confirmPasswordController,
            ),

            const SizedBox(height: 25),

            //login button
            MyButton(text: "Register", onTap: () => register(context)),

            const SizedBox(height: 25),

            //register button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account? ",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    "Login now",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
