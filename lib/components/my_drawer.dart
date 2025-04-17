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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "End-to-End Encrypted",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9 * 255.0),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Home List Tile
              _buildDrawerItem(
                context,
                title: "Home",
                icon: Icons.home,
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              // Setting List Tile
              _buildDrawerItem(
                context,
                title: "Settings",
                icon: Icons.settings,
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
            child: _buildDrawerItem(
              context,
              title: "Logout",
              icon: Icons.logout,
              isLogout: true,
              onTap: logout,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawerItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isLogout ? Colors.red : null,
        ),
      ),
      leading: Icon(
        icon,
        color: isLogout ? Colors.red : Theme.of(context).colorScheme.primary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      dense: true,
    );
  }
}
