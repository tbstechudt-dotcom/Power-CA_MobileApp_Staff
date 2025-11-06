const { Pool } = require('pg');

const pool = new Pool({
  host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Powerca@2025',
  ssl: { rejectUnauthorized: false }
});

async function checkMMWorkdiary() {
  try {
    // Get MM's staff_id
    const staffResult = await pool.query(`
      SELECT staff_id, name
      FROM mbstaff
      WHERE app_username = 'MM'
    `);

    if (staffResult.rows.length === 0) {
      console.log('User MM not found');
      return;
    }

    const staff = staffResult.rows[0];
    console.log(`Staff: ${staff.name} (ID: ${staff.staff_id})`);
    console.log('');

    // Check workdiary entries for this staff
    const workdiaryResult = await pool.query(`
      SELECT COUNT(*) as count, COUNT(DISTINCT job_id) as unique_jobs
      FROM workdiary
      WHERE staff_id = $1
    `, [staff.staff_id]);

    console.log('Workdiary entries:');
    console.log(`  Total entries: ${workdiaryResult.rows[0].count}`);
    console.log(`  Unique jobs: ${workdiaryResult.rows[0].unique_jobs}`);
    console.log('');

    // Get total jobs in system
    const totalJobsResult = await pool.query(`
      SELECT COUNT(*) as count
      FROM jobshead
    `);

    console.log(`Total jobs in system: ${totalJobsResult.rows[0].count}`);
    console.log('');

    // Check if jobtasks has staff_id linkage
    const jobtasksResult = await pool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'jobtasks' AND column_name LIKE '%staff%'
    `);

    console.log('Staff-related columns in jobtasks:');
    jobtasksResult.rows.forEach(row => {
      console.log(`  - ${row.column_name}`);
    });
    console.log('');

    // Sample some jobs to see their structure
    const sampleJobs = await pool.query(`
      SELECT job_id, job_name, job_status, client_id
      FROM jobshead
      ORDER BY updated_at DESC
      LIMIT 5
    `);

    console.log('Sample jobs (last 5 updated):');
    sampleJobs.rows.forEach(job => {
      console.log(`  Job ${job.job_id}: ${job.job_name || 'No name'} (${job.job_status || 'No status'})`);
    });

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkMMWorkdiary();
