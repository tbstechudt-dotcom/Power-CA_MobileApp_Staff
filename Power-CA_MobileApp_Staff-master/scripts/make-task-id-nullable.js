/**
 * Make task_id column NULLABLE in taskchecklist table
 *
 * Issue: Desktop database has 3 taskchecklist records with task_id=NULL (0.10%)
 * Supabase has NOT NULL constraint, causing sync failures
 *
 * Solution: Make task_id NULLABLE to mirror desktop behavior
 * (Same approach as FK constraint removal - mirror desktop data quality)
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

async function makeTaskIdNullable() {
  console.log('\n' + '='.repeat(80));
  console.log('MAKING task_id NULLABLE IN taskchecklist');
  console.log('='.repeat(80));
  console.log('\n⚠️  WARNING: This will allow NULL values in task_id column');
  console.log('   Desktop has 3 records (0.10%) with task_id=NULL');
  console.log('   Making column NULLABLE to mirror desktop behavior\n');

  const client = await pool.connect();

  try {
    // Check current constraint
    console.log('[INFO] Checking current constraint...');
    const checkResult = await client.query(`
      SELECT column_name, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist' AND column_name = 'task_id'
    `);

    if (checkResult.rows.length === 0) {
      console.log('  ✗ task_id column not found!');
      return false;
    }

    const currentNullable = checkResult.rows[0].is_nullable;
    console.log(`  → Current: task_id is ${currentNullable === 'YES' ? 'NULLABLE' : 'NOT NULL'}`);

    if (currentNullable === 'YES') {
      console.log('\n[INFO] task_id is already NULLABLE - no action needed');
      return true;
    }

    // Make column NULLABLE
    console.log('\n[INFO] Altering column to allow NULL...');
    await client.query('BEGIN');

    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN task_id DROP NOT NULL
    `);

    await client.query('COMMIT');
    console.log('  ✓ task_id is now NULLABLE');

    // Verify change
    const verifyResult = await client.query(`
      SELECT column_name, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist' AND column_name = 'task_id'
    `);

    console.log('\n' + '='.repeat(80));
    console.log('✓ VERIFICATION');
    console.log('='.repeat(80));
    console.log(`  task_id is now: ${verifyResult.rows[0].is_nullable === 'YES' ? 'NULLABLE ✓' : 'NOT NULL ✗'}`);
    console.log('\n✓ Sync should now work without NULL constraint violations');
    console.log('='.repeat(80));
    console.log('');

    return true;

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ ERROR:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

if (require.main === module) {
  makeTaskIdNullable()
    .then(() => {
      console.log('✓ Operation completed successfully');
      process.exit(0);
    })
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}

module.exports = makeTaskIdNullable;
