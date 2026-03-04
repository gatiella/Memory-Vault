import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:notes/utils/secure_storage.dart';

class SimpleEncryptionUtil {
  static Future<String> encryptText(String plainText) async {
    try {
      final key = await _deriveKey();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return '${encrypted.base64}|${iv.base64}';
    } catch (e) {
      print("Encryption error: $e");
      return '';
    }
  }

  static Future<String> decryptText(String encryptedText) async {
    try {
      final key = await _deriveKey();
      final parts = encryptedText.split('|');
      if (parts.length != 2) {
        throw const FormatException("Invalid encrypted text format");
      }
      final encrypted = encrypt.Encrypted.fromBase64(parts[0]);
      final iv = encrypt.IV.fromBase64(parts[1]);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print("Decryption error: $e");
      return '';
    }
  }

  static Future<encrypt.Key> _deriveKey() async {
    final storedKey = await SecureStorage.getEncryptionKey();
    if (storedKey.isEmpty) {
      throw Exception("Stored encryption key is null or empty");
    }
    final keyBytes = sha256.convert(utf8.encode(storedKey)).bytes;
    return encrypt.Key(Uint8List.fromList(keyBytes));
  }
}
