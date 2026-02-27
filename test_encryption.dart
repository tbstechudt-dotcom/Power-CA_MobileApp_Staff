// Quick test to verify encryption/decryption works with actual mbstaff data
// Run this with: dart test_encryption.dart

import 'lib/core/utils/crypto_service.dart';

void main() {
  print('🔐 Testing PowerCA Encryption/Decryption');
  print('=' * 50);

  // Sample encrypted passwords from your mbstaff table
  final testCases = [
    {
      'username': 'MM',
      'encrypted': '&N&M\$I A',
      'expected': null, // We don't know the plain password yet
    },
    {
      'username': 'TSM',
      'encrypted': '\x16-"F#F&N&L A\x10!\x13&\x13&\x10"',
      'expected': null,
    },
    {
      'username': 'ASVITHA',
      'encrypted': '&N&M\$I A',
      'expected': null,
    },
  ];

  print('\nEncryption Key: ${CryptoService.encryptionKey}');
  print('Key Length: ${CryptoService.encryptionKey.length} characters\n');

  for (var testCase in testCases) {
    print('Testing user: ${testCase['username']}');
    print('Encrypted: ${testCase['encrypted']}');

    try {
      final decrypted = CryptoService.decrypt(testCase['encrypted'] as String);
      print('✅ Decrypted: "$decrypted"');

      // Try to re-encrypt to verify round-trip
      final reEncrypted = CryptoService.encrypt(decrypted);
      print('Re-encrypted: $reEncrypted');

      final match = reEncrypted == testCase['encrypted'];
      print('Round-trip match: ${match ? "✅ YES" : "⚠️ NO (expected for CBC with random IV)"}');
    } catch (e) {
      print('❌ Error: $e');
    }

    print('-' * 50);
  }

  print('\n🎯 Test encrypt/decrypt round-trip with custom text:');
  const testPassword = 'TestPassword123';
  print('Original: "$testPassword"');

  try {
    final encrypted = CryptoService.encrypt(testPassword);
    print('Encrypted: $encrypted');

    final decrypted = CryptoService.decrypt(encrypted);
    print('Decrypted: "$decrypted"');

    final match = decrypted == testPassword;
    print('Match: ${match ? "✅ SUCCESS" : "❌ FAILED"}');
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n${'=' * 50}');
  print('✅ Encryption test complete!');
  print('\nNext step: Run the app and test sign-in with actual credentials.');
}
