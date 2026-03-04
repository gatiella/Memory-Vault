import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyKey = 'encryption_key';

  static Future<String> getEncryptionKey() async {
    String? key = await _storage.read(key: _keyKey);
    if (key == null) {
      // Generate a new key if one doesn't exist
      key = _generateEncryptionKey();
      await _storage.write(key: _keyKey, value: key);
    }
    return key;
  }

  static String _generateEncryptionKey() {
    final key = encrypt.Key.fromSecureRandom(32);
    return key.base64;
  }

  static Future<void> saveEncryptedData(String key, String value) async {
    final encryptionKey = await getEncryptionKey();
    final encrypter = _getEncrypter(encryptionKey);
    final encrypted = encrypter.encrypt(value);
    await _storage.write(key: key, value: encrypted.base64);
  }

  static Future<String?> getDecryptedData(String key) async {
    final encryptionKey = await getEncryptionKey();
    final encrypter = _getEncrypter(encryptionKey);
    final encryptedValue = await _storage.read(key: key);
    if (encryptedValue == null) return null;
    final encrypted = encrypt.Encrypted.fromBase64(encryptedValue);
    return encrypter.decrypt(encrypted);
  }

  static encrypt.Encrypter _getEncrypter(String key) {
    final encryptionKey = encrypt.Key.fromBase64(key);
    return encrypt.Encrypter(encrypt.AES(encryptionKey));
  }
}
