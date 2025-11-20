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

async function checkUniqueJobs() {
  try {
    const clientId = 17; // ALAGAMMAI

    // Get all jobs for this client (including duplicates)
    const allJobsResult = await pool.query(`
      SELECT job_id, work_desc, client_id
      FROM jobshead
      WHERE client_id = $1
      ORDER BY work_desc
    `, [clientId]);

    console.log('ALL Jobs (including duplicates):');
    console.log('Total rows:', allJobsResult.rows.length);
    console.log('');

    // Deduplicate by job_id (mimic Flutter logic)
    const uniqueJobsMap = {};
    for (const job of allJobsResult.rows) {
      const jobId = job.job_id;
      if (!uniqueJobsMap[jobId]) {
        uniqueJobsMap[jobId] = job;
      }
    }

    const uniqueJobs = Object.values(uniqueJobsMap);

    console.log('UNIQUE Jobs (after deduplication):');
    console.log('Total unique job_ids:', uniqueJobs.length);
    console.log('');

    uniqueJobs.forEach((job, index) => {
      console.log(`${index + 1}. job_id: ${job.job_id}, work_desc: "${job.work_desc}"`);
    });

    await pool.end();
  } catch (err) {
    console.log('Error:', err.message);
    await pool.end();
  }
}

checkUniqueJobs();
