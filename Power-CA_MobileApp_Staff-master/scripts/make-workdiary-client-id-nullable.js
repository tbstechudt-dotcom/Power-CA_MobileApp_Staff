/**
 * Make client_id NULLABLE in Supabase workdiary table
 *
 * Issue: Desktop workdiary has NO client_id column
 * Supabase workdiary has client_id (numeric NOT NULL, no DEFAULT)
 * When sync creates staging table and omits client_id, it fails
 *
 * Solution: Make client_id NULLABLE to mirror desktop behavior
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function makeClientIdNullable() {
  try {
    console.log('\n' + '='.repeat(80));
    console.log('MAKING client_id NULLABLE IN workdiary');
    console.log('='.repeat(80));
    console.log('\n⚠️  WARNING: This will allow NULL values in client_id column');
    console.log('   Desktop workdiary has NO client_id column');
    console.log('   Making column NULLABLE to mirror desktop behavior\n');

    // Check current state
    console.log('[Step 1] Checking current client_id constraint...');
    const checkResult = await pool.query(`
      SELECT column_name, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'workdiary' AND column_name = 'client_id'
    `);

    if (checkResult.rows.length === 0) {
      console.log('\n[INFO] client_id column does not exist - no action needed');
      return true;
    }

    const currentNullable = checkResult.rows[0].is_nullable;
    const currentDefault = checkResult.rows[0].column_default;

    console.log(`  → Current: client_id is ${currentNullable === 'YES' ? 'NULLABLE' : 'NOT NULL'}`);
    console.log(`  → Current DEFAULT: ${currentDefault || 'none'}`);

    if (currentNullable === 'YES') {
      console.log('\n[INFO] client_id is already NULLABLE - no action needed');
      return true;
    }

    // Make client_id NULLABLE
    console.log('\n[Step 2] Making client_id NULLABLE...');
    await pool.query(`
      ALTER TABLE workdiary
      ALTER COLUMN client_id DROP NOT NULL
    `);
    console.log('  ✓ client_id is now NULLABLE');

    // Verify change
    console.log('\n[Step 3] Verifying...');
    const verify = await pool.query(`
      SELECT column_name, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'workdiary' AND column_name = 'client_id'
    `);

    console.log('  client_id column:');
    console.log('    - is_nullable:', verify.rows[0].is_nullable);
    console.log('    - column_default:', verify.rows[0].column_default || 'none');

    console.log('\n' + '='.repeat(80));
    console.log('✅ SUCCESS: client_id can now be NULL!');
    console.log('='.repeat(80));
    console.log('\nSync should now work - staging table can omit client_id');
    console.log('');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  makeClientIdNullable()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}

module.exports = makeClientIdNullable;
