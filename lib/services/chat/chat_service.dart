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
        return doc.data();
      }).toList();
    });
  }

  // Pridobi vse uporabnike razen tistih, ki sem jih blokiral
  Stream<List<Map<String, dynamic>>> getUsersStreamExceptBlocked() {
    // Pridobi trenutnega uporabnika
    final currentUser = _auth.currentUser;

    // Najprej pridobi blokirane uporabnike, nato filtriraj glavni seznam uporabnikov
    return _firestore
        .collection("users")
        .doc(currentUser!.uid)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
      // Pridobi ID-je blokiranih uporabnikov
      List<String> blockedIds = [];
      for (var doc in snapshot.docs) {
        blockedIds.add(doc.id);
      }

      // Pridobi vse uporabnike
      final usersSnapshot = await _firestore.collection("users").get();

      // Filtriraj blokirane uporabnike in sebe
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

  // Funkcija za prijavo uporabnika
  Future<void> reportUser(String messageId, String userId) async {
    final currentUser = _auth.currentUser;

    // Ustvari prijavo
    Map<String, dynamic> report = {
      'reportedBy': currentUser!.uid,
      'messageId': messageId,
      'messageOwnerId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Shrani prijavo v Firebase
    try {
      await _firestore.collection('reports').add(report);
      _logger.info("Uporabnik uspešno prijavljen");
    } catch (e) {
      _logger.warning("Napaka pri prijavi uporabnika: $e");
    }
  }

  // Blokiraj uporabnika
  Future<void> blockUser(String userId) async {
    final currentUser = _auth.currentUser;

    try {
      // Dodaj uporabnika v zbirko blokiranih
      await _firestore
          .collection("users")
          .doc(currentUser!.uid)
          .collection("blockedUsers")
          .doc(userId)
          .set({});

      _logger.info("Uporabnik uspešno blokiran");
      notifyListeners();
    } catch (e) {
      _logger.warning("Napaka pri blokiranju uporabnika: $e");
    }
  }

  // Odblokiraj uporabnika
  Future<void> unblockUser(String blockedUserId) async {
    final currentUser = _auth.currentUser;

    try {
      // Odstrani uporabnika iz zbirke blokiranih
      await _firestore
          .collection("users")
          .doc(currentUser!.uid)
          .collection("blockedUsers")
          .doc(blockedUserId)
          .delete();

      _logger.info("Uporabnik uspešno odblokiran");
    } catch (e) {
      _logger.warning("Napaka pri odblokiranju uporabnika: $e");
    }
  }

  // Pridobi seznam blokiranih uporabnikov
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream(String userId) {
    return _firestore
        .collection("users")
        .doc(userId)
        .collection("blockedUsers")
        .snapshots()
        .asyncMap((snapshot) async {
      // Pridobi ID-je blokiranih uporabnikov
      List<String> blockedIds = [];
      for (var doc in snapshot.docs) {
        blockedIds.add(doc.id);
      }

      // Pridobi podrobnosti uporabnika za vsak blokiran ID
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
