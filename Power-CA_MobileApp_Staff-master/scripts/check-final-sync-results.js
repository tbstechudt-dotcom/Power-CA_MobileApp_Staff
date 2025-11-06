/**
 * Check final sync results in Supabase
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
  database: process.env.SUPABASE_DB_NAME || 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkResults() {
  try {
    console.log('='.repeat(70));
    console.log('FINAL SYNC RESULTS - SUPABASE DATABASE');
    console.log('='.repeat(70));

    const tables = [
      'orgmaster',
      'locmaster',
      'conmaster',
      'climaster',
      'mbstaff',
      'jobshead',
      'jobtasks',
      'taskchecklist',
      'workdiary',
      'reminder',
      'remdetail',
      'learequest'
    ];

    console.log('\n📊 RECORD COUNTS:\n');

    let totalRecords = 0;

    for (const table of tables) {
      try {
        const result = await pool.query(`SELECT COUNT(*) as count FROM ${table}`);
        const count = parseInt(result.rows[0].count);
        totalRecords += count;

        const padding = ' '.repeat(20 - table.length);
        console.log(`  ${table}${padding}${count.toLocaleString()} records`);
      } catch (error) {
        console.log(`  ${table}${' '.repeat(20 - table.length)}ERROR: ${error.message}`);
      }
    }

    console.log('\n' + '-'.repeat(70));
    console.log(`  TOTAL${' '.repeat(15)}${totalRecords.toLocaleString()} records`);
    console.log('='.repeat(70));

    await pool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkResults();
