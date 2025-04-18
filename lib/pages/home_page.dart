// lib/pages/home_page.dart
import "package:chatapp/pages/chat_page.dart";
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Services
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  
  // Loading state
  bool _isLoading = true;
  
  // For demonstration, we'll hardcode some users with unread messages
  // In a real app, you would track this in your database
  final List<String> _usersWithUnreadMessages = ['user123', 'user456'];
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
    
    // For demonstration purposes, let's add a timer to simulate a new message
    // after 5 seconds to test the notification
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          // Add a random user ID to the unread messages list
          _usersWithUnreadMessages.add('randomUser789');
        });
        // Vibrate the phone
        HapticFeedback.vibrate();
      }
    });
  }
  
  Future<void> _initializeApp() async {
    await _chatService.initializeEncryption();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Logout function
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _authService.signOut();
            },
            child: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Cryptiq",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF1E88E5),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Color(0xFF1E88E5)),
          onPressed: _logout,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _buildUserList(),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatService.getUsersStreamExceptBlocked(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text("Error loading users"),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        final users = snapshot.data!;
        
        if (users.isEmpty) {
          return const Center(
            child: Text("No users available"),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index];
            if (userData["email"] != _authService.getCurrentUser()!.email) {
              // For demonstration, we'll mark some users as having unread messages
              // In a real app, you would check your database
              bool hasUnreadMessages = index % 3 == 0; // Every third user has unread messages
              
              return _buildUserTile(userData, hasUnreadMessages);
            } else {
              return Container();
            }
          },
        );
      },
    );
  }
  
  Widget _buildUserTile(Map<String, dynamic> userData, bool hasUnreadMessages) {
    // Get first letter of email for avatar
    String firstLetter = userData["email"][0].toUpperCase();
    
    // Determine avatar color based on first letter
    Color avatarColor;
    if (firstLetter == 'J') {
      avatarColor = Colors.blue;
    } else if (firstLetter == 'M') {
      avatarColor = Colors.purple;
    } else if (firstLetter == 'L') {
      avatarColor = Colors.green;
    } else {
      avatarColor = Colors.blue;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: avatarColor,
              radius: 20,
              child: Text(
                firstLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Show a notification dot if there are unread messages
            if (hasUnreadMessages)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          userData["email"],
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 12,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 4),
            Text(
              "Tap to start secure chat",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () {
          // Vibrate when tapping on a chat with unread messages
          if (hasUnreadMessages) {
            HapticFeedback.mediumImpact();
          }
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                receiverEmail: userData["email"],
                receiverId: userData["uid"],
              ),
            ),
          );
        },
      ),
    );
  }
}
