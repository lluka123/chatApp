// lib/components/chat_bubble.dart
import 'package:chatapp/services/chat/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final String messageId;
  final String userId;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.messageId,
    required this.userId,
  });

  void _showContextMenu(BuildContext context) {
    final chatService = ChatService();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Copy message'),
              onTap: () {
                // Copy message to clipboard
                Navigator.pop(context);
              },
            ),
            if (!isCurrentUser) ...[
              ListTile(
                leading: Icon(Icons.report),
                title: Text('Report message'),
                onTap: () {
                  chatService.reportUser(messageId, userId);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Message reported')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.block),
                title: Text('Block user'),
                onTap: () {
                  chatService.blockUser(userId);
                  Navigator.pop(context);
                  Navigator.pop(context); // Go back to home
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User blocked')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isCurrentUser ? Radius.circular(0) : null,
            bottomLeft: !isCurrentUser ? Radius.circular(0) : null,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(DateTime.now()),
              style: TextStyle(
                color: isCurrentUser
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.5),
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
