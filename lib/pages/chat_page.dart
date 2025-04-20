// lib/pages/chat_page.dart
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:logging/logging.dart";

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverId;

  const ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Kontrolerji za vnos in drsenje
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Servisi
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger('ChatPage');

  // Focus node za tipkovnico
  FocusNode myFocusNode = FocusNode();

  // Spremenljivke stanja
  bool _hasText = false;
  bool _isInitialized = false;
  int _lastMessageCount = 0;

  // Spremenljivka za sledenje stanju tipkovnice
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();

    // Namesto uporabe poslušalca, ki kliče setState za vsak pritisk tipke,
    // bomo posodobili _hasText pri pošiljanju sporočila ali v onChanged
    _messageController.text = ""; // Začni prazno
    _hasText = false;

    // Bolje upravljaj s prikazom/skrivanjem tipkovnice
    myFocusNode.addListener(() {
      // Posodobi stanje samo, če se je vidnost tipkovnice dejansko spremenila
      bool keyboardIsNowVisible = myFocusNode.hasFocus;
      if (_isKeyboardVisible != keyboardIsNowVisible) {
        setState(() {
          _isKeyboardVisible = keyboardIsNowVisible;
        });

        // Če se je tipkovnica pravkar pojavila, se pomakni navzdol
        if (keyboardIsNowVisible) {
          // Počakaj, da se tipkovnica popolnoma pojavi
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) scrollDown();
          });
        }
      }
    });

    // Inicializiraj šifriranje
    initializeChat();
  }

  // Funkcija za inicializacijo klepeta
  void initializeChat() async {
    try {
      // Inicializiraj šifrirni servis
      await _chatService.initializeEncryption();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Pomakni se na dno
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) scrollDown();
        });
      }
    } catch (e) {
      _logger.severe("Inicializacija klepeta ni uspela: $e");
      // Prikazal bom napako, če aplikacija ne more inicializirati
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Napaka pri nastavitvi klepeta: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Počisti kontrolerje
    myFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Funkcija za pomik na dno klepeta
  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Funkcija za pošiljanje sporočila
  void sendMessage() async {
    // Preveri, če sporočilo ni prazno
    if (_messageController.text.isNotEmpty) {
      // Pridobi besedilo sporočila in ga shrani pred čiščenjem polja
      String message = _messageController.text;

      // Počisti vnosno polje
      _messageController.clear();

      // Posodobi stanje hasText po čiščenju
      setState(() {
        _hasText = false;
      });

      try {
        // Pošlji šifrirano sporočilo
        await _chatService.sendMessage(
          widget.receiverId,
          message,
        );

        // Pomakni se navzdol po pošiljanju
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            scrollDown();
          });
        }
      } catch (e) {
        // Prikaži napako, če pošiljanje ne uspe - s preverjanjem mounted
        _logger.warning("Pošiljanje sporočila ni uspelo: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Napaka pri pošiljanju sporočila: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            // Avatar uporabnika
            CircleAvatar(
              backgroundColor: const Color(0xFF1E88E5),
              child: Text(
                widget.receiverEmail[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Podrobnosti uporabnika
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email
                  Text(
                    widget.receiverEmail,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Indikator šifriranja
                  Row(
                    children: [
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "End-to-end encrypted",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF1E88E5),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Seznam sporočil
          Expanded(child: buildMessageList()),
          // Vnosno polje
          buildUserInput(),
        ],
      ),
    );
  }

  // Zgradi seznam sporočil
  Widget buildMessageList() {
    // Prikaži indikator nalaganja med inicializacijo
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Pridobi ID trenutnega uporabnika
    String senderId = _authService.getCurrentUser()!.uid;

    // Ustvari ID klepetalnice
    List<String> ids = [senderId, widget.receiverId];
    ids.sort();
    String chatRoomID = ids.join("_");

    // Stream builder za sporočila
    return StreamBuilder(
      stream: _chatService.getMessages(senderId, widget.receiverId),
      builder: (context, snapshot) {
        // Obravnavaj stanja nalaganja in napak
        if (snapshot.hasError) {
          _logger.warning("Napaka v toku sporočil: ${snapshot.error}");
          return const Center(
            child: Text("Napaka pri nalaganju sporočil"),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Preveri nova sporočila
        if (snapshot.data != null && snapshot.data!.docs.isNotEmpty) {
          int currentCount = snapshot.data!.docs.length;

          // Če imamo več sporočil kot prej
          if (_lastMessageCount > 0 && currentCount > _lastMessageCount) {
            var lastMessage = snapshot.data!.docs.last;

            // Preveri, če je sporočilo od druge osebe
            if (lastMessage['senderId'] != senderId) {
              _logger.info("Prejeto novo sporočilo");
            }
          }

          // Posodobi števec
          _lastMessageCount = currentCount;
        }

        // Pomakni se navzdol, ko prispejo nova sporočila, vendar samo če smo že blizu dna
        // To prepreči skakanje seznama med branjem starih sporočil
        if (_scrollController.hasClients) {
          bool isNearBottom = _scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels <
              150;

          if (isNearBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollDown();
            });
          }
        }

        // Prikaži sporočilo, če ni sporočil
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("Še ni sporočil"),
          );
        }

        // Zgradi seznam sporočil
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            // Pridobi podatke sporočila
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Dešifriraj sporočilo
            return FutureBuilder<String>(
              future: _chatService.decryptMessageFromDoc(data, chatRoomID),
              builder: (context, decryptSnapshot) {
                // Ne prikaži ničesar med dešifriranjem
                if (decryptSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                // Preveri, če je sporočilo od trenutnega uporabnika
                bool isCurrentUser = data['senderId'] == senderId;

                // Zgradi mehurček sporočila
                return buildMessageItem(
                  decryptSnapshot.data ?? "[Napaka pri dešifriranju]",
                  isCurrentUser,
                  data['timestamp'] as Timestamp,
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  // Zgradi mehurček sporočila
  Widget buildMessageItem(
      String message, bool isCurrentUser, Timestamp timestamp) {
    // Oblikuj čas
    DateTime messageTime = timestamp.toDate();
    String formattedTime =
        "${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}";

    // Mehurček sporočila
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        // Poravnaj desno ali levo glede na pošiljatelja
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Vsebina sporočila
          Container(
            // Omeji širino na 75% zaslona
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            // Različna barva glede na pošiljatelja
            decoration: BoxDecoration(
              color: isCurrentUser ? const Color(0xFF1E88E5) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // Časovna oznaka
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              formattedTime,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Zgradi območje za vnos sporočila
  Widget buildUserInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Besedilni vnos
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageController,
                  focusNode: myFocusNode,
                  // Posodobi hasText samo, ko se besedilo dejansko spremeni, ne ob vsakem ponovnem izrisu
                  onChanged: (text) {
                    // Kliči setState samo, če se je vrednost dejansko spremenila
                    if ((_hasText && text.isEmpty) ||
                        (!_hasText && text.isNotEmpty)) {
                      setState(() {
                        _hasText = text.isNotEmpty;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: "Napiši sporočilo",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Gumb za pošiljanje - ne preoblikuj tega ob vsakem znaku, to je potratno
          Container(
            decoration: BoxDecoration(
              color: _hasText ? const Color(0xFF1E88E5) : Colors.grey[300],
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _hasText ? sendMessage : null,
              icon: const Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
