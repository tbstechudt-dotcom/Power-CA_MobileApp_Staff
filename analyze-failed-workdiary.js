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

const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function analyze() {
  console.log('='.repeat(80));
  console.log('ANALYZING FAILED WORKDIARY RECORDS');
  console.log('='.repeat(80));

  // Get mobile workdiary records
  const failedRecords = await supabasePool.query(`
    SELECT wd_id, job_id, task_id, staff_id, date, tasknotes
    FROM workdiary
    WHERE source = 'M'
    ORDER BY date DESC
  `);

  console.log(`\nFound ${failedRecords.rows.length} mobile workdiary records\n`);

  let nullTaskId = 0;
  let jobNotFound = 0;
  let taskNotFound = 0;
  let taskNeedSync = 0;
  let ok = 0;

  for (const record of failedRecords.rows) {
    console.log(`Record wd_id: ${record.wd_id}`);
    console.log(`  Job: ${record.job_id}, Task: ${record.task_id}, Date: ${new Date(record.date).toDateString()}`);

    // Check if task_id is null
    if (!record.task_id) {
      console.log('  [ISSUE] task_id is NULL - cannot insert');
      console.log('  [SOLUTION] Mobile user needs to select a task\n');
      nullTaskId++;
      continue;
    }

    // Check if job exists in desktop
    const jobExists = await desktopPool.query(
      'SELECT job_id FROM jobcard_head WHERE job_id = $1',
      [record.job_id]
    );

    if (jobExists.rows.length === 0) {
      console.log(`  [ISSUE] Job ${record.job_id} does not exist in desktop database`);
      console.log(`  [SOLUTION] Run forward sync to sync job from desktop to Supabase\n`);
      jobNotFound++;
      continue;
    }

    // Check if task exists in desktop for this job
    const taskExists = await desktopPool.query(
      'SELECT jd.task_id FROM jobcard_det jd WHERE jd.job_id = $1 AND jd.task_id = $2',
      [record.job_id, record.task_id]
    );

    if (taskExists.rows.length === 0) {
      console.log(`  [ISSUE] Task ${record.task_id} not in desktop jobcard_det for job ${record.job_id}`);

      // Check where this task_id came from in Supabase
      const supabaseTask = await supabasePool.query(
        'SELECT task_id, task_desc FROM jobtasks WHERE job_id = $1 AND task_id = $2',
        [record.job_id, record.task_id]
      );

      if (supabaseTask.rows.length > 0) {
        console.log(`  [INFO] Task exists in Supabase: "${supabaseTask.rows[0].task_desc}"`);
        console.log(`  [SOLUTION] Sync this task from Supabase to desktop jobcard_det\n`);
        taskNeedSync++;
      } else {
        console.log(`  [ERROR] Task ${record.task_id} not found anywhere - orphaned`);
        console.log(`  [SOLUTION] Delete this workdiary record or fix task_id\n`);
        taskNotFound++;
      }
    } else {
      console.log(`  [OK] Task exists in desktop jobcard_det`);
      console.log(`  [STATUS] Should insert successfully\n`);
      ok++;
    }
  }

  console.log('='.repeat(80));
  console.log('SUMMARY');
  console.log('='.repeat(80));
  console.log(`Total mobile workdiary records: ${failedRecords.rows.length}`);
  console.log(`  - NULL task_id:               ${nullTaskId} records`);
  console.log(`  - Job not in desktop:         ${jobNotFound} records`);
  console.log(`  - Task needs sync to desktop: ${taskNeedSync} records`);
  console.log(`  - Task not found anywhere:    ${taskNotFound} records`);
  console.log(`  - OK (should insert):         ${ok} records`);

  console.log('\n' + '='.repeat(80));
  console.log('RECOMMENDED ACTIONS');
  console.log('='.repeat(80));

  if (taskNeedSync > 0) {
    console.log(`\n1. Sync missing tasks from Supabase to desktop (${taskNeedSync} tasks)`);
    console.log('   - These tasks exist in Supabase jobtasks but not in desktop jobcard_det');
    console.log('   - Need to INSERT these tasks into jobcard_det');
  }

  if (nullTaskId > 0) {
    console.log(`\n2. Fix NULL task_id records in mobile app (${nullTaskId} records)`);
    console.log('   - Update mobile app validation to require task selection');
  }

  if (taskNotFound > 0) {
    console.log(`\n3. Clean up orphaned task references (${taskNotFound} records)`);
    console.log('   - Delete these workdiary records or fix their task_id');
  }

  await supabasePool.end();
  await desktopPool.end();
}

analyze().catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
