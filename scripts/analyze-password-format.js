// Analyze password encryption format

const passwords = [
  { user: 'MM (and 7 others)', encrypted: '&N&M$I A' },
  { user: 'TSM', encrypted: '\u0016-"F#F&N&L A\u0010!\u0013&\u0013&\u0010"' },
  { user: 'SIVAKUMAR', encrypted: '&M#F\'O A' },
];

console.log('=== Password Format Analysis ===\n');

passwords.forEach(({ user, encrypted }) => {
  console.log(`User: ${user}`);
  console.log(`Encrypted: "${encrypted}"`);
  console.log(`Length: ${encrypted.length} characters`);

  // Convert to hex
  const hexValues = [];
  for (let i = 0; i < encrypted.length; i++) {
    const charCode = encrypted.charCodeAt(i);
    hexValues.push(`0x${charCode.toString(16).padStart(2, '0')} (${encrypted[i]})`);
  }

  console.log('Hex values:', hexValues.join(', '));
  console.log('');
});

// Try XOR decryption with encryption key
console.log('\n=== Attempting XOR Decryption ===\n');

const ENCRYPTION_KEY = 'PCASVR-29POWERCA';

function xorDecrypt(encrypted, key) {
  let decrypted = '';
  for (let i = 0; i < encrypted.length; i++) {
    const encChar = encrypted.charCodeAt(i);
    const keyChar = key.charCodeAt(i % key.length);
    const decChar = encChar ^ keyChar;
    decrypted += String.fromCharCode(decChar);
  }
  return decrypted;
}

passwords.forEach(({ user, encrypted }) => {
  const decrypted = xorDecrypt(encrypted, ENCRYPTION_KEY);
  console.log(`User: ${user}`);
  console.log(`Encrypted: "${encrypted}"`);
  console.log(`XOR Decrypted: "${decrypted}"`);

  // Check if decrypted looks valid (printable ASCII)
  const isPrintable = decrypted.split('').every(c => {
    const code = c.charCodeAt(0);
    return code >= 32 && code <= 126;
  });
  console.log(`Valid printable ASCII: ${isPrintable}`);
  console.log('');
});

// Try simpler XOR with shorter key variations
console.log('\n=== Trying Key Variations ===\n');

const keyVariations = [
  'PCASVR-29POWERCA',
  'PCASVR',
  'POWERCA',
  'PCA',
];

const testPassword = '&N&M$I A';

keyVariations.forEach(key => {
  const decrypted = xorDecrypt(testPassword, key);
  const isPrintable = decrypted.split('').every(c => {
    const code = c.charCodeAt(0);
    return code >= 32 && code <= 126;
  });

  console.log(`Key: "${key}" (${key.length} chars)`);
  console.log(`Decrypted: "${decrypted}"`);
  console.log(`Valid: ${isPrintable}`);
  console.log('');
});
