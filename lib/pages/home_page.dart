// lib/pages/home_page.dart
import "package:chatapp/pages/chat_page.dart";
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:flutter/material.dart";

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Servisi
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();

  // Stanje nalaganja
  bool _isLoading = true;

  // Za demonstracijo bomo vnaprej določili nekaj uporabnikov z neprebranimi sporočili
  // V pravi aplikaciji bi to sledili v vaši bazi podatkov
  final List<String> _usersWithUnreadMessages = ['user123', 'user456'];

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // Za demonstracijske namene dodajmo časovnik, ki simulira novo sporočilo
    // po 5 sekundah za testiranje obvestila
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          // Dodaj naključni ID uporabnika na seznam neprebranih sporočil
          _usersWithUnreadMessages.add('randomUser789');
        });
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

  // Funkcija za odjavo
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Odjava"),
        content: const Text("Ali ste prepričani, da se želite odjaviti?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Prekliči"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _authService.signOut();
            },
            child: const Text(
              "Odjava",
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
            child: Text("Napaka pri nalaganju uporabnikov"),
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
            child: Text("Ni razpoložljivih uporabnikov"),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index];
            if (userData["email"] != _authService.getCurrentUser()!.email) {
              // Za demonstracijo bomo označili nekatere uporabnike kot tiste z neprebranimi sporočili
              // V pravi aplikaciji bi to preverili v vaši bazi podatkov
              bool hasUnreadMessages = index % 3 ==
                  0; // Vsak tretji uporabnik ima neprebrana sporočila

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
    // Pridobi prvo črko e-pošte za avatar
    String firstLetter = userData["email"][0].toUpperCase();

    // Določi barvo avatarja glede na prvo črko
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
            // Prikaži piko za obvestilo, če obstajajo neprebrana sporočila
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
              "Tapni za začetek varnega klepeta",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () {
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
