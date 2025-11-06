/**
 * Analyze invalid client_id references in jobshead
 * Find which client_ids are referenced but don't exist in climaster
 */

require('dotenv').config();
const { Pool } = require('pg');

const localPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function analyzeInvalidClients() {
  try {
    console.log('='.repeat(70));
    console.log('ANALYZING INVALID CLIENT REFERENCES');
    console.log('='.repeat(70));

    // 1. Find jobs with invalid client_ids
    console.log('\n1. Finding jobs with invalid client_id references...\n');

    const invalidJobs = await localPool.query(`
      SELECT
        j.client_id,
        COUNT(*) as job_count,
        MIN(j.job_id) as first_job_id,
        MAX(j.job_id) as last_job_id,
        MIN(j.work_desc) as sample_work_desc
      FROM jobshead j
      LEFT JOIN climaster c ON j.client_id = c.client_id
      WHERE c.client_id IS NULL
      GROUP BY j.client_id
      ORDER BY job_count DESC
    `);

    console.log('Invalid Client IDs Found:');
    console.log('-'.repeat(70));
    console.log('Client ID'.padEnd(15) + 'Jobs'.padEnd(10) + 'First Job'.padEnd(12) + 'Sample Work Description');
    console.log('-'.repeat(70));

    let totalInvalidJobs = 0;
    invalidJobs.rows.forEach(row => {
      totalInvalidJobs += parseInt(row.job_count);
      console.log(
        String(row.client_id || 'NULL').padEnd(15) +
        String(row.job_count).padEnd(10) +
        String(row.first_job_id).padEnd(12) +
        (row.sample_work_desc || 'N/A').substring(0, 40)
      );
    });

    console.log('-'.repeat(70));
    console.log(`Total: ${invalidJobs.rows.length} invalid client_ids`);
    console.log(`Total: ${totalInvalidJobs} jobs affected`);

    // 2. Check if these clients ever existed
    console.log('\n2. Checking job details for invalid client references...\n');

    if (invalidJobs.rows.length > 0) {
      const topInvalid = invalidJobs.rows.slice(0, 5);

      for (const inv of topInvalid) {
        console.log(`\nClient ID ${inv.client_id}: ${inv.job_count} jobs`);

        // Get sample jobs
        const sampleJobs = await localPool.query(`
          SELECT job_id, work_desc, year_id, job_status
          FROM jobshead
          WHERE client_id = $1
          LIMIT 5
        `, [inv.client_id]);

        console.log('  Sample jobs:');
        sampleJobs.rows.forEach(job => {
          console.log(`    - Job #${job.job_id}: ${job.work_desc || 'N/A'} (Year: ${job.year_id}, Status: ${job.job_status})`);
        });
      }
    }

    // 3. Summary and recommendations
    console.log('\n' + '='.repeat(70));
    console.log('SUMMARY');
    console.log('='.repeat(70));
    console.log(`\nTotal jobs in jobshead: ${(await localPool.query('SELECT COUNT(*) FROM jobshead')).rows[0].count}`);
    console.log(`Jobs with invalid client_id: ${totalInvalidJobs}`);
    console.log(`Percentage affected: ${((totalInvalidJobs / parseInt((await localPool.query('SELECT COUNT(*) FROM jobshead')).rows[0].count)) * 100).toFixed(2)}%`);

    console.log('\n' + '='.repeat(70));
    console.log('RECOMMENDATIONS');
    console.log('='.repeat(70));
    console.log('\nOption 1: FIX DATA - Create missing clients');
    console.log('  - Recreate deleted clients in climaster');
    console.log('  - Preserves all job data');
    console.log('  - Best for production data');

    console.log('\nOption 2: ACCEPT LOSS - Skip invalid jobs');
    console.log('  - Continue with current sync (skips 3,942 jobs)');
    console.log('  - Quick but loses data');
    console.log('  - Only if these jobs are truly obsolete');

    console.log('\nOption 3: NULL REFERENCES - Make client_id nullable');
    console.log('  - Change Supabase schema to allow NULL client_id');
    console.log('  - Syncs all jobs, but some have no client');
    console.log('  - May break mobile app logic');

    console.log('\nOption 4: DUMMY CLIENT - Create placeholder client');
    console.log('  - Create client_id=0 as "Deleted Client"');
    console.log('  - Update invalid jobs to use client_id=0');
    console.log('  - Preserves job data with clear indicator');
    console.log('='.repeat(70));

    await localPool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

analyzeInvalidClients();
