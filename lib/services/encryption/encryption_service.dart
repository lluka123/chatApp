import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EncryptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate a secure random key
  String generateSecureKey() {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(keyBytes);
  }
  
  // Store encryption key in Firestore
  Future<void> storeEncryptionKey(String chatRoomId, String receiverId, String encryptedKey) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('keys')
        .doc(receiverId)
        .set({
      'encryptedKey': encryptedKey,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  // Encrypt a message
  String encryptMessage(String message, String key) {
    try {
      final encryptKey = encrypt.Key.fromBase64(key);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));
      return encrypter.encrypt(message, iv: iv).base64;
    } catch (e) {
      print("Encryption error: $e");
      return message; // Return original message if encryption fails
    }
  }
  
  // Decrypt a message
  String decryptMessage(String encryptedMessage, String key) {
    try {
      final encryptKey = encrypt.Key.fromBase64(key);
      final iv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));
      return encrypter.decrypt64(encryptedMessage, iv: iv);
    } catch (e) {
      print("Decryption error: $e");
      return "[Encrypted message]"; // Return placeholder if decryption fails
    }
  }
  
  // Generate a conversation key for a chat room
  Future<String> getOrCreateConversationKey(String chatRoomId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User not authenticated");
    
    // Check if key exists
    final keyDoc = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('keys')
        .doc('shared_key')
        .get();
    
    if (keyDoc.exists && keyDoc.data() != null && keyDoc.data()!.containsKey('key')) {
      return keyDoc.data()!['key'];
    }
    
    // Create new key
    final newKey = generateSecureKey();
    
    // Store key
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('keys')
        .doc('shared_key')
        .set({
      'key': newKey,
      'createdBy': currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    return newKey;
  }
}
