// lib/pages/home_page.dart
import "package:chatapp/pages/chat_page.dart";
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:flutter/material.dart";
import 'package:logging/logging.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Servisi
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  // Logger za celoten razred
  final Logger _logger = Logger('HomePage');

  // Stanje nalaganja
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Počakaj trenutek, da se UI lahko izriše pred nalaganjem podatkov
    await Future.delayed(const Duration(milliseconds: 100));

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
    // Pridobi trenutnega uporabnika za filtriranje
    final currentUserEmail = _authService.getCurrentUser()?.email;
    // Uporabi razredni logger namesto lokalnega
    // Ni več potrebe po lokalni spremenljivki logger

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.severe("Napaka pri nalaganju uporabnikov: ${snapshot.error}");
          return const Center(
            child: Text("Napaka pri nalaganju uporabnikov"),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Če še vedno nalagamo, prikaži indikator
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          _logger.warning("Ni podatkov o uporabnikih");
          return const Center(
            child: Text("Ni podatkov o uporabnikih"),
          );
        }

        // Filtriraj seznam uporabnikov, da izključiš trenutnega uporabnika
        final users = snapshot.data!
            .where((userData) => userData["email"] != currentUserEmail)
            .toList();

        if (users.isEmpty) {
          _logger.info("Seznam uporabnikov je prazen");
          return const Center(
            child: Text("Ni razpoložljivih uporabnikov za klepet"),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index];
            return _buildUserTile(userData);
          },
        );
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> userData) {
    String email = userData["email"] ?? "Neznan email";
    if (email.isEmpty) {
      email = "Neznan email";
    }
    String firstLetter = email.isNotEmpty ? email[0].toUpperCase() : "?";

    Color avatarColor;
    // Preprosta logika za barvo avatarja
    switch (firstLetter) {
      case 'A':
      case 'G':
      case 'M':
      case 'S':
      case 'Y':
        avatarColor = Colors.blue.shade300;
        break;
      case 'B':
      case 'H':
      case 'N':
      case 'T':
      case 'Z':
        avatarColor = Colors.green.shade300;
        break;
      case 'C':
      case 'I':
      case 'O':
      case 'U':
        avatarColor = Colors.purple.shade300;
        break;
      case 'D':
      case 'J':
      case 'P':
      case 'V':
        avatarColor = Colors.orange.shade300;
        break;
      case 'E':
      case 'K':
      case 'Q':
      case 'W':
        avatarColor = Colors.red.shade300;
        break;
      case 'F':
      case 'L':
      case 'R':
      case 'X':
        avatarColor = Colors.teal.shade300;
        break;
      default:
        avatarColor = Colors.grey.shade400;
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
        leading: CircleAvatar(
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
        title: Text(
          email,
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
          if (userData["uid"] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  receiverEmail: email,
                  receiverId: userData["uid"],
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Napaka: ID uporabnika ni na voljo."),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}
