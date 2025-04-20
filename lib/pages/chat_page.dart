// lib/pages/chat_page.dart
import "package:chatapp/services/auth/auth_service.dart";
import "package:chatapp/services/chat/chat_service.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
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
  // Controllers for input and scrolling
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final Logger _logger = Logger('ChatPage');

  // Focus node for keyboard
  FocusNode myFocusNode = FocusNode();

  // State variables
  bool _hasText = false;
  bool _isInitialized = false;
  int _lastMessageCount = 0;

  // Variable to track keyboard status
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();

    // Instead of using a listener that calls setState for every keystroke,
    // we'll update _hasText when sending a message or in onChanged
    _messageController.text = ""; // Start empty
    _hasText = false;

    // Handle keyboard showing/hiding better
    myFocusNode.addListener(() {
      // Only update state if keyboard visibility actually changed
      bool keyboardIsNowVisible = myFocusNode.hasFocus;
      if (_isKeyboardVisible != keyboardIsNowVisible) {
        setState(() {
          _isKeyboardVisible = keyboardIsNowVisible;
        });

        // If keyboard just appeared, scroll down
        if (keyboardIsNowVisible) {
          // Wait for keyboard to fully appear
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) scrollDown();
          });
        }
      }
    });

    // Initialize encryption
    initializeChat();
  }

  // Initialize chat function
  void initializeChat() async {
    try {
      // Initialize encryption service
      await _chatService.initializeEncryption();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) scrollDown();
        });
      }
    } catch (e) {
      _logger.severe("Failed to initialize chat: $e");
      // I'll show an error if the app can't initialize
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error setting up chat: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    myFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Function to scroll to bottom of chat
  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Send message function
  void sendMessage() async {
    // Check if message is not empty
    if (_messageController.text.isNotEmpty) {
      // Get message text and save it before clearing the field
      String message = _messageController.text;

      // Clear input field
      _messageController.clear();

      // Update hasText state after clearing
      setState(() {
        _hasText = false;
      });

      try {
        // Send encrypted message
        await _chatService.sendMessage(
          widget.receiverId,
          message,
        );

        // Scroll down after sending
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            scrollDown();
          });
        }
      } catch (e) {
        // Show error if sending fails - with mounted check
        _logger.warning("Failed to send message: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error sending message: $e"),
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
            // User avatar
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
            // User details
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
                  // Encryption indicator
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
          // Messages list
          Expanded(child: buildMessageList()),
          // Input field
          buildUserInput(),
        ],
      ),
    );
  }

  // Build the message list
  Widget buildMessageList() {
    // Show loading indicator while initializing
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Get current user ID
    String senderId = _authService.getCurrentUser()!.uid;

    // Create chat room ID
    List<String> ids = [senderId, widget.receiverId];
    ids.sort();
    String chatRoomID = ids.join("_");

    // Stream builder for messages
    return StreamBuilder(
      stream: _chatService.getMessages(senderId, widget.receiverId),
      builder: (context, snapshot) {
        // Handle loading and error states
        if (snapshot.hasError) {
          _logger.warning("Error in message stream: ${snapshot.error}");
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
          int currentCount = snapshot.data!.docs.length;

          // If we have more messages than before
          if (_lastMessageCount > 0 && currentCount > _lastMessageCount) {
            var lastMessage = snapshot.data!.docs.last;

            // Check if message is from other person
            if (lastMessage['senderId'] != senderId) {
              // Make phone vibrate
              HapticFeedback.vibrate();
              _logger.info("New message received - vibrating");
            }
          }

          // Update count
          _lastMessageCount = currentCount;
        }

        // Scroll down when new messages arrive, but only if we're already near the bottom
        // This stops the list jumping around while reading old messages
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

        // Show message if no messages
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No messages yet"),
          );
        }

        // Build message list
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: snapshot.data!.docs.map((doc) {
            // Get message data
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            // Decrypt message
            return FutureBuilder<String>(
              future: _chatService.decryptMessageFromDoc(data, chatRoomID),
              builder: (context, decryptSnapshot) {
                // Show nothing while decrypting
                if (decryptSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }

                // Check if message is from current user
                bool isCurrentUser = data['senderId'] == senderId;

                // Build message bubble
                return buildMessageItem(
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

  // Build a message bubble
  Widget buildMessageItem(
      String message, bool isCurrentUser, Timestamp timestamp) {
    // Format the time
    DateTime messageTime = timestamp.toDate();
    String formattedTime =
        "${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}";

    // Message bubble
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        // Align to right or left based on sender
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message content
          Container(
            // Limit width to 75% of screen
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            // Different color based on sender
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
          // Time stamp
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

  // Build the message input area
  Widget buildUserInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Text input
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
                  // Only update hasText when text actually changes, not on every rebuild
                  onChanged: (text) {
                    // Only call setState if the value actually changed
                    if ((_hasText && text.isEmpty) ||
                        (!_hasText && text.isNotEmpty)) {
                      setState(() {
                        _hasText = text.isNotEmpty;
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: "Type a message",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button - don't rebuild this on every character, it's wasteful
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
