// lib/services/encryption/encryption_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';

class EncryptionService {
  // Firebase elementi
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Ustvari logger
  final Logger _logger = Logger('EncryptionService');

  // Ustvari naključni ključ za šifriranje
  String makeRandomKey() {
    // Uporabi Random.secure, ker je moj učitelj rekel, da je bolj varen
    final random = Random.secure();

    // Ustvari 32 naključnih števil in jih pretvori v niz
    List<int> numbers = [];
    for (int i = 0; i < 32; i++) {
      numbers.add(random.nextInt(256));
    }

    // Pretvori v base64, ker to potrebuje encrypt paket
    String key = base64Encode(numbers);
    _logger.info("Ustvarjen nov šifrirni ključ!");
    return key;
  }

  // Shrani ključ v Firebase, da ga lahko uporabimo kasneje
  Future<void> saveKeyToFirebase(
      String chatRoomId, String receiverId, String key) async {
    // Preveri, če je uporabnik prijavljen
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.warning("Napaka: Niste prijavljeni!");
      return;
    }

    // Shrani ključ
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
      _logger.info("Ključ uspešno shranjen!");
    } catch (e) {
      _logger.severe("Napaka pri shranjevanju ključa: $e");
    }
  }

  // Šifriraj sporočilo
  Map<String, String> encryptMessage(String message, String key) {
    try {
      // Pretvori ključ v format, ki ga potrebuje paket
      final encryptKey = encrypt.Key.fromBase64(key);

      // Ustvari naključni IV (moj učitelj je razložil, da je to pomembno za varnost)
      final iv = encrypt.IV.fromSecureRandom(16);

      // Nastavi šifrator
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));

      // Izvedi šifriranje
      final encrypted = encrypter.encrypt(message, iv: iv);

      _logger.info("Sporočilo uspešno šifrirano!");

      // Vrni šifrirano sporočilo in IV
      return {
        'encryptedText': encrypted.base64,
        'iv': iv.base64,
      };
    } catch (e) {
      // Če gre kaj narobe, vrni originalno sporočilo
      _logger.warning("Šifriranje ni uspelo: $e");
      return {
        'encryptedText': message,
        'iv': '',
      };
    }
  }

  // Dešifriraj sporočilo
  String decryptMessage(String encryptedMessage, String ivString, String key) {
    try {
      // Če ni IV, verjetno ni šifrirano
      if (ivString.isEmpty) {
        return encryptedMessage;
      }

      // Nastavi dešifriranje
      final encryptKey = encrypt.Key.fromBase64(key);
      final iv = encrypt.IV.fromBase64(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(encryptKey));

      // Dešifriraj sporočilo
      String decrypted = encrypter.decrypt64(encryptedMessage, iv: iv);
      _logger.info("Sporočilo uspešno dešifrirano!");
      return decrypted;
    } catch (e) {
      // Če dešifriranje ne uspe, prikaži sporočilo o napaki
      _logger.warning("Dešifriranje ni uspelo: $e");
      return "[Sporočila ni bilo mogoče dešifrirati]";
    }
  }

  // Pridobi ali ustvari ključ za klepetalnico
  Future<String> getOrCreateChatKey(String chatRoomId) async {
    // Preveri, če je uporabnik prijavljen
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.severe("Napaka: Niste prijavljeni!");
      throw Exception("Niste prijavljeni");
    }

    // Poskusi pridobiti obstoječi ključ
    try {
      final keyDoc = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('keys')
          .doc('shared_key')
          .get();

      // Če ključ obstaja, ga vrni
      if (keyDoc.exists &&
          keyDoc.data() != null &&
          keyDoc.data()!['key'] != null) {
        _logger.info("Najden obstoječi ključ!");
        return keyDoc.data()!['key'];
      }

      // Sicer ustvari nov ključ
      _logger.info("Ključ ni najden, ustvarjam novega...");
      final newKey = makeRandomKey();

      // Shrani novi ključ
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

      _logger.info("Nov ključ ustvarjen in shranjen!");
      return newKey;
    } catch (e) {
      // Prikaži napako in ponovno vrži
      _logger.severe("Napaka s ključem za klepet: $e");
      throw Exception("Ni uspelo pridobiti ali ustvariti ključa: $e");
    }
  }
}
