const { Pool } = require('pg');

// Desktop database configuration
const desktopPool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres',
  max: 5,
});

async function checkEncryptionKey() {
  try {
    console.log('=== Checking Desktop Database ===\n');

    // Check if ds_encript_code table exists
    const tableCheck = await desktopPool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_name = 'ds_encript_code'
      );
    `);

    console.log('Table ds_encript_code exists:', tableCheck.rows[0].exists);

    if (!tableCheck.rows[0].exists) {
      // Try alternative table names
      console.log('\nSearching for encryption key in other tables...');

      const searchTables = await desktopPool.query(`
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name LIKE '%encr%'
        OR table_name LIKE '%code%'
        OR table_name LIKE '%key%'
        ORDER BY table_name;
      `);

      console.log('\nTables with "encr", "code", or "key" in name:');
      searchTables.rows.forEach(row => {
        console.log(`  - ${row.table_name}`);
      });

      // Also check for column with encryption key
      const searchColumns = await desktopPool.query(`
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE column_name LIKE '%encrypt%'
        OR column_name LIKE '%key%'
        ORDER BY table_name, column_name;
      `);

      console.log('\nColumns with "encrypt" or "key" in name:');
      searchColumns.rows.forEach(row => {
        console.log(`  - ${row.table_name}.${row.column_name}`);
      });
    } else {
      // Query the encryption key
      const result = await desktopPool.query(`
        SELECT * FROM ds_encript_code;
      `);

      console.log(`\nEncryption key from ds_encript_code:`);
      console.log(result.rows);
    }

    // Also check a sample password from desktop
    console.log('\n=== Checking Sample Passwords from Desktop DB ===\n');

    const passwords = await desktopPool.query(`
      SELECT app_username, app_pw, LENGTH(app_pw) as pw_length
      FROM mbstaff
      WHERE app_username IN ('MM', 'TSM')
      ORDER BY app_username;
    `);

    passwords.rows.forEach(row => {
      console.log(`User: ${row.app_username}`);
      console.log(`Password: "${row.app_pw}"`);
      console.log(`Length: ${row.pw_length} characters`);

      // Check if it looks like Base64
      const isValidBase64 = /^[A-Za-z0-9+/]*={0,2}$/.test(row.app_pw);
      console.log(`Valid Base64 format: ${isValidBase64}`);
      console.log('');
    });

    await desktopPool.end();
  } catch (error) {
    console.error('Error:', error.message);
    await desktopPool.end();
    process.exit(1);
  }
}

checkEncryptionKey();
