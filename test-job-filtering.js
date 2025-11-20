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

async function testFiltering() {
  try {
    const clientId = 17; // ALAGAMMAI

    // Simulate what the Flutter app does
    console.log('STEP 1: Load ALL jobs and order by work_desc');
    const allJobs = await pool.query(`
      SELECT job_id, work_desc, client_id
      FROM jobshead
      ORDER BY work_desc
    `);
    console.log('Total jobs loaded:', allJobs.rows.length);
    console.log('');

    // Deduplicate
    console.log('STEP 2: Deduplicate by job_id');
    const uniqueJobsMap = {};
    for (const job of allJobs.rows) {
      const jobId = job.job_id;
      if (!uniqueJobsMap[jobId]) {
        uniqueJobsMap[jobId] = job;
      }
    }
    const uniqueJobs = Object.values(uniqueJobsMap);
    console.log('Unique jobs:', uniqueJobs.length);
    console.log('');

    // Filter by client_id
    console.log('STEP 3: Filter by client_id =', clientId);
    const filteredJobs = uniqueJobs.filter(job => {
      return job.client_id == clientId; // Using == to match both int and num
    });

    console.log('Filtered jobs for ALAGAMMAI:', filteredJobs.length);
    console.log('');

    if (filteredJobs.length > 0) {
      console.log('Jobs that should appear in dropdown:');
      filteredJobs.forEach((job, index) => {
        console.log(`${index + 1}. job_id: ${job.job_id}, work_desc: "${job.work_desc}", client_id: ${job.client_id}`);
      });
    } else {
      console.log('ERROR: No jobs found for this client!');

      // Debug: Check all jobs for this client_id
      const debugJobs = await pool.query(`
        SELECT job_id, work_desc, client_id
        FROM jobshead
        WHERE client_id = $1
      `, [clientId]);

      console.log('');
      console.log('DEBUG: Direct query for client_id', clientId);
      console.log('Found', debugJobs.rows.length, 'jobs');
      debugJobs.rows.slice(0, 5).forEach(job => {
        console.log(`  job_id: ${job.job_id}, client_id: ${job.client_id} (type: ${typeof job.client_id})`);
      });
    }

    await pool.end();
  } catch (err) {
    console.log('Error:', err.message);
    await pool.end();
  }
}

testFiltering();
