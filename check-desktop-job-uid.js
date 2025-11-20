const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkDesktopJobUid() {
  try {
    // Check column info
    const columnInfo = await pool.query(`
      SELECT column_name, data_type, character_maximum_length
      FROM information_schema.columns
      WHERE table_name = 'jobshead' AND column_name = 'job_uid'
    `);

    if (columnInfo.rows.length > 0) {
      console.log('[OK] job_uid column exists in desktop database');
      console.log(`    Type: ${columnInfo.rows[0].data_type}`);
      if (columnInfo.rows[0].character_maximum_length) {
        console.log(`    Max length: ${columnInfo.rows[0].character_maximum_length}`);
      }
    }

    // Check data for client 17 (ALAGAMMAI)
    const samples = await pool.query(`
      SELECT job_id, job_uid, work_desc, client_id
      FROM jobshead
      WHERE client_id = 17
      ORDER BY job_id
    `);

    console.log(`\nSample job_uid values for client 17 (ALAGAMMAI) - ${samples.rows.length} jobs:`);
    samples.rows.forEach((row, idx) => {
      console.log(`${idx + 1}. job_id: ${row.job_id}, job_uid: "${row.job_uid || 'NULL'}", desc: "${row.work_desc}"`);
    });

    // Check how many jobs have NULL job_uid
    const nullCheck = await pool.query(`
      SELECT
        COUNT(*) as total,
        COUNT(job_uid) as with_uid,
        COUNT(*) - COUNT(job_uid) as null_uid
      FROM jobshead
    `);

    console.log(`\n[INFO] Total jobs: ${nullCheck.rows[0].total}`);
    console.log(`[INFO] Jobs with job_uid: ${nullCheck.rows[0].with_uid}`);
    console.log(`[INFO] Jobs with NULL job_uid: ${nullCheck.rows[0].null_uid}`);

    await pool.end();
  } catch (err) {
    console.error('Error:', err.message);
    await pool.end();
  }
}

checkDesktopJobUid();
