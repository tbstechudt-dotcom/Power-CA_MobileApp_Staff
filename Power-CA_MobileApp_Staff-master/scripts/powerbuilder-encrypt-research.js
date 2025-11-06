/**
 * PowerBuilder Old Encrypt() Algorithm Research
 *
 * Testing different algorithms to match the encryption pattern
 */

const key = 'PCASVR-29POWERCA';
const plainText = 'TSMA';
const encrypted = '&N&M$I A';

console.log('Target:');
console.log(`Plain: "${plainText}"`);
console.log(`Encrypted: "${encrypted}"`);
console.log('');

// Convert to character codes for analysis
const plainCodes = Array.from(plainText).map(c => c.charCodeAt(0));
const encryptedCodes = Array.from(encrypted).map(c => c.charCodeAt(0));
const keyCodes = Array.from(key).map(c => c.charCodeAt(0));

console.log('Character codes:');
console.log('Plain:', plainCodes, '→', plainText.split('').map((c, i) => `${c}(${plainCodes[i]})`).join(' '));
console.log('Encrypted:', encryptedCodes, '→', encrypted.split('').map((c, i) => `${c}(${encryptedCodes[i]})`).join(' '));
console.log('Key (first 8):', keyCodes.slice(0, 8), '→', key.slice(0, 8).split('').map((c, i) => `${c}(${keyCodes[i]})`).join(' '));
console.log('');

// Analysis: encrypted is 8 chars, plain is 4 chars
// This suggests each plain char produces 2 encrypted chars

console.log('=== Pattern Analysis ===');
console.log('Plain length:', plainText.length);
console.log('Encrypted length:', encrypted.length);
console.log('Ratio:', encrypted.length / plainText.length);
console.log('');

// Try to find the pattern
console.log('=== Attempting to find pattern ===');

// Theory: Each character is encrypted into 2 bytes
for (let i = 0; i < plainText.length; i++) {
  const plainChar = plainText[i];
  const plainCode = plainChar.charCodeAt(0);
  const encryptedByte1 = encryptedCodes[i * 2];
  const encryptedByte2 = encryptedCodes[i * 2 + 1];

  console.log(`\nPlain[${i}]: '${plainChar}' (0x${plainCode.toString(16).padStart(2, '0')})`);
  console.log(`Encrypted[${i*2},${i*2+1}]: '${encrypted[i*2]}${encrypted[i*2+1]}' (0x${encryptedByte1.toString(16).padStart(2, '0')} 0x${encryptedByte2.toString(16).padStart(2, '0')})`);

  // Try various operations
  const keyChar1 = keyCodes[i * 2 % keyCodes.length];
  const keyChar2 = keyCodes[(i * 2 + 1) % keyCodes.length];

  console.log(`Key[${i*2 % keyCodes.length}, ${(i*2+1) % keyCodes.length}]: (0x${keyChar1.toString(16).padStart(2, '0')} 0x${keyChar2.toString(16).padStart(2, '0')})`);

  // Test XOR
  const xor1 = plainCode ^ keyChar1;
  const xor2 = plainCode ^ keyChar2;
  console.log(`XOR test: 0x${xor1.toString(16).padStart(2, '0')} 0x${xor2.toString(16).padStart(2, '0')} (doesn't match)`);

  // Test addition
  const add1 = (plainCode + keyChar1) & 0xFF;
  const add2 = (plainCode + keyChar2) & 0xFF;
  console.log(`ADD test: 0x${add1.toString(16).padStart(2, '0')} 0x${add2.toString(16).padStart(2, '0')}`,
    add1 === encryptedByte1 && add2 === encryptedByte2 ? '✅ MATCH!' : '');

  // Test subtraction
  const sub1 = (plainCode - keyChar1) & 0xFF;
  const sub2 = (plainCode - keyChar2) & 0xFF;
  console.log(`SUB test: 0x${sub1.toString(16).padStart(2, '0')} 0x${sub2.toString(16).padStart(2, '0')}`,
    sub1 === encryptedByte1 && sub2 === encryptedByte2 ? '✅ MATCH!' : '');
}

// Try PowerBuilder-style encoding (high/low nibbles)
console.log('\n=== Testing Nibble Encoding ===');
for (let i = 0; i < plainText.length; i++) {
  const plainCode = plainText.charCodeAt(i);
  const highNibble = (plainCode >> 4) & 0x0F;
  const lowNibble = plainCode & 0x0F;

  const encrypted1 = encryptedCodes[i * 2];
  const encrypted2 = encryptedCodes[i * 2 + 1];

  console.log(`\nPlain '${plainText[i]}' (0x${plainCode.toString(16).padStart(2, '0')}):`);
  console.log(`  High nibble: 0x${highNibble.toString(16)}, Low nibble: 0x${lowNibble.toString(16)}`);
  console.log(`  Encrypted bytes: 0x${encrypted1.toString(16).padStart(2, '0')}, 0x${encrypted2.toString(16).padStart(2, '0')}`);

  // Try adding key to nibbles
  const keyCode1 = keyCodes[i * 2 % keyCodes.length];
  const keyCode2 = keyCodes[(i * 2 + 1) % keyCodes.length];

  const nibbleEncrypted1 = (highNibble + (keyCode1 & 0x0F)) & 0xFF;
  const nibbleEncrypted2 = (lowNibble + (keyCode2 & 0x0F)) & 0xFF;

  console.log(`  Nibble+Key test: 0x${nibbleEncrypted1.toString(16).padStart(2, '0')}, 0x${nibbleEncrypted2.toString(16).padStart(2, '0')}`);
}
