// lib/services/encryption/encryption_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

class EncryptionService {
  // Firebase stuff
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Create a logger
  final Logger _logger = Logger('EncryptionService');

  // Make a random key for encryption
  String makeRandomKey() {
    // Use Random.secure because my teacher said it's more secure
    final random = Random.secure();

    // Make 32 random numbers and convert to a string
    List<int> numbers = [];
    for (int i = 0; i < 32; i++) {
      numbers.add(random.nextInt(256));
    }

    // Turn it into base64 because that's what the encrypt package needs
    String key = base64Encode(numbers);
    _logger.info("Created new encryption key!");
    return key;
  }

  // Save the key to Firebase so we can use it later
  Future<void> saveKeyToFirebase(
      String chatRoomId, String receiverId, String key) async {
    // Check if user is logged in
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.warning("Error: Not logged in!");
      return;
    }

    // Save the key
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('keys')
          .doc(receiverId)
          .set({
        'encryptedKey': key,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _logger.info("Key saved successfully!");
    } catch (e) {
      _logger.severe("Error saving key: $e");
    }
  }

  // Encrypt a message
  Map<String, String> encryptMessage(String message, String key) {
    try {
      // Convert the key to the format needed by the package
      final encryptKey = encrypt.Key.fromBase64(key);

      // Create a random IV (my teacher explained this is important for security)
      final iv = encrypt.IV.fromSecureRandom(16);

      // Set up the encrypter
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));

      // Do the encryption
      final encrypted = encrypter.encrypt(message, iv: iv);

      _logger.info("Message encrypted successfully!");

      // Return the encrypted message and IV
      return {
        'encryptedText': encrypted.base64,
        'iv': iv.base64,
      };
    } catch (e) {
      // If something goes wrong, just return the original message
      _logger.warning("Encryption failed: $e");
      return {
        'encryptedText': message,
        'iv': '',
      };
    }
  }

  // Decrypt a message
  String decryptMessage(String encryptedMessage, String ivString, String key) {
    try {
      // If there's no IV, it's probably not encrypted
      if (ivString.isEmpty) {
        return encryptedMessage;
      }

      // Set up the decryption
      final encryptKey = encrypt.Key.fromBase64(key);
      final iv = encrypt.IV.fromBase64(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));

      // Decrypt the message
      String decrypted = encrypter.decrypt64(encryptedMessage, iv: iv);
      _logger.info("Message decrypted successfully!");
      return decrypted;
    } catch (e) {
      // If decryption fails, show an error message
      _logger.warning("Decryption failed: $e");
      return "[Could not decrypt message]";
    }
  }

  // Get or create a key for a chat room
  Future<String> getOrCreateChatKey(String chatRoomId) async {
    // Check if user is logged in
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.severe("Error: Not logged in!");
      throw Exception("Not logged in");
    }

    // Try to get existing key
    try {
      final keyDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('keys')
          .doc('shared_key')
          .get();

      // If key exists, return it
      if (keyDoc.exists &&
          keyDoc.data() != null &&
          keyDoc.data()!['key'] != null) {
        _logger.info("Found existing key!");
        return keyDoc.data()!['key'];
      }

      // Otherwise create a new key
      _logger.info("No key found, creating new one...");
      final newKey = makeRandomKey();

      // Save the new key
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

      _logger.info("New key created and saved!");
      return newKey;
    } catch (e) {
      // Show error and rethrow
      _logger.severe("Error with chat key: $e");
      throw Exception("Failed to get or create key: $e");
    }
  }
}
