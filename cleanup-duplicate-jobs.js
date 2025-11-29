const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function cleanupDuplicates() {
  try {
    console.log('[INFO] Cleaning up duplicate jobs...\n');

    // Count duplicates before cleanup
    const beforeCount = await pool.query(`
      SELECT COUNT(*) as total FROM jobshead
    `);
    console.log(`Total records before cleanup: ${beforeCount.rows[0].total}`);

    // Find how many duplicates exist
    const duplicateCount = await pool.query(`
      SELECT SUM(count - 1) as duplicates
      FROM (
        SELECT job_id, COUNT(*) as count
        FROM jobshead
        GROUP BY job_id
        HAVING COUNT(*) > 1
      ) sub
    `);
    console.log(`Duplicate records to remove: ${duplicateCount.rows[0].duplicates || 0}`);

    // Delete duplicates keeping one of each job_id
    // Using ctid (PostgreSQL internal row identifier) to identify unique rows
    const deleteResult = await pool.query(`
      DELETE FROM jobshead
      WHERE ctid NOT IN (
        SELECT MIN(ctid)
        FROM jobshead
        GROUP BY job_id
      )
    `);

    console.log(`\nDeleted ${deleteResult.rowCount} duplicate records`);

    // Count after cleanup
    const afterCount = await pool.query(`
      SELECT COUNT(*) as total FROM jobshead
    `);
    console.log(`Total records after cleanup: ${afterCount.rows[0].total}`);

    // Verify no more duplicates
    const verifyDuplicates = await pool.query(`
      SELECT job_id, COUNT(*) as count
      FROM jobshead
      GROUP BY job_id
      HAVING COUNT(*) > 1
      LIMIT 5
    `);

    if (verifyDuplicates.rows.length === 0) {
      console.log('\n[OK] All duplicates removed successfully!');
    } else {
      console.log('\n[WARN] Some duplicates still exist:');
      verifyDuplicates.rows.forEach(row => {
        console.log(`  - job_id ${row.job_id}: ${row.count} copies`);
      });
    }

    // Check specific job
    const verifyJob = await pool.query(`
      SELECT COUNT(*) as count FROM jobshead WHERE job_uid = '62510-002'
    `);
    console.log(`\nRecords with job_uid = 62510-002: ${verifyJob.rows[0].count}`);

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
  }
}

cleanupDuplicates();
