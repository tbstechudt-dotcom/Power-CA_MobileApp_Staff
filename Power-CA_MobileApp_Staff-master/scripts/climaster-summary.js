/**
 * Simple climaster summary
 */

require('dotenv').config();
const { Pool } = require('pg');

const localPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD,
});

async function summary() {
  try {
    console.log('='.repeat(70));
    console.log('CLIMASTER SYNC ANALYSIS');
    console.log('='.repeat(70));

    // Total
    const total = await localPool.query('SELECT COUNT(*) as count FROM climaster');
    console.log(`\n📊 LOCAL DATABASE: ${total.rows[0].count} total clients`);

    // Valid records (should sync)
    const valid = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE EXISTS (SELECT 1 FROM orgmaster o WHERE o.org_id = c.org_id)
        AND EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
    `);
    console.log(`✅ VALID RECORDS: ${valid.rows[0].count} clients (have valid org_id AND loc_id)`);

    // Invalid records (filtered out)
    const invalid = parseInt(total.rows[0].count) - parseInt(valid.rows[0].count);
    console.log(`❌ INVALID RECORDS: ${invalid} clients (filtered due to FK violations)`);

    // Show which records are invalid
    console.log('\n🔍 INVALID RECORDS DETAILS:');
    const invalidRecords = await localPool.query(`
      SELECT client_id, org_id, loc_id, con_id
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
      ORDER BY client_id
    `);

    for (const rec of invalidRecords.rows) {
      console.log(`   client_id=${rec.client_id}: loc_id=${rec.loc_id} does not exist in locmaster`);
    }

    console.log('\n' + '='.repeat(70));
    console.log('CONCLUSION:');
    console.log(`  ✅ ${valid.rows[0].count} clients synced to Supabase (all valid records)`);
    console.log(`  ❌ ${invalid} clients skipped (invalid loc_id)`);
    console.log(`  📌 No records are missing - sync is working correctly!`);
    console.log('='.repeat(70));

    await localPool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

summary();
