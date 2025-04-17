// lib/pages/chat_page.dart
import "package:chatapp/components/chat_bubble.dart";
import "package:chatapp/components/my_textfield.dart";
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending message: ${e.toString()}")),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
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
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverEmail,
                    style: TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
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
          ? Center(child: CircularProgressIndicator())
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
          return Center(child: Text("Error loading messages"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());

        return ListView(
          controller: _scrollController,
          padding: EdgeInsets.all(12),
          children: snapshot.data!.docs.map((doc) {
            return FutureBuilder<String>(
              future: _chatService.decryptMessage(
                doc['message'], 
                chatRoomID
              ),
              builder: (context, decryptSnapshot) {
                if (decryptSnapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(height: 0);
                }
                
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
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
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                  maxLines: null,
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isLoading ? null : sendMessage,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
