// lib/services/chat/chat_service.dart (rename from chart_service.dart)
import 'package:chatapp/models/message.dart';
import 'package:chatapp/services/encryption/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatService extends ChangeNotifier {
  // Get instance of firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EncryptionService _encryptionService = EncryptionService();

  // Initialize encryption method
  Future<void> initializeEncryption() async {
    // This is a placeholder method to satisfy the calls in other files
    // The actual encryption is handled by the EncryptionService
  }

  // Get user stream
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    });
  }

  // Get all users except blocked users
  Stream<List<Map<String, dynamic>>> getUsersStreamExceptBlocked() {
    final currentUser = _auth.currentUser;

    return _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
          final blockedUserIds = snapshot.docs.map((doc) => doc.id).toList();

          final usersSnapshot = await _firestore.collection("users").get();

          return usersSnapshot.docs
              .where(
                (doc) =>
                    doc.data()['email'] != currentUser.email &&
                    !blockedUserIds.contains(doc.id),
              )
              .map((doc) => doc.data())
              .toList();
        });
  }

  // Send message with encryption
  Future<void> sendMessage(String receiverId, String message) async {
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // Create chat room ID
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatRoomID = ids.join("_");
    
    // Get or create conversation key
    String conversationKey = await _encryptionService.getOrCreateConversationKey(chatRoomID);
    
    // Encrypt message
    String encryptedMessage = _encryptionService.encryptMessage(message, conversationKey);

    Message newMessage = Message(
      senderId: currentUserId,
      senderEmail: currentUserEmail,
      receiverId: receiverId,
      message: encryptedMessage, // Store encrypted message
      timestamp: timestamp,
    );

    await _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .add(newMessage.toMap());
  }

  // Get messages
  Stream<QuerySnapshot> getMessages(String userId, otherUserId) {
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomID = ids.join("_");

    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }
  
  // Decrypt a message
  Future<String> decryptMessage(String encryptedMessage, String chatRoomId) async {
    try {
      // Get conversation key
      String conversationKey = await _encryptionService.getOrCreateConversationKey(chatRoomId);
      
      // Decrypt message
      return _encryptionService.decryptMessage(encryptedMessage, conversationKey);
    } catch (e) {
      // Use logger instead of print in production
      debugPrint("Error decrypting message: $e");
      return "[Decryption error]";
    }
  }

  // Report User
  Future<void> reportUser(String messageId, String userId) async {
    final currentUser = _auth.currentUser;
    final report = {
      'reportedBy': currentUser!.uid,
      'messageId': messageId,
      'messageOwnerId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('reports').add(report);
  }

  // Block User
  Future<void> blockUser(String userId) async {
    final currentUser = _auth.currentUser;
    await _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .doc(userId)
        .set({});

    notifyListeners();
  }

  // Unblock User
  Future<void> unblockUser(String blockedUserId) async {
    final currentUser = _auth.currentUser;
    await _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .doc(blockedUserId)
        .delete();
  }

  // Get Blocked User stream
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
          final blockedUserIds = snapshot.docs.map((doc) => doc.id).toList();

          final userDocs = await Future.wait(
            blockedUserIds.map(
              (id) => _firestore.collection("users").doc(id).get(),
            ),
          );

          return userDocs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
        });
  }
}
