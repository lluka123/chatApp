// lib/pages/chat_page.dart
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

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
  final ScrollController _scrollController = ScrollController();

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  FocusNode myFocusNode = FocusNode();
  bool _hasText = false;
  bool _isInitialized = false;
  
  // To track the last message count for vibration
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();

    _messageController.addListener(() {
      final newHasText = _messageController.text.isNotEmpty;
      if (_hasText != newHasText) {
        setState(() {
          _hasText = newHasText;
        });
      }
    });

    myFocusNode.addListener(() {
      if (myFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () => scrollDown());
      }
    });

    // Initialize encryption in background
    _initializeChat();
  }
  
  Future<void> _initializeChat() async {
    await _chatService.initializeEncryption();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      Future.delayed(const Duration(milliseconds: 300), () => scrollDown());
    }
  }

  @override
  void dispose() {
    myFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      // Save message and clear input
      String messageText = _messageController.text;
      _messageController.clear();
      
      try {
        await _chatService.sendMessage(
          widget.receiverId,
          messageText,
        );
        
        // Scroll down after sending
        Future.delayed(const Duration(milliseconds: 100), () => scrollDown());
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sending message: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.receiverEmail,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
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
          Expanded(child: _buildMessageList()),
          _buildUserInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    String senderId = _authService.getCurrentUser()!.uid;
    List<String> ids = [senderId, widget.receiverId];
    ids.sort();
    String chatRoomID = ids.join("_");

    return StreamBuilder(
      stream: _chatService.getMessages(senderId, widget.receiverId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text("Error loading messages"),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Check for new messages to vibrate
        if (snapshot.data != null && snapshot.data!.docs.isNotEmpty) {
          final currentMessageCount = snapshot.data!.docs.length;
          
          // If we have more messages than before and this isn't the first load
          if (_lastMessageCount > 0 && currentMessageCount > _lastMessageCount) {
            final latestMessage = snapshot.data!.docs.last;
            
            // Only vibrate if the message is from the other person
            if (latestMessage['senderId'] != senderId) {
              // Vibrate phone - use a stronger vibration pattern
              HapticFeedback.heavyImpact();
              
              // For older devices that might not support haptic feedback well
              Future.delayed(const Duration(milliseconds: 100), () {
                HapticFeedback.vibrate();
              });
            }
          }
          
          // Update the message count
          _lastMessageCount = currentMessageCount;
        }

        // Make sure we scroll down when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No messages yet"),
          );
        }

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            
            return FutureBuilder<String>(
              future: _chatService.decryptMessageFromDoc(data, chatRoomID),
              builder: (context, decryptSnapshot) {
                if (decryptSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                
                bool isCurrentUser = data['senderId'] == senderId;
                
                return _buildMessageItem(
                  decryptSnapshot.data ?? "[Error decrypting]",
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

  Widget _buildMessageItem(String message, bool isCurrentUser, Timestamp timestamp) {
    // Format time
    DateTime messageTime = timestamp.toDate();
    String formattedTime = "${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
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

  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
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
                  decoration: const InputDecoration(
                    hintText: "Type a message",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: sendMessage,
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
