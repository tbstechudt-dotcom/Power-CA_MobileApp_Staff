/**
 * Fix constraints for reminder and remdetail tables
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

async function fixConstraints() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(70));
    console.log('FIXING REMINDER AND REMDETAIL CONSTRAINTS');
    console.log('='.repeat(70));

    await client.query('BEGIN');

    // 1. Make client_id nullable in reminder
    console.log('\n1. Making client_id nullable in reminder...');
    await client.query(`
      ALTER TABLE reminder
      ALTER COLUMN client_id DROP NOT NULL
    `);
    console.log('   ✓ client_id is now nullable');

    // 2. Remove staff_id FK from remdetail
    console.log('\n2. Removing staff_id FK from remdetail...');
    await client.query(`
      ALTER TABLE remdetail
      DROP CONSTRAINT IF EXISTS remdetail_staff_id_fkey
    `);
    console.log('   ✓ staff_id FK constraint removed');

    await client.query('COMMIT');

    console.log('\n' + '='.repeat(70));
    console.log('✓ CONSTRAINT FIXES COMPLETE!');
    console.log('='.repeat(70));
    console.log('\nreminder table can now accept:');
    console.log('  - Records with NULL client_id');
    console.log('\nremdetail table can now accept:');
    console.log('  - Records with invalid staff_id');
    console.log('\nReady to sync reminder and remdetail!');
    console.log('='.repeat(70));

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

fixConstraints();
