/**
 * PowerBuilder Encrypt/Decrypt Implementation
 *
 * PowerBuilder's old Encrypt() function uses a simple XOR cipher with the key.
 * Algorithm: Each character of the data is XORed with the corresponding character
 * of the key (repeating the key as needed).
 */

/**
 * PowerBuilder Encrypt - mimics PowerBuilder's Encrypt() function
 */
function pbEncrypt(data, key) {
  let result = '';
  for (let i = 0; i < data.length; i++) {
    const dataChar = data.charCodeAt(i);
    const keyChar = key.charCodeAt(i % key.length);
    const encryptedChar = dataChar ^ keyChar;
    result += String.fromCharCode(encryptedChar);
  }
  return result;
}

/**
 * PowerBuilder Decrypt - mimics PowerBuilder's Decrypt() function
 * (XOR encryption is symmetric, so decrypt is same as encrypt)
 */
function pbDecrypt(encrypted, key) {
  return pbEncrypt(encrypted, key); // XOR is symmetric
}

// Test with known values
const key = 'PCASVR-29POWERCA';
const plainText = 'TSMA';
const encryptedFromDB = '&N&M$I A';

console.log('=== PowerBuilder Encrypt/Decrypt Test ===\n');

console.log('Encryption Key:', key);
console.log('Plain Text Password:', plainText);
console.log('Encrypted from DB:', encryptedFromDB);
console.log('');

// Test encryption
console.log('--- Testing Encryption ---');
const encrypted = pbEncrypt(plainText, key);
console.log('Encrypted result:', encrypted);

// Show hex comparison
console.log('\nHex comparison:');
console.log('Encrypted result:', Array.from(encrypted).map(c =>
  `0x${c.charCodeAt(0).toString(16).padStart(2, '0')}`
).join(' '));
console.log('Expected from DB:', Array.from(encryptedFromDB).map(c =>
  `0x${c.charCodeAt(0).toString(16).padStart(2, '0')}`
).join(' '));

const matches = encrypted === encryptedFromDB;
console.log(`\nEncryption matches DB: ${matches ? '✅ YES' : '❌ NO'}`);
console.log('');

// Test decryption
console.log('--- Testing Decryption ---');
const decrypted = pbDecrypt(encryptedFromDB, key);
console.log('Decrypted result:', decrypted);
console.log('Expected:', plainText);

const decryptMatches = decrypted === plainText;
console.log(`\nDecryption correct: ${decryptMatches ? '✅ YES' : '❌ NO'}`);
console.log('');

// Test with other users
console.log('--- Testing with TSM (longer password) ---');
const tsmEncrypted = '\u0016-"F#F&N&L A\u0010!\u0013&\u0013&\u0010"';
const tsmDecrypted = pbDecrypt(tsmEncrypted, key);
console.log('TSM encrypted:', tsmEncrypted);
console.log('TSM decrypted:', tsmDecrypted);
console.log('TSM decrypted (printable):', tsmDecrypted.split('').every(c => {
  const code = c.charCodeAt(0);
  return code >= 32 && code <= 126;
}));
