/**
 * Check local taskchecklist data structure
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
    console.log('LOCAL TASKCHECKLIST DATA SAMPLE');
    console.log('='.repeat(70));

    // Get sample records
    const sample = await localPool.query(`
      SELECT * FROM taskchecklist LIMIT 5
    `);

    console.log('\nSample records:');
    console.log(JSON.stringify(sample.rows, null, 2));

    // Get count
    const count = await localPool.query('SELECT COUNT(*) as count FROM taskchecklist');
    console.log('\n\nTotal records:', count.rows[0].count);

    console.log('\n' + '='.repeat(70));

    await localPool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkData();
