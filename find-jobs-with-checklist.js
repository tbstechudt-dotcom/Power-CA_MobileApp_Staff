const { Pool } = require('pg');
require('dotenv').config();

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '6543'),
  database: 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres.jacqfogzgzvbjeizljqf',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function findJobsWithChecklist() {
  console.log('Finding jobs with taskchecklist records...\n');

  try {
    // Find jobs that have taskchecklist items with task details
    const result = await supabasePool.query(`
      SELECT
        j.job_id,
        j.job_uid,
        j.work_desc,
        t.task_id,
        t.task_desc,
        COUNT(tc.tc_id) as checklist_count
      FROM taskchecklist tc
      JOIN jobshead j ON tc.job_id = j.job_id
      JOIN jobtasks t ON tc.job_id = t.job_id AND tc.task_id = t.task_id
      GROUP BY j.job_id, j.job_uid, j.work_desc, t.task_id, t.task_desc
      ORDER BY checklist_count DESC, j.job_id, t.task_id
      LIMIT 20
    `);

    if (result.rows.length === 0) {
      console.log('No jobs found with taskchecklist records.');
      await supabasePool.end();
      return;
    }

    console.log(`Found ${result.rows.length} job-task combinations with checklist items:\n`);
    console.log('╔════════════════════════════════════════════════════════════════════════════╗');
    console.log('║ Job ID   │ Job UID       │ Task ID │ Task Name           │ Checklist Count ║');
    console.log('╠════════════════════════════════════════════════════════════════════════════╣');

    result.rows.forEach(row => {
      const jobId = row.job_id.toString().padEnd(8);
      const jobUid = (row.job_uid || 'N/A').toString().padEnd(13);
      const taskId = row.task_id.toString().padEnd(7);
      const taskDesc = (row.task_desc || 'N/A').toString().substring(0, 19).padEnd(19);
      const count = row.checklist_count.toString().padEnd(15);

      console.log(`║ ${jobId} │ ${jobUid} │ ${taskId} │ ${taskDesc} │ ${count} ║`);
    });

    console.log('╚════════════════════════════════════════════════════════════════════════════╝');

    // Show details for the first job with most checklist items
    const topJob = result.rows[0];
    console.log(`\n\nDetailed checklist items for Job ${topJob.job_uid} - Task ${topJob.task_desc}:`);
    console.log('─'.repeat(80));

    const items = await supabasePool.query(`
      SELECT
        tc_id,
        checklistdesc,
        checkliststatus,
        completedby,
        completeddate
      FROM taskchecklist
      WHERE job_id = $1 AND task_id = $2
      ORDER BY tc_id
    `, [topJob.job_id, topJob.task_id]);

    items.rows.forEach((item, index) => {
      const status = (item.checkliststatus === 1 || item.completedby) ? '[OK] DONE' : '[ ] TODO';
      const completedInfo = item.completeddate
        ? ` (completed on ${new Date(item.completeddate).toLocaleDateString()})`
        : '';

      console.log(`${index + 1}. ${status} ${item.checklistdesc}${completedInfo}`);
    });

    console.log('\n' + '─'.repeat(80));
    console.log(`\nTo test in the app:`);
    console.log(`1. Navigate to Job: ${topJob.job_uid}`);
    console.log(`2. Click on "Task Summary" tab`);
    console.log(`3. Click on task: ${topJob.task_desc}`);
    console.log(`4. You should see ${topJob.checklist_count} checklist items`);

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await supabasePool.end();
  }
}

findJobsWithChecklist();
