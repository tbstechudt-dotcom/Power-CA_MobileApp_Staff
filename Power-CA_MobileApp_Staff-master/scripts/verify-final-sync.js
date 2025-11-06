/**
 * Verify final sync results for all tables
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

async function verifySync() {
  try {
    console.log('='.repeat(70));
    console.log('FINAL SYNC VERIFICATION');
    console.log('='.repeat(70));

    const tables = [
      'orgmaster',
      'locmaster',
      'conmaster',
      'climaster',
      'cliunimaster',
      'taskmaster',
      'jobmaster',
      'mbstaff',
      'jobshead',
      'jobtasks',
      'taskchecklist',
      'reminder',
      'remdetail',
    ];

    console.log('\nRecord counts in Supabase:');
    console.log('-'.repeat(70));

    let totalRecords = 0;

    for (const table of tables) {
      const result = await pool.query(`SELECT COUNT(*) as count FROM ${table}`);
      const count = parseInt(result.rows[0].count);
      totalRecords += count;
      console.log(`  ${table.padEnd(20)} ${count.toString().padStart(10)} records`);
    }

    console.log('-'.repeat(70));
    console.log(`  ${'TOTAL'.padEnd(20)} ${totalRecords.toString().padStart(10)} records`);
    console.log('='.repeat(70));

    await pool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

verifySync();
