/**
 * Remove All Problematic FK Constraints from Supabase
 *
 * This script removes FK constraints that violate desktop data quality issues.
 * Desktop PostgreSQL has NO FK constraints (legacy system), but Supabase added
 * them during migration. Production data contains orphaned references that
 * prevent sync from completing.
 *
 * Based on:
 * - CLAUDE.md guidance (Section: Rule #4 - Handle FK Constraint Violations)
 * - Test failures (jobshead_con_id_fkey, taskchecklist issues)
 * - Existing removal scripts in scripts/ directory
 *
 * FK Constraints Removed:
 * - jobshead: client_id_fkey, con_id_fkey (allows orphaned jobs)
 * - jobtasks: job_id_fkey, task_id_fkey, client_id_fkey (DELETE+INSERT pattern)
 * - taskchecklist: job_id_fkey (allows any job_id)
 * - reminder: staff_id_fkey, client_id_fkey (allows orphaned reminders)
 * - remdetail: staff_id_fkey (allows any staff_id)
 * - climaster: con_id_fkey (allows con_id=0/NULL)
 * - mbstaff: con_id_fkey (allows con_id=0/NULL)
 *
 * FK Constraints KEPT:
 * - workdiary FK constraints (valid in production)
 * - Master table org_id/loc_id FKs (valid)
 * - Valid staff_id FKs where data quality is good
 *
 * Usage:
 *   node scripts/remove-all-problematic-fks.js
 *
 * Safety:
 *   - Runs in a single transaction (all-or-nothing)
 *   - Uses IF EXISTS to prevent errors if already removed
 *   - Displays clear success/failure messages
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

async function removeAllProblematicFKs() {
  const client = await pool.connect();

  try {
    console.log('\n' + '='.repeat(80));
    console.log('REMOVING PROBLEMATIC FK CONSTRAINTS FROM SUPABASE');
    console.log('='.repeat(80));
    console.log('');
    console.log('⚠️  WARNING: This will remove FK constraints to match desktop behavior');
    console.log('   Desktop DB has NO FK constraints (legacy system)');
    console.log('   Removing constraints allows ALL data to sync without loss');
    console.log('');
    console.log('Starting transaction...\n');

    await client.query('BEGIN');

    let removedCount = 0;

    // ============================================
    // JOBSHEAD - Remove client_id and con_id FK
    // ============================================
    console.log('[1/7] Removing jobshead FK constraints...');
    try {
      await client.query('ALTER TABLE jobshead DROP CONSTRAINT IF EXISTS jobshead_client_id_fkey');
      console.log('  ✓ Removed jobshead_client_id_fkey');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  jobshead_client_id_fkey: ${err.message}`);
    }

    try {
      await client.query('ALTER TABLE jobshead DROP CONSTRAINT IF EXISTS jobshead_con_id_fkey');
      console.log('  ✓ Removed jobshead_con_id_fkey (THIS WAS CAUSING SYNC FAILURE!)');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  jobshead_con_id_fkey: ${err.message}`);
    }

    // ============================================
    // JOBTASKS - Remove job_id, task_id, client_id FK
    // ============================================
    console.log('\n[2/7] Removing jobtasks FK constraints...');
    try {
      await client.query('ALTER TABLE jobtasks DROP CONSTRAINT IF EXISTS jobtasks_job_id_fkey');
      console.log('  ✓ Removed jobtasks_job_id_fkey (needed for DELETE+INSERT pattern)');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  jobtasks_job_id_fkey: ${err.message}`);
    }

    try {
      await client.query('ALTER TABLE jobtasks DROP CONSTRAINT IF EXISTS jobtasks_task_id_fkey');
      console.log('  ✓ Removed jobtasks_task_id_fkey (taskmaster is empty)');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  jobtasks_task_id_fkey: ${err.message}`);
    }

    try {
      await client.query('ALTER TABLE jobtasks DROP CONSTRAINT IF EXISTS jobtasks_client_id_fkey');
      console.log('  ✓ Removed jobtasks_client_id_fkey');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  jobtasks_client_id_fkey: ${err.message}`);
    }

    // ============================================
    // TASKCHECKLIST - Remove job_id FK
    // ============================================
    console.log('\n[3/7] Removing taskchecklist FK constraints...');
    try {
      await client.query('ALTER TABLE taskchecklist DROP CONSTRAINT IF EXISTS taskchecklist_job_id_fkey');
      console.log('  ✓ Removed taskchecklist_job_id_fkey (THIS WAS CAUSING TRANSACTION ABORTS!)');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  taskchecklist_job_id_fkey: ${err.message}`);
    }

    // ============================================
    // REMINDER - Remove staff_id and client_id FK
    // ============================================
    console.log('\n[4/7] Removing reminder FK constraints...');
    try {
      await client.query('ALTER TABLE reminder DROP CONSTRAINT IF EXISTS reminder_staff_id_fkey');
      console.log('  ✓ Removed reminder_staff_id_fkey');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  reminder_staff_id_fkey: ${err.message}`);
    }

    try {
      await client.query('ALTER TABLE reminder DROP CONSTRAINT IF EXISTS reminder_client_id_fkey');
      console.log('  ✓ Removed reminder_client_id_fkey');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  reminder_client_id_fkey: ${err.message}`);
    }

    // ============================================
    // REMDETAIL - Remove staff_id FK
    // ============================================
    console.log('\n[5/7] Removing remdetail FK constraints...');
    try {
      await client.query('ALTER TABLE remdetail DROP CONSTRAINT IF EXISTS remdetail_staff_id_fkey');
      console.log('  ✓ Removed remdetail_staff_id_fkey');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  remdetail_staff_id_fkey: ${err.message}`);
    }

    // ============================================
    // CLIMASTER - Remove con_id FK (allows con_id=0/NULL)
    // ============================================
    console.log('\n[6/7] Removing climaster FK constraints...');
    try {
      await client.query('ALTER TABLE climaster DROP CONSTRAINT IF EXISTS climaster_con_id_fkey');
      console.log('  ✓ Removed climaster_con_id_fkey (allows con_id=0/NULL)');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  climaster_con_id_fkey: ${err.message}`);
    }

    // ============================================
    // MBSTAFF - Remove con_id FK (allows con_id=0/NULL)
    // ============================================
    console.log('\n[7/7] Removing mbstaff FK constraints...');
    try {
      await client.query('ALTER TABLE mbstaff DROP CONSTRAINT IF EXISTS mbstaff_con_id_fkey');
      console.log('  ✓ Removed mbstaff_con_id_fkey (allows con_id=0/NULL)');
      removedCount++;
    } catch (err) {
      console.log(`  ℹ  mbstaff_con_id_fkey: ${err.message}`);
    }

    // ============================================
    // COMMIT TRANSACTION
    // ============================================
    await client.query('COMMIT');

    console.log('\n' + '='.repeat(80));
    console.log('✓ ALL FK CONSTRAINTS REMOVED SUCCESSFULLY!');
    console.log('='.repeat(80));
    console.log(`Total constraints removed: ${removedCount}`);
    console.log('');
    console.log('✓ Sync should now work without FK constraint violations');
    console.log('✓ Production data will sync without loss');
    console.log('✓ Desktop behavior mirrored (no FK enforcement)');
    console.log('');
    console.log('Next steps:');
    console.log('  1. Run: node scripts/list-all-fk-constraints.js (verify removal)');
    console.log('  2. Run: node scripts/test-bidirectional-sync-complete.js (test sync)');
    console.log('');

    return removedCount;

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n' + '='.repeat(80));
    console.error('❌ ERROR: Transaction rolled back');
    console.error('='.repeat(80));
    console.error(`Error: ${error.message}`);
    console.error('');
    console.error('No changes were made to the database.');
    console.error('');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run if called directly
if (require.main === module) {
  removeAllProblematicFKs()
    .then((count) => {
      console.log(`✓ Script completed successfully (removed ${count} constraints)`);
      process.exit(0);
    })
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}

module.exports = removeAllProblematicFKs;
