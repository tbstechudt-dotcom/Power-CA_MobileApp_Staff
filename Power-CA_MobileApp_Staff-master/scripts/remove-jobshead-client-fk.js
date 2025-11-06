/**
 * Remove client_id FK constraint from jobshead
 * This allows jobs to reference non-existent clients
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

async function removeFKConstraint() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(70));
    console.log('REMOVING client_id FK CONSTRAINT FROM jobshead');
    console.log('='.repeat(70));

    console.log('\nRemoving client_id FK constraint...');
    await client.query(`
      ALTER TABLE jobshead
      DROP CONSTRAINT IF EXISTS jobshead_client_id_fkey
    `);

    console.log('✓ client_id FK constraint removed');

    console.log('\n' + '='.repeat(70));
    console.log('✓ CONSTRAINT REMOVAL COMPLETE!');
    console.log('='.repeat(70));
    console.log('\njobshead table can now accept:');
    console.log('  - Valid client_id references');
    console.log('  - Invalid client_id values (orphaned jobs)');
    console.log('\nThis will allow ALL 24,568 jobs to sync!');
    console.log('(Previously filtered 3,942 jobs will now sync)');
    console.log('='.repeat(70));

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

removeFKConstraint();
