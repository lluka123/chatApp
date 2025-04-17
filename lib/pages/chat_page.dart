// lib/pages/chat_page.dart
import "package:chatapp/components/chat_bubble.dart";
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";

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
  final TextEditingController _messageController = TextEditingController();

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  FocusNode myFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 750), () => scrollDown());
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () => scrollDown());
    
    // Initialize encryption
    _initializeEncryption();
  }
  
  Future<void> _initializeEncryption() async {
    setState(() {
      _isLoading = true;
    });
    
    await _chatService.initializeEncryption();
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    super.dispose();
  }

  final ScrollController _scrollController = ScrollController();
  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(seconds: 1),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }
void sendMessage() async {
  if (_messageController.text.isNotEmpty) {
    setState(() {
      _isLoading = true;
    });

    try {
      await _chatService.sendMessage(
        widget.receiverId,
        _messageController.text,
      );

      _messageController.clear();
      scrollDown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending message: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                widget.receiverEmail[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverEmail,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    "End-to-end encrypted",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [Expanded(child: _buildMessageList()), _buildUserInput()],
            ),
    );
  }

 Widget _buildMessageList() {
  String senderId = _authService.getCurrentUser()!.uid;
  List<String> ids = [senderId, widget.receiverId];
  ids.sort();
  String chatRoomID = ids.join("_");

  return StreamBuilder(
    stream: _chatService.getMessages(senderId, widget.receiverId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text("Error loading messages"));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());

      return ListView(
  controller: _scrollController,
  padding: const EdgeInsets.all(12),
  children: snapshot.data!.docs.map((doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return FutureBuilder<String>(
      future: _chatService.decryptMessageFromDoc(
        data, 
        chatRoomID
      ),
      builder: (context, decryptSnapshot) {
        if (decryptSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 0);
        }
        
        bool isCurrentUser = data['senderId'] == senderId;
        
        return _buildMessageListItem(
          doc, 
          decryptSnapshot.data ?? "[Decryption error]",
          isCurrentUser
        );
      },
    );
  }).toList(),
);

    },
  );
}


  Widget _buildMessageListItem(
    DocumentSnapshot doc, 
    String decryptedMessage,
    bool isCurrentUser
  ) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    var alignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;

    return Container(
      alignment: alignment,
      child: ChatBubble(
        message: decryptedMessage,
        isCurrentUser: isCurrentUser,
        messageId: doc.id,
        userId: data["senderId"],
      ),
    );
  }

  Widget _buildUserInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            // FIXED: Use withValues instead of withOpacity
            color: Colors.black.withValues(alpha: 0.05 * 255),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageController,
                  focusNode: myFocusNode,
                  decoration: InputDecoration(
                    hintText: "Type a message",
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7 * 255.0),
                    ),
                  ),
                  maxLines: null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isLoading ? null : sendMessage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
