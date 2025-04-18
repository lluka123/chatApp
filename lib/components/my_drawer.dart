// lib/components/my_drawer.dart
import "package:chatapp/services/auth/auth_service.dart";
import "package:flutter/material.dart";

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void logout() {
    final authService = AuthService();
    authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Logo and app name
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
              ),
              child: Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Cryptiq",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Spacer to push logout to bottom
            const Spacer(),
            
            // Logout option
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                title: const Text(
                  "Logout",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                onTap: logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
