import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

/// Crypto Service
///
/// Handles AES-CBC encryption/decryption matching the desktop PowerBuilder implementation.
///
/// Desktop Encryption Details:
/// - Algorithm: AES (Advanced Encryption Standard)
/// - Mode: CBC (Cipher Block Chaining)
/// - Padding: PKCS7
/// - Encoding: Base64 (for encrypted output)
/// - Key Length: Variable (from tbsrencryptpass)
/// - IV Length: 16 bytes (same as key, truncated/padded to 16 bytes)
class CryptoService {
  // Encryption key from desktop database (tbsrencryptpass)
  // This key is used for AES-CBC encryption/decryption of passwords in mbstaff table
  static const String _encryptionKey = 'PCASVR-29POWERCA';

  /// Get the encryption key
  /// In production, this could be fetched from secure storage or environment
  static String get encryptionKey => _encryptionKey;

  /// Set a custom encryption key (for testing or dynamic key loading)
  static String? _customKey;

  static void setEncryptionKey(String key) {
    _customKey = key;
  }

  static String _getActiveKey() {
    return _customKey ?? _encryptionKey;
  }

  /// Decrypt a Base64-encoded AES-CBC encrypted string
  ///
  /// This matches the desktop decrypt function:
  /// ```powerbuilder
  /// lblb_decoded = lnv_coder.Base64Decode(ls_data)
  /// lblb_key = Blob(ls_encrypt, EncodingANSI!)
  /// lblb_iv = Blob(ls_encrypt, EncodingANSI!)
  /// lblb_decrypt = lnv_CrypterObject.SymmetricDecrypt(AES!, lblb_decoded,
  ///                lblb_key, OperationModeCBC!, lblb_iv, PKCSPadding!)
  /// ```
  static String decrypt(String encryptedBase64) {
    try {
      if (encryptedBase64.isEmpty) {
        return encryptedBase64;
      }

      final keyString = _getActiveKey();

      // Ensure key is at least 16 bytes for AES-128
      // If longer than 32 bytes, truncate to 32 (AES-256)
      final keyBytes = _prepareKey(keyString);
      final ivBytes = _prepareIV(keyString);

      // Create key and IV
      final key = enc.Key(keyBytes);
      final iv = enc.IV(ivBytes);

      // Create encrypter with AES CBC mode
      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );

      // Decrypt
      final decrypted = encrypter.decrypt64(
        encryptedBase64,
        iv: iv,
      );

      return decrypted;
    } catch (e) {
      // If decryption fails, return original string
      // (handles cases where password might not be encrypted)
      return encryptedBase64;
    }
  }

  /// Encrypt a string using AES-CBC
  ///
  /// This matches the desktop encrypt function:
  /// ```powerbuilder
  /// lblb_data = Blob(ls_data, EncodingANSI!)
  /// lblb_key = Blob(ls_encrypt, EncodingANSI!)
  /// lblb_iv = Blob(ls_encrypt, EncodingANSI!)
  /// lblb_encrypt = lnv_CrypterObject.SymmetricEncrypt(AES!, lblb_data,
  ///                lblb_key, OperationModeCBC!, lblb_iv, PKCSPadding!)
  /// ls_base64 = lnv_coder.Base64Encode(lblb_encrypt)
  /// ```
  static String encrypt(String plainText) {
    try {
      if (plainText.isEmpty) {
        return plainText;
      }

      final keyString = _getActiveKey();

      final keyBytes = _prepareKey(keyString);
      final ivBytes = _prepareIV(keyString);

      // Create key and IV
      final key = enc.Key(keyBytes);
      final iv = enc.IV(ivBytes);

      // Create encrypter with AES CBC mode
      final encrypter = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
      );

      // Encrypt and return Base64
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return encrypted.base64;
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Prepare key bytes - ensure proper length for AES
  /// Desktop uses the encryption key as-is, we need to ensure it's valid for AES
  static Uint8List _prepareKey(String keyString) {
    final keyBytes = utf8.encode(keyString);

    // AES supports 128, 192, or 256 bit keys (16, 24, or 32 bytes)
    if (keyBytes.length >= 32) {
      // Use first 32 bytes for AES-256
      return Uint8List.fromList(keyBytes.sublist(0, 32));
    } else if (keyBytes.length >= 24) {
      // Use first 24 bytes for AES-192
      return Uint8List.fromList(keyBytes.sublist(0, 24));
    } else if (keyBytes.length >= 16) {
      // Use first 16 bytes for AES-128
      return Uint8List.fromList(keyBytes.sublist(0, 16));
    } else {
      // Pad with zeros to 16 bytes for AES-128
      final paddedKey = Uint8List(16);
      paddedKey.setRange(0, keyBytes.length, keyBytes);
      return paddedKey;
    }
  }

  /// Prepare IV bytes - AES requires 16 bytes for CBC mode
  /// Desktop uses same string as key for IV
  static Uint8List _prepareIV(String ivString) {
    final ivBytes = utf8.encode(ivString);

    // IV for AES-CBC must be exactly 16 bytes
    if (ivBytes.length >= 16) {
      return Uint8List.fromList(ivBytes.sublist(0, 16));
    } else {
      // Pad with zeros to 16 bytes
      final paddedIV = Uint8List(16);
      paddedIV.setRange(0, ivBytes.length, ivBytes);
      return paddedIV;
    }
  }

  /// Verify if a password matches the encrypted password
  static bool verifyPassword(String plainPassword, String encryptedPassword) {
    try {
      final decrypted = decrypt(encryptedPassword);
      return plainPassword == decrypted;
    } catch (e) {
      return false;
    }
  }
}
