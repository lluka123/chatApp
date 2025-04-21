// lib/services/chat/chat_service.dart
import 'package:chatapp/models/message.dart';
import 'package:chatapp/services/encryption/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class ChatService extends ChangeNotifier {
  // Firebase elementi
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ustvari naš šifrirni servis
  final EncryptionService _encryptionService = EncryptionService();
  // Ustvari logger
  final Logger _logger = Logger('ChatService');

  // To je tukaj samo zato, ker to potrebujem v drugih datotekah
  Future<void> initializeEncryption() async {
    // Tukaj ni ničesar za narediti, ampak potrebujem to funkcijo
    _logger.info("Inicializacija šifriranja...");
  }

  // Pridobi vse uporabnike iz Firebase
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("users").snapshots().map((snapshot) {
      // Pretvori vsak dokument v Map
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }

  // Pošlji sporočilo s šifriranjem
  Future<void> sendMessage(String receiverId, String message) async {
    // Pridobi informacije o trenutnem uporabniku
    final String currentUserId = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // Ustvari ID klepetalnice s kombinacijo ID-jev uporabnikov po abecedi
    List<String> ids = [currentUserId, receiverId];
    ids.sort(); // Razvrsti po abecedi
    String chatRoomID = ids.join("_");

    try {
      // Pridobi ali ustvari šifrirni ključ
      String key = await _encryptionService.getOrCreateChatKey(chatRoomID);

      // Šifriraj sporočilo
      Map<String, String> encrypted =
          _encryptionService.encryptMessage(message, key);

      // Ustvari objekt sporočila
      Message newMessage = Message(
        senderId: currentUserId,
        senderEmail: currentUserEmail,
        receiverId: receiverId,
        message: encrypted['encryptedText']!,
        iv: encrypted['iv']!,
        timestamp: timestamp,
      );

      // Shrani v Firebase
      await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .add(newMessage.toMap());

      _logger.info("Sporočilo poslano in šifrirano!");
    } catch (e) {
      _logger.warning("Napaka pri pošiljanju sporočila: $e");
    }
  }

  // Pridobi sporočila med dvema uporabnikoma
  Stream<QuerySnapshot> getMessages(String userId, otherUserId) {
    // Ustvari ID klepetalnice
    List<String> ids = [userId, otherUserId];
    ids.sort();
    String chatRoomID = ids.join("_");

    // Pridobi sporočila iz Firebase
    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }

  // Dešifriraj sporočilo iz dokumenta
  Future<String> decryptMessageFromDoc(
      Map<String, dynamic> messageData, String chatRoomId) async {
    try {
      // Pridobi ključ
      String key = await _encryptionService.getOrCreateChatKey(chatRoomId);

      // Pridobi sporočilo in IV
      String encrypted = messageData['message'] ?? '';
      String iv = messageData['iv'] ?? '';

      // Dešifriraj
      return _encryptionService.decryptMessage(encrypted, iv, key);
    } catch (e) {
      _logger.warning("Napaka pri dešifriranju: $e");
      return "[Napaka pri dešifriranju]";
    }
  }

  // Stara funkcija za dešifriranje (ohranjena zaradi združljivosti)
  Future<String> decryptMessage(
      String encryptedMessage, String chatRoomId) async {
    try {
      // Pridobi ključ
      String key = await _encryptionService.getOrCreateChatKey(chatRoomId);

      // Dešifriraj (brez IV za stara sporočila)
      return _encryptionService.decryptMessage(encryptedMessage, '', key);
    } catch (e) {
      _logger.warning("Napaka pri starem dešifriranju: $e");
      return "[Šifrirano sporočilo]";
    }
  }
}
