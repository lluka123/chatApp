// lib/pages/chat_page.dart
import "package:chatapp/components/chat_bubble.dart";
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

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonAnimation;

  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  FocusNode myFocusNode = FocusNode();
  bool _isLoading = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _sendButtonAnimation = CurvedAnimation(
      parent: _sendButtonController,
      curve: Curves.elasticOut,
    );

    _messageController.addListener(() {
      final hasText = _messageController.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
        if (hasText) {
          _sendButtonController.forward();
        } else {
          _sendButtonController.reverse();
        }
      }
    });

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
    _sendButtonController.dispose();
    myFocusNode.dispose();
    _messageController.dispose();
    super.dispose();
  }

  final ScrollController _scrollController = ScrollController();
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
      setState(() {
        _isLoading = true;
      });
      
      HapticFeedback.lightImpact();
      
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
          SnackBar(
            content: Text("Error sending message: ${e.toString()}"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.receiverId}',
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  widget.receiverEmail[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            onPressed: () {
              // Show chat options
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Setting up secure connection...",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(child: _buildMessageList()),
                _buildUserInput(),
              ],
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  "Error loading messages",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => scrollDown());

        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "No messages yet",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Start the conversation!",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
    
    // Format timestamp
    Timestamp timestamp = data['timestamp'] as Timestamp;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentUser 
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isCurrentUser ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isCurrentUser ? const Radius.circular(4) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              decryptedMessage,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black87,
                fontSize: 16,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 50, // Fixed height to ensure consistent sizing
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, // Light blue background
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _messageController,
                          focusNode: myFocusNode,
                          decoration: const InputDecoration(
                            hintText: "Type a message",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey),
                            // Remove any padding that might be causing the issue
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 16),
                          maxLines: 1, // Start with one line
                          minLines: 1, // Minimum one line
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        // Show emoji picker
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ScaleTransition(
              scale: _sendButtonAnimation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
