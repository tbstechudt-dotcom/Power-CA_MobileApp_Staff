// Script to verify job counts and check for duplicates
// Run with: node scripts/check-job-counts.js

const { createClient } = require('@supabase/supabase-js');

// Supabase credentials (from .env or hardcoded for testing)
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzAzNzA4ODIsImV4cCI6MjA0NTk0Njg4Mn0.dHa4c_eDPnaR1DJZJ7wNPC3lBu_73csOCCp5ok4MFOM';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Staff ID to check (change this to test different staff)
const STAFF_ID = 1; // Replace with actual staff ID

async function checkJobCounts() {
  console.log('='.repeat(60));
  console.log('JOB COUNT VERIFICATION SCRIPT');
  console.log('='.repeat(60));
  console.log(`Staff ID: ${STAFF_ID}`);
  console.log('');

  try {
    // 1. Get all jobs for this staff (excluding Closer status 'C')
    const { data: allJobs, error: jobsError } = await supabase
      .from('jobshead')
      .select('job_id, job_uid, job_status, work_desc, client_id')
      .eq('sporg_id', STAFF_ID)
      .neq('job_status', 'C')
      .order('job_id', { ascending: false });

    if (jobsError) {
      console.error('Error fetching jobs:', jobsError);
      return;
    }

    console.log(`Total records from database: ${allJobs.length}`);
    console.log('');

    // 2. Check for duplicate job_ids
    const jobIdCounts = {};
    const duplicates = [];

    for (const job of allJobs) {
      const jobId = job.job_id;
      if (jobIdCounts[jobId]) {
        jobIdCounts[jobId]++;
        duplicates.push(job);
      } else {
        jobIdCounts[jobId] = 1;
      }
    }

    console.log('--- DUPLICATE CHECK ---');
    if (duplicates.length > 0) {
      console.log(`Found ${duplicates.length} duplicate records!`);
      console.log('Duplicate job_ids:');
      const uniqueDuplicateIds = [...new Set(duplicates.map(d => d.job_id))];
      uniqueDuplicateIds.forEach(id => {
        console.log(`  - job_id ${id}: appears ${jobIdCounts[id]} times`);
      });
    } else {
      console.log('No duplicates found - all job_ids are unique');
    }
    console.log('');

    // 3. Count unique jobs
    const uniqueJobIds = new Set(allJobs.map(j => j.job_id));
    console.log(`Unique job count: ${uniqueJobIds.size}`);
    console.log('');

    // 4. Count by status
    const statusMap = {
      'W': 'Waiting',
      'P': 'Progress',
      'D': 'Delivery',
      'A': 'Planning',
      'G': 'Work Done',
      'L': 'Planning',
    };

    // Count using unique jobs only (deduplicated)
    const uniqueJobs = [];
    const seenIds = new Set();
    for (const job of allJobs) {
      if (!seenIds.has(job.job_id)) {
        seenIds.add(job.job_id);
        uniqueJobs.push(job);
      }
    }

    const statusCounts = {};
    for (const job of uniqueJobs) {
      const statusCode = (job.job_status || 'W').toString().trim();
      const statusName = statusMap[statusCode] || 'Waiting';
      statusCounts[statusName] = (statusCounts[statusName] || 0) + 1;
    }

    console.log('--- STATUS COUNTS (after deduplication) ---');
    Object.entries(statusCounts).forEach(([status, count]) => {
      console.log(`  ${status}: ${count}`);
    });
    console.log('');

    // 5. Show raw status code counts
    const rawStatusCounts = {};
    for (const job of uniqueJobs) {
      const statusCode = (job.job_status || 'W').toString().trim();
      rawStatusCounts[statusCode] = (rawStatusCounts[statusCode] || 0) + 1;
    }

    console.log('--- RAW STATUS CODE COUNTS ---');
    Object.entries(rawStatusCounts).forEach(([code, count]) => {
      const name = statusMap[code] || 'Unknown';
      console.log(`  '${code}' (${name}): ${count}`);
    });
    console.log('');

    // 6. Summary
    console.log('='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total records from DB: ${allJobs.length}`);
    console.log(`Unique jobs (deduplicated): ${uniqueJobIds.size}`);
    console.log(`Duplicates found: ${allJobs.length - uniqueJobIds.size}`);
    console.log('');
    console.log('Expected counts in app (after deduplication):');
    console.log(`  Progress: ${statusCounts['Progress'] || 0}`);
    console.log(`  Waiting: ${statusCounts['Waiting'] || 0}`);
    console.log(`  Planning: ${statusCounts['Planning'] || 0}`);
    console.log(`  Work Done: ${statusCounts['Work Done'] || 0}`);
    console.log(`  Delivery: ${statusCounts['Delivery'] || 0}`);

  } catch (error) {
    console.error('Script error:', error);
  }
}

checkJobCounts();
