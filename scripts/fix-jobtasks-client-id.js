/**
 * Fix jobtasks client_id constraint
 * Make client_id nullable to match desktop database
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

async function fixClientIdConstraint() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(70));
    console.log('FIXING jobtasks client_id CONSTRAINT');
    console.log('='.repeat(70));

    // Check current constraint
    console.log('\n1. Checking current client_id constraint...');
    const checkConstraint = await client.query(`
      SELECT
        column_name,
        is_nullable,
        column_default,
        data_type
      FROM information_schema.columns
      WHERE table_name = 'jobtasks'
      AND column_name = 'client_id'
    `);

    if (checkConstraint.rows.length > 0) {
      const col = checkConstraint.rows[0];
      console.log(`   Column: ${col.column_name}`);
      console.log(`   Type: ${col.data_type}`);
      console.log(`   Nullable: ${col.is_nullable}`);
      console.log(`   Default: ${col.column_default || 'NULL'}`);
    } else {
      console.log('   ✓ client_id column does not exist in jobtasks');
      console.log('\n' + '='.repeat(70));
      console.log('NO CHANGES NEEDED');
      console.log('='.repeat(70));
      return;
    }

    // Make client_id nullable
    console.log('\n2. Making client_id nullable...');
    await client.query(`
      ALTER TABLE jobtasks
      ALTER COLUMN client_id DROP NOT NULL
    `);
    console.log('   ✓ client_id is now nullable');

    // Verify the change
    console.log('\n3. Verifying the change...');
    const verifyConstraint = await client.query(`
      SELECT
        column_name,
        is_nullable,
        column_default,
        data_type
      FROM information_schema.columns
      WHERE table_name = 'jobtasks'
      AND column_name = 'client_id'
    `);

    if (verifyConstraint.rows.length > 0) {
      const col = verifyConstraint.rows[0];
      console.log(`   Column: ${col.column_name}`);
      console.log(`   Type: ${col.data_type}`);
      console.log(`   Nullable: ${col.is_nullable}`);
      console.log(`   Default: ${col.column_default || 'NULL'}`);
    }

    console.log('\n' + '='.repeat(70));
    console.log('✓ CONSTRAINT FIX COMPLETE!');
    console.log('='.repeat(70));
    console.log('\njobtasks.client_id can now accept:');
    console.log('  - Valid client_id values');
    console.log('  - NULL values (for tasks without client assignment)');
    console.log('\nThis will allow tasks with NULL client_id to sync!');
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

fixClientIdConstraint();
