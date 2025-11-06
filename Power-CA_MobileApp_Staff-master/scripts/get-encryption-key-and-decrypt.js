const { Pool } = require('pg');
const crypto = require('crypto');

// Desktop database configuration
const desktopPool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres',
  max: 5,
});

async function getEncryptionKeyAndDecrypt() {
  try {
    console.log('=== Retrieving Encryption Key ===\n');

    // Get encryption key from tbsregistration
    const keyResult = await desktopPool.query(`
      SELECT tbsrencryptpass FROM tbsregistration LIMIT 1;
    `);

    if (keyResult.rows.length === 0) {
      console.log('ERROR: No encryption key found in tbsregistration table');
      await desktopPool.end();
      return;
    }

    const encryptionKey = keyResult.rows[0].tbsrencryptpass;
    console.log(`Encryption Key: "${encryptionKey}"`);
    console.log(`Key Length: ${encryptionKey.length} characters\n`);

    // Get sample passwords
    console.log('=== Sample Encrypted Passwords ===\n');

    const passwords = await desktopPool.query(`
      SELECT app_username, app_pw
      FROM mbstaff
      WHERE app_username IN ('MM', 'TSM')
      ORDER BY app_username;
    `);

    passwords.rows.forEach(row => {
      console.log(`User: ${row.app_username}`);
      console.log(`Encrypted: "${row.app_pw}"`);
      console.log('');
    });

    // Try AES-128-CBC decryption with key as both key and IV (like PowerBuilder)
    console.log('=== Attempting AES-128-CBC Decryption (PowerBuilder style) ===\n');

    const testPassword = passwords.rows[0].app_pw;
    console.log(`Testing with MM's password: "${testPassword}"\n`);

    try {
      // PowerBuilder uses key as both key AND IV
      const keyBuffer = Buffer.from(encryptionKey.substring(0, 16), 'utf-8');
      const ivBuffer = Buffer.from(encryptionKey.substring(0, 16), 'utf-8');

      console.log('Key (hex):', keyBuffer.toString('hex'));
      console.log('IV (hex):', ivBuffer.toString('hex'));

      // Try to decode Base64
      console.log('\nAttempting Base64 decode...');
      const encryptedBuffer = Buffer.from(testPassword, 'base64');
      console.log('Decoded buffer:', encryptedBuffer);
      console.log('Decoded buffer length:', encryptedBuffer.length);

      if (encryptedBuffer.length >= 16) {
        const decipher = crypto.createDecipheriv('aes-128-cbc', keyBuffer, ivBuffer);
        decipher.setAutoPadding(true);

        let decrypted = decipher.update(encryptedBuffer, undefined, 'utf8');
        decrypted += decipher.final('utf8');

        console.log(`\n✅ SUCCESS: Decrypted password = "${decrypted}"`);
      } else {
        console.log(`\n❌ Buffer too short (${encryptedBuffer.length} bytes)`);
        console.log('Password is NOT Base64 AES-encrypted\n');

        // The password might be stored in a different format
        console.log('HYPOTHESIS: Passwords might be:');
        console.log('1. Using old/legacy encryption (not AES-CBC)');
        console.log('2. Plain text obfuscated with simple cipher');
        console.log('3. Encrypted with different PowerBuilder function\n');
      }
    } catch (error) {
      console.log(`\n❌ Decryption failed: ${error.message}`);
    }

    await desktopPool.end();
  } catch (error) {
    console.error('Error:', error.message);
    await desktopPool.end();
    process.exit(1);
  }
}

getEncryptionKeyAndDecrypt();
