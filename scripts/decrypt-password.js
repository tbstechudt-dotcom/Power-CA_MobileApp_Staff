const crypto = require('crypto');

// Encryption configuration
const ENCRYPTION_KEY = 'PCASVR-29POWERCA';
const ALGORITHM = 'aes-128-cbc';

/**
 * Decrypt password using AES-128-CBC
 * @param {string} encryptedPassword - Base64 encoded encrypted password
 * @returns {string|null} - Decrypted password or null if decryption fails
 */
function decryptPassword(encryptedPassword) {
  try {
    console.log('\n=== Decryption Process ===');
    console.log('Encrypted password (raw):', encryptedPassword);
    console.log('Encrypted password length:', encryptedPassword.length);
    console.log('Encryption key:', ENCRYPTION_KEY);

    // The key must be exactly 16 bytes for AES-128
    const keyBuffer = Buffer.from(ENCRYPTION_KEY.substring(0, 16), 'utf-8');
    console.log('Key buffer length:', keyBuffer.length);

    // Decode the base64 encrypted password
    console.log('\nAttempting Base64 decode...');
    const encryptedBuffer = Buffer.from(encryptedPassword, 'base64');
    console.log('Encrypted buffer:', encryptedBuffer);
    console.log('Encrypted buffer length:', encryptedBuffer.length);

    // Extract IV (first 16 bytes) and encrypted data (rest)
    if (encryptedBuffer.length < 16) {
      console.log('ERROR: Encrypted buffer too short (< 16 bytes)');
      return null;
    }

    const iv = encryptedBuffer.slice(0, 16);
    const encryptedData = encryptedBuffer.slice(16);

    console.log('\nIV:', iv);
    console.log('IV length:', iv.length);
    console.log('Encrypted data:', encryptedData);
    console.log('Encrypted data length:', encryptedData.length);

    // Create decipher
    const decipher = crypto.createDecipheriv(ALGORITHM, keyBuffer, iv);
    decipher.setAutoPadding(true);

    // Decrypt
    let decrypted = decipher.update(encryptedData, undefined, 'utf8');
    decrypted += decipher.final('utf8');

    console.log('\n✅ Decryption successful!');
    console.log('Decrypted password:', decrypted);

    return decrypted;
  } catch (error) {
    console.log('\n❌ Decryption failed!');
    console.log('Error:', error.message);
    console.log('Error stack:', error.stack);
    return null;
  }
}

// Test with MM's password
const mmEncryptedPassword = '&N&M$I A';
console.log('Testing decryption for user MM');
console.log('================================');
const decrypted = decryptPassword(mmEncryptedPassword);

if (decrypted) {
  console.log(`\n✅ SUCCESS: The password for user MM is: "${decrypted}"`);
} else {
  console.log('\n❌ FAILED: Could not decrypt password');
  console.log('\nPossible reasons:');
  console.log('1. Password is not Base64 encoded');
  console.log('2. Password uses different encryption method');
  console.log('3. Password data is corrupted');
  console.log('4. Encryption key is incorrect');

  // Try to check if it's valid Base64
  console.log('\n=== Checking Base64 Validity ===');
  try {
    const decoded = Buffer.from(mmEncryptedPassword, 'base64').toString('utf8');
    console.log('Decoded as UTF-8:', decoded);
    console.log('Original matches decoded:', mmEncryptedPassword === decoded);
  } catch (e) {
    console.log('Not valid Base64:', e.message);
  }
}
