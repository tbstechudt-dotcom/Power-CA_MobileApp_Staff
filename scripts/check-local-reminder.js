/**
 * Check local reminder (mbreminder) data structure
 */

require('dotenv').config();
const { Pool } = require('pg');

const localPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkData() {
  try {
    console.log('='.repeat(70));
    console.log('LOCAL REMINDER (mbreminder) DATA');
    console.log('='.repeat(70));

    // Get columns
    const cols = await localPool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'mbreminder'
      ORDER BY ordinal_position
    `);

    console.log('\nColumns in local mbreminder:');
    cols.rows.forEach(r => console.log('  -', r.column_name));

    // Get sample records
    const sample = await localPool.query(`
      SELECT * FROM mbreminder LIMIT 3
    `);

    console.log('\nSample records:');
    console.log(JSON.stringify(sample.rows, null, 2));

    // Get count
    const count = await localPool.query('SELECT COUNT(*) as count FROM mbreminder');
    console.log('\nTotal records:', count.rows[0].count);

    console.log('\n' + '='.repeat(70));

    await localPool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkData();
