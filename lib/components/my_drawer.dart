// lib/components/my_drawer.dart
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/pages/settings_page.dart";
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and menu items
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.message,
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "SecureChat",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "End-to-End Encrypted",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8 * 255.0),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Home List Tile
              ListTile(
                title: const Text(
                  "Home",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                leading: Icon(
                  Icons.home,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              // Setting List Tile
              ListTile(
                title: const Text(
                  "Settings",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                leading: Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
              
              const Divider(),
            ],
          ),

          // Logout Tile
          Padding(
            padding: const EdgeInsets.only(bottom: 25.0),
            child: ListTile(
              title: const Text(
                "Logout",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: const Icon(
                Icons.logout,
                color: Colors.red,
              ),
              onTap: logout,
            ),
          ),
        ],
      ),
    );
  }
}
