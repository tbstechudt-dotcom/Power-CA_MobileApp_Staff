/**
 * Clean up massive jobshead duplicates caused by DELETE+INSERT bug
 *
 * PROBLEM: jobshead was wrongly classified as mobile-only PK table
 * Each sync run added 24,568 records without deleting old ones
 * Result: 122,840 duplicate records (should be ~24,568)
 *
 * SOLUTION: Keep only the most recent record for each job_id
 */

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST || 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function cleanupDuplicates() {
  try {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     CLEANUP: jobshead Duplicate Records                   ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    // Step 1: Count current duplicates
    const beforeCount = await pool.query('SELECT COUNT(*) FROM jobshead');
    console.log(`[INFO] Current jobshead records: ${beforeCount.rows[0].count}`);

    const duplicateCheck = await pool.query(`
      SELECT job_id, COUNT(*) as count
      FROM jobshead
      GROUP BY job_id
      HAVING COUNT(*) > 1
      ORDER BY count DESC
      LIMIT 10
    `);

    console.log(`[INFO] Found ${duplicateCheck.rows.length} job_ids with duplicates`);
    console.log('\nSample duplicates:');
    duplicateCheck.rows.forEach(row => {
      console.log(`  job_id ${row.job_id}: ${row.count} copies`);
    });

    console.log('\n[WARN] This will delete all duplicate records, keeping only the most recent for each job_id');
    console.log('[WARN] Press Ctrl+C within 5 seconds to cancel...\n');

    await new Promise(resolve => setTimeout(resolve, 5000));

    // Step 2: Delete duplicates, keeping only the most recent record for each job_id
    console.log('[...] Removing duplicates...');

    const deleteResult = await pool.query(`
      DELETE FROM jobshead
      WHERE ctid IN (
        SELECT ctid
        FROM (
          SELECT
            ctid,
            ROW_NUMBER() OVER (
              PARTITION BY job_id
              ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST
            ) as rn
          FROM jobshead
        ) t
        WHERE rn > 1
      )
    `);

    console.log(`[OK] Deleted ${deleteResult.rowCount} duplicate records\n`);

    // Step 3: Verify cleanup
    const afterCount = await pool.query('SELECT COUNT(*) FROM jobshead');
    console.log(`[OK] Final jobshead records: ${afterCount.rows[0].count}`);

    const remainingDuplicates = await pool.query(`
      SELECT job_id, COUNT(*) as count
      FROM jobshead
      GROUP BY job_id
      HAVING COUNT(*) > 1
    `);

    if (remainingDuplicates.rows.length === 0) {
      console.log('[OK] No duplicate job_ids remaining! ✓\n');
    } else {
      console.log(`[WARN] Still have ${remainingDuplicates.rows.length} duplicate job_ids\n`);
    }

    // Step 4: Show summary
    const removed = parseInt(beforeCount.rows[0].count) - parseInt(afterCount.rows[0].count);
    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║              CLEANUP SUMMARY                               ║');
    console.log('╚═══════════════════════════════════════════════════════════╝');
    console.log(`Before:  ${beforeCount.rows[0].count} records`);
    console.log(`After:   ${afterCount.rows[0].count} records`);
    console.log(`Removed: ${removed} duplicate records`);
    console.log('');

    await pool.end();
    process.exit(0);

  } catch (error) {
    console.error('\n[ERROR] Cleanup failed:', error.message);
    console.error(error.stack);
    await pool.end();
    process.exit(1);
  }
}

cleanupDuplicates();
