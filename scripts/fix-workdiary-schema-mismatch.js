/**
 * Fix ALL schema mismatches in Supabase workdiary table
 *
 * Issue: Many columns are NULLABLE in Desktop but NOT NULL in Supabase
 * This causes staging table INSERT to fail when Desktop has NULL values
 *
 * Desktop NULLABLE → Supabase NOT NULL:
 * - org_id: NULLABLE → NOT NULL
 * - con_id: NULLABLE → NOT NULL
 * - loc_id: NULLABLE → NOT NULL
 * - staff_id: NULLABLE → NOT NULL
 * - job_id: NULLABLE → NOT NULL
 * - task_id: NULLABLE → NOT NULL
 *
 * Solution: Make all these columns NULLABLE to mirror Desktop schema
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

async function fixWorkdiarySchema() {
  try {
    console.log('\n' + '='.repeat(80));
    console.log('FIXING WORKDIARY SCHEMA MISMATCHES');
    console.log('='.repeat(80));
    console.log('\n⚠️  WARNING: Making columns NULLABLE to match Desktop schema');
    console.log('   Desktop has these columns as NULLABLE');
    console.log('   Supabase currently has them as NOT NULL\n');

    const columnsToFix = ['org_id', 'con_id', 'loc_id', 'staff_id', 'job_id', 'task_id'];

    // Check current state
    console.log('[Step 1] Checking current column constraints...');
    const checkResult = await pool.query(`
      SELECT column_name, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'workdiary'
        AND column_name IN (${columnsToFix.map((_, i) => `$${i + 1}`).join(', ')})
      ORDER BY ordinal_position
    `, columnsToFix);

    console.log('\nCurrent state:');
    checkResult.rows.forEach(col => {
      const status = col.is_nullable === 'YES' ? '✅ NULLABLE' : '❌ NOT NULL';
      console.log(`  ${col.column_name}: ${status}`);
    });

    // Fix each column
    console.log('\n[Step 2] Making columns NULLABLE...');
    for (const col of columnsToFix) {
      const current = checkResult.rows.find(r => r.column_name === col);

      if (!current) {
        console.log(`  ⚠️  ${col}: Column not found, skipping`);
        continue;
      }

      if (current.is_nullable === 'YES') {
        console.log(`  ✓ ${col}: Already NULLABLE, skipping`);
        continue;
      }

      console.log(`  → ${col}: Making NULLABLE...`);
      await pool.query(`ALTER TABLE workdiary ALTER COLUMN ${col} DROP NOT NULL`);
      console.log(`    ✓ ${col} is now NULLABLE`);
    }

    // Verify changes
    console.log('\n[Step 3] Verifying changes...');
    const verify = await pool.query(`
      SELECT column_name, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'workdiary'
        AND column_name IN (${columnsToFix.map((_, i) => `$${i + 1}`).join(', ')})
      ORDER BY ordinal_position
    `, columnsToFix);

    console.log('\nFinal state:');
    verify.rows.forEach(col => {
      const status = col.is_nullable === 'YES' ? '✅ NULLABLE' : '❌ NOT NULL';
      console.log(`  ${col.column_name}: ${status}`);
    });

    const allNullable = verify.rows.every(r => r.is_nullable === 'YES');

    console.log('\n' + '='.repeat(80));
    if (allNullable) {
      console.log('✅ SUCCESS: All columns are now NULLABLE!');
    } else {
      console.log('⚠️  WARNING: Some columns are still NOT NULL');
    }
    console.log('='.repeat(80));
    console.log('\nSync should now work - all columns match Desktop schema');
    console.log('');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  fixWorkdiarySchema()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}

module.exports = fixWorkdiarySchema;
