const { Pool } = require('pg');

const pool = new Pool({
  host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Powerca@2025',
  ssl: { rejectUnauthorized: false }
});

async function testAuth() {
  try {
    // Get user from database
    const result = await pool.query(`
      SELECT staff_id, name, app_username, app_pw,
             length(app_pw) as pw_length,
             encode(app_pw::bytea, 'hex') as pw_hex
      FROM mbstaff
      WHERE app_username = 'MM'
    `);

    const user = result.rows[0];
    console.log('=== Database User ===');
    console.log('Username:', user.app_username);
    console.log('Password:', JSON.stringify(user.app_pw));
    console.log('Password Length:', user.pw_length);
    console.log('Password (bytes):', user.pw_hex);
    console.log('');

    // Test password comparisons
    const testPasswords = [
      '&N&M$I A',
      '&N&M$I A',  // with space
      '&N&M$I A ',  // with trailing space
      ' &N&M$I A',  // with leading space
    ];

    console.log('=== Password Comparison Tests ===');
    testPasswords.forEach((testPw, i) => {
      const match = testPw === user.app_pw;
      console.log(`Test ${i + 1}: ${JSON.stringify(testPw)} - ${match ? '✓ MATCH' : '✗ NO MATCH'}`);
    });

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

testAuth();
