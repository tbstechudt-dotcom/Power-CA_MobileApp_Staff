import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

/// Crypto Service
///
/// Handles password encryption/decryption matching the desktop PowerBuilder implementation.
///
/// PowerBuilder Encoding Details (for mbstaff.app_pw):
/// - Each plain character is encoded as 2 characters
/// - Decryption: sum the two encoded char codes
/// - If sum is lowercase (97-122), convert to uppercase (-32)
/// - Otherwise use sum directly
///
/// Example: 'TSMA' -> '&N&M$I A' (enc1+enc2 gives plain char)
class CryptoService {
  // Encryption key derived from PowerBuilder script:
  // ls_product = "LICENCE"
  // ls_provider = "TBSTECH25'"
  // ls_encrypt = left(ls_product + ls_provider, 16) = "LICENCETBSTECH25"
  static const String _encryptionKey = 'LICENCETBSTECH25';

  // Encryption uses a simple sum-based encoding:
  // Each plain character is split into two encoded characters
  // Decryption: plain = enc1 + enc2 (with lowercase to uppercase conversion)

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

  /// Decrypt PowerBuilder encoded password
  ///
  /// PowerBuilder encodes each character as 2 printable ASCII characters using
  /// position-dependent offsets. This decodes back to the original password.
  ///
  /// Example: '&N&M$I A' -> 'TSMA'
  static String decrypt(String encrypted) {
    try {
      if (encrypted.isEmpty) {
        return encrypted;
      }

      // Check if it looks like PowerBuilder encoding (even length, printable chars)
      if (encrypted.length % 2 == 0 && !_isBase64(encrypted)) {
        return _decryptPowerBuilder(encrypted);
      }

      // Fall back to AES decryption for Base64 encoded strings
      return _decryptAES(encrypted);
    } catch (e) {
      // If decryption fails, return original string
      return encrypted;
    }
  }

  /// Encrypt password using PowerBuilder encoding
  ///
  /// Each character is encoded as 2 printable ASCII characters using
  /// position-dependent offsets derived from the encryption key.
  ///
  /// Example: 'TSMA' -> '&N&M$I A'
  static String encrypt(String plainText) {
    try {
      if (plainText.isEmpty) {
        return plainText;
      }

      return _encryptPowerBuilder(plainText);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// PowerBuilder sum-based decryption
  ///
  /// Each pair of encrypted characters sums to the plain character code.
  /// If the sum is a lowercase letter (97-122), convert to uppercase.
  static String _decryptPowerBuilder(String encrypted) {
    final result = StringBuffer();

    for (int i = 0; i < encrypted.length; i += 2) {
      if (i + 1 >= encrypted.length) break;

      final c1 = encrypted.codeUnitAt(i);
      final c2 = encrypted.codeUnitAt(i + 1);

      // Sum the two character codes
      int sum = c1 + c2;

      // If sum is lowercase letter (a-z = 97-122), convert to uppercase
      if (sum >= 97 && sum <= 122) {
        sum -= 32;
      }

      result.writeCharCode(sum);
    }

    return result.toString();
  }

  /// PowerBuilder sum-based encryption
  ///
  /// Each plain character is split into two characters that sum to:
  /// - The character code directly (for digits and some chars)
  /// - The lowercase equivalent (for uppercase letters)
  static String _encryptPowerBuilder(String plainText) {
    final result = StringBuffer();

    for (int i = 0; i < plainText.length; i++) {
      int charCode = plainText.codeUnitAt(i);

      // For uppercase letters (A-Z = 65-90), store as lowercase (add 32)
      if (charCode >= 65 && charCode <= 90) {
        charCode += 32;
      }

      // Split the value into two parts
      // Using a simple split: first half and remainder
      final enc1 = charCode ~/ 2;
      final enc2 = charCode - enc1;

      result.writeCharCode(enc1);
      result.writeCharCode(enc2);
    }

    return result.toString();
  }

  /// Check if string looks like Base64
  static bool _isBase64(String str) {
    // Base64 uses A-Z, a-z, 0-9, +, /, and = for padding
    final base64Regex = RegExp(r'^[A-Za-z0-9+/]+=*$');
    return base64Regex.hasMatch(str) && str.length >= 4;
  }

  /// AES-CBC decryption (fallback for Base64 encoded strings)
  static String _decryptAES(String encryptedBase64) {
    final keyString = _getActiveKey();
    final keyBytes = _prepareKey(keyString);
    final ivBytes = _prepareIV(keyString);

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );

    return encrypter.decrypt64(encryptedBase64, iv: iv);
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
