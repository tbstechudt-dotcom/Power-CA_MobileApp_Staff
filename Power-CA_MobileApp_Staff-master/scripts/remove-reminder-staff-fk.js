/**
 * Remove staff_id FK constraint from reminder table
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
    console.log('REMOVING staff_id FK CONSTRAINT FROM reminder');
    console.log('='.repeat(70));

    console.log('\nRemoving staff_id FK constraint...');
    await client.query(`
      ALTER TABLE reminder
      DROP CONSTRAINT IF EXISTS reminder_staff_id_fkey
    `);

    console.log('✓ staff_id FK constraint removed');

    console.log('\n' + '='.repeat(70));
    console.log('✓ CONSTRAINT REMOVAL COMPLETE!');
    console.log('='.repeat(70));
    console.log('\nreminder table can now accept:');
    console.log('  - Valid staff_id references');
    console.log('  - Invalid staff_id values (data quality issue)');
    console.log('\nReady to sync reminder!');
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
