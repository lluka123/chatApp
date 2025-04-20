// lib/services/chat/chat_service.dart
import 'package:chatapp/models/message.dart';
import 'package:chatapp/services/encryption/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class ChatService extends ChangeNotifier {
  // Firebase stuff
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create our encryption service
  final EncryptionService _encryptionService = EncryptionService();
  // Create a logger
  final Logger _logger = Logger('ChatService');

  // This is just here because I need it in other files
  Future<void> initializeEncryption() async {
    // Nothing to do here, but I need this function
    _logger.info("Initializing encryption...");
  }

  // Get all users from Firebase
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("users").snapshots().map((snapshot) {
      // Convert each document to a Map
      return snapshot.docs.map((doc) {
        return doc.data();
      }).toList();
    });
  }

  // Get all users except ones I blocked
  Stream<List<Map<String, dynamic>>> getUsersStreamExceptBlocked() {
    // Get current user
    final currentUser = _auth.currentUser;

    // First get blocked users, then filter the main user list
    return _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
      // Get IDs of blocked users
      List<String> blockedIds = [];
      for (var doc in snapshot.docs) {
        blockedIds.add(doc.id);
      }

      // Get all users
      final usersSnapshot = await _firestore.collection("users").get();

      // Filter out blocked users and myself
      List<Map<String, dynamic>> filteredUsers = [];
      for (var doc in usersSnapshot.docs) {
        if (doc.data()['email'] != currentUser.email &&
            !blockedIds.contains(doc.id)) {
          filteredUsers.add(doc.data());
        }
      }

      return filteredUsers;
    });
  }

  // Send a message with encryption
  Future<void> sendMessage(String receiverId, String message) async {
    // Get current user info
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // Create chat room ID by combining user IDs alphabetically
    List<String> ids = [currentUserId, receiverId];
    ids.sort(); // Sort alphabetically
    String chatRoomID = ids.join("_");

    try {
      // Get or create encryption key
      String key = await _encryptionService.getOrCreateChatKey(chatRoomID);

      // Encrypt the message
      Map<String, String> encrypted =
          _encryptionService.encryptMessage(message, key);

      // Create a message object
      Message newMessage = Message(
        senderId: currentUserId,
        senderEmail: currentUserEmail,
        receiverId: receiverId,
        message: encrypted['encryptedText']!,
        iv: encrypted['iv']!,
        timestamp: timestamp,
      );

      // Save to Firebase
      await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .add(newMessage.toMap());

      _logger.info("Message sent and encrypted!");
    } catch (e) {
      _logger.warning("Error sending message: $e");
    }
  }

  // Get messages between two users
  Stream<QuerySnapshot> getMessages(String userId, otherUserId) {
    // Create chat room ID
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomID = ids.join("_");

    // Get messages from Firebase
    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  // Decrypt a message from document
  Future<String> decryptMessageFromDoc(
      Map<String, dynamic> messageData, String chatRoomId) async {
    try {
      // Get key
      String key = await _encryptionService.getOrCreateChatKey(chatRoomId);

      // Get message and IV
      String encrypted = messageData['message'] ?? '';
      String iv = messageData['iv'] ?? '';

      // Decrypt
      return _encryptionService.decryptMessage(encrypted, iv, key);
    } catch (e) {
      _logger.warning("Error decrypting: $e");
      return "[Decryption error]";
    }
  }

  // Old decrypt function (keeping for compatibility)
  Future<String> decryptMessage(
      String encryptedMessage, String chatRoomId) async {
    try {
      // Get key
      String key = await _encryptionService.getOrCreateChatKey(chatRoomId);

      // Decrypt (without IV for old messages)
      return _encryptionService.decryptMessage(encryptedMessage, '', key);
    } catch (e) {
      _logger.warning("Error with old decryption: $e");
      return "[Encrypted message]";
    }
  }

  // Report user function
  Future<void> reportUser(String messageId, String userId) async {
    final currentUser = _auth.currentUser;

    // Create report
    Map<String, dynamic> report = {
      'reportedBy': currentUser!.uid,
      'messageId': messageId,
      'messageOwnerId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Save report to Firebase
    try {
      await _firestore.collection('reports').add(report);
      _logger.info("User reported successfully");
    } catch (e) {
      _logger.warning("Error reporting user: $e");
    }
  }

  // Block a user
  Future<void> blockUser(String userId) async {
    final currentUser = _auth.currentUser;

    try {
      // Add user to blocked collection
      await _firestore
          .collection("users")
          .doc(currentUser!.uid)
          .collection("blockedUsers")
          .doc(userId)
          .set({});

      _logger.info("User blocked successfully");
      notifyListeners();
    } catch (e) {
      _logger.warning("Error blocking user: $e");
    }
  }

  // Unblock a user
  Future<void> unblockUser(String blockedUserId) async {
    final currentUser = _auth.currentUser;

    try {
      // Remove user from blocked collection
      await _firestore
          .collection("users")
          .doc(currentUser!.uid)
          .collection("blockedUsers")
          .doc(blockedUserId)
          .delete();

      _logger.info("User unblocked successfully");
    } catch (e) {
      _logger.warning("Error unblocking user: $e");
    }
  }

  // Get list of blocked users
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
      // Get blocked user IDs
      List<String> blockedIds = [];
      for (var doc in snapshot.docs) {
        blockedIds.add(doc.id);
      }

      // Get user details for each blocked ID
      List<Map<String, dynamic>> blockedUsers = [];
      for (var id in blockedIds) {
        DocumentSnapshot userDoc =
            await _firestore.collection("users").doc(id).get();
        blockedUsers.add(userDoc.data() as Map<String, dynamic>);
      }

      return blockedUsers;
    });
  }
}
