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
                padding: EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.message,
                        color: Colors.white,
                        size: 60,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "SecureChat",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        "End-to-End Encrypted",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Home List Tile
              ListTile(
                title: Text(
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
                title: Text(
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
              
              Divider(),
            ],
          ),

          // Logout Tile
          Padding(
            padding: const EdgeInsets.only(bottom: 25.0),
            child: ListTile(
              title: Text(
                "Logout",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              leading: Icon(
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
