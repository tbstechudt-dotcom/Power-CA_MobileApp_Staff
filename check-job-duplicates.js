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

async function checkDuplicates() {
  try {
    console.log('[INFO] Checking for duplicate jobs...\n');

    // Check for duplicate job_uid values
    const duplicates = await pool.query(`
      SELECT job_uid, COUNT(*) as count
      FROM jobshead
      WHERE sporg_id = 2
      GROUP BY job_uid
      HAVING COUNT(*) > 1
      ORDER BY count DESC
      LIMIT 20
    `);

    console.log('Duplicate job_uid values (sporg_id = 2):');
    if (duplicates.rows.length === 0) {
      console.log('  No duplicates found by job_uid');
    } else {
      duplicates.rows.forEach(row => {
        console.log(`  - ${row.job_uid}: ${row.count} times`);
      });
    }

    // Check sample of the specific job
    const sample = await pool.query(`
      SELECT job_id, job_uid, job_status, sporg_id, client_id
      FROM jobshead
      WHERE job_uid = '62510-002' AND sporg_id = 2
      ORDER BY job_id
    `);

    console.log('\n\nRecords with job_uid = 62510-002 (sporg_id = 2):');
    sample.rows.forEach((row, idx) => {
      console.log(`${idx + 1}. job_id: ${row.job_id}, job_uid: ${row.job_uid}, status: ${row.job_status}, sporg_id: ${row.sporg_id}, client_id: ${row.client_id}`);
    });

    // Check total count
    const totalCount = await pool.query(`
      SELECT COUNT(*) as total FROM jobshead WHERE sporg_id = 2
    `);
    console.log(`\nTotal jobs for sporg_id = 2: ${totalCount.rows[0].total}`);

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
  }
}

checkDuplicates();
