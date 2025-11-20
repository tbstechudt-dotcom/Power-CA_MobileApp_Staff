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

async function checkJobUid() {
  try {
    // Check if job_uid column exists
    const columnCheck = await pool.query(`
      SELECT column_name, data_type, character_maximum_length
      FROM information_schema.columns
      WHERE table_name = 'jobshead' AND column_name = 'job_uid'
    `);

    if (columnCheck.rows.length > 0) {
      console.log('[OK] job_uid column exists in Supabase');
      console.log(`    Type: ${columnCheck.rows[0].data_type}`);

      // Check if it has data
      const dataCheck = await pool.query(`
        SELECT COUNT(*) as total,
               COUNT(job_uid) as with_uid,
               COUNT(*) - COUNT(job_uid) as null_uid
        FROM jobshead
      `);

      console.log(`[INFO] Data: ${dataCheck.rows[0].total} total jobs, ${dataCheck.rows[0].with_uid} have job_uid, ${dataCheck.rows[0].null_uid} are NULL`);

      // Show sample job_uid values for client 17
      const samples = await pool.query(`
        SELECT job_id, job_uid, work_desc
        FROM jobshead
        WHERE client_id = 17
        ORDER BY job_id
        LIMIT 10
      `);

      console.log('\nSample job_uid values for client 17 (ALAGAMMAI):');
      samples.rows.forEach(row => {
        console.log(`  job_id: ${row.job_id}, job_uid: ${row.job_uid || 'NULL'}, desc: ${row.work_desc}`);
      });
    } else {
      console.log('[ERROR] job_uid column does NOT exist in Supabase jobshead table');
      console.log('[INFO] Need to add this column and sync it from desktop');
    }

    await pool.end();
  } catch (err) {
    console.error('Error:', err.message);
    await pool.end();
  }
}

checkJobUid();
