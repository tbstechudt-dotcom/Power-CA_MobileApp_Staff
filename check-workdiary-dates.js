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

async function checkWorkdiaryDates() {
  console.log('Analyzing workdiary dates vs job year_id...\n');

  try {
    // Get all mobile workdiary records with their job year_id
    const records = await supabasePool.query(`
      SELECT wd_id, job_id, task_id, staff_id, date, tasknotes
      FROM workdiary
      WHERE source = 'M' AND task_id IS NOT NULL
      ORDER BY date
    `);

    console.log(`Found ${records.rows.length} mobile workdiary records\n`);

    for (const record of records.rows) {
      // Get job year_id
      const jobInfo = await desktopPool.query(`
        SELECT year_id, job_dt
        FROM jobcard_head
        WHERE job_id = $1
      `, [record.job_id]);

      if (jobInfo.rows.length === 0) {
        console.log(`wd_id ${record.wd_id}: Job ${record.job_id} not found`);
        continue;
      }

      const yearId = jobInfo.rows[0].year_id;
      const jobDate = jobInfo.rows[0].job_dt;
      const workDate = new Date(record.date);

      // Check if week exists for this date and year
      const weekCheck = await desktopPool.query(`
        SELECT week_id, week_start, week_end
        FROM jc_week
        WHERE org_id = 1
          AND year_id = $1
          AND $2 BETWEEN week_start AND week_end
      `, [yearId, workDate]);

      const hasWeek = weekCheck.rows.length > 0;

      console.log(`wd_id ${record.wd_id}:`);
      console.log(`  Job: ${record.job_id}, Task: ${record.task_id}`);
      console.log(`  Work date: ${workDate.toDateString()}`);
      console.log(`  Job year_id: ${yearId}`);
      console.log(`  Job date: ${new Date(jobDate).toDateString()}`);
      console.log(`  Week exists: ${hasWeek ? 'YES' : 'NO ❌'}`);

      if (!hasWeek) {
        // Find which year_id contains this date
        const correctYear = await desktopPool.query(`
          SELECT year_id, week_start, week_end
          FROM jc_week
          WHERE org_id = 1
            AND $1 BETWEEN week_start AND week_end
          LIMIT 1
        `, [workDate]);

        if (correctYear.rows.length > 0) {
          console.log(`  [FIX] Date ${workDate.toDateString()} should use year_id ${correctYear.rows[0].year_id}`);
        } else {
          console.log(`  [ERROR] No year_id found for date ${workDate.toDateString()}`);
        }
      }
      console.log('');
    }

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await supabasePool.end();
    await desktopPool.end();
  }
}

checkWorkdiaryDates();
