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

async function testInsert() {
  console.log('Testing manual insert of wd_id 16...\n');

  // Get wd_id 16 record
  const record = await supabasePool.query('SELECT * FROM workdiary WHERE wd_id = 16');
  const wd = record.rows[0];

  console.log('Record details:');
  console.log(`  wd_id: ${wd.wd_id}`);
  console.log(`  job_id: ${wd.job_id}`);
  console.log(`  task_id: ${wd.task_id}`);
  console.log(`  staff_id: ${wd.staff_id}`);
  console.log(`  date: ${wd.date}`);
  console.log(`  minutes: ${wd.minutes}`);

  // Get org_id, loc_id from job
  const jobInfo = await desktopPool.query('SELECT org_id, loc_id, year_id FROM jobcard_head WHERE job_id = $1', [wd.job_id]);

  if (jobInfo.rows.length === 0) {
    console.log('\nJob not found in desktop!');
    await supabasePool.end();
    await desktopPool.end();
    return;
  }

  const { org_id, loc_id, year_id } = jobInfo.rows[0];
  console.log(`\nJob info: org_id=${org_id}, loc_id=${loc_id}, year_id=${year_id}`);

  // Try to insert
  try {
    await desktopPool.query(`
      INSERT INTO daily_work (
        org_id, loc_id, work_dt, sporgid, task_id, job_id,
        work_det, work_man_min, year_id, jobdet_slno, work_id
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
      )
    `, [
      org_id,
      loc_id,
      wd.date,
      wd.staff_id,
      wd.task_id,
      wd.job_id,
      wd.tasknotes || 'Mobile entry',
      wd.minutes || 0,
      year_id,
      1,
      wd.wd_id
    ]);

    console.log('\n[SUCCESS] Record inserted to daily_work!');
  } catch (error) {
    console.log(`\n[ERROR] Failed to insert: ${error.message}`);
  }

  await supabasePool.end();
  await desktopPool.end();
}

testInsert();
