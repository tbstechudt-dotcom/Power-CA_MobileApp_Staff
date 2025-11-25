const { Pool } = require('pg');
require('dotenv').config();

// Desktop PostgreSQL connection
const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

// Supabase connection
const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '6543'),
  database: 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres.jacqfogzgzvbjeizljqf',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function insertWorkdiaryToDailyWork() {
  console.log('\n[1/2] Processing workdiary → daily_work');
  console.log('='.repeat(60));

  try {
    // Fetch mobile-created workdiary records
    const workdiaryRecords = await supabasePool.query(`
      SELECT
        org_id, loc_id, date as work_dt, staff_id as sporgid,
        task_id, job_id, tasknotes as work_det,
        timefrom as manhrs_from, timeto as manhrs_to,
        minutes as work_man_min, wd_id
      FROM workdiary
      WHERE source = 'M'
      ORDER BY date DESC
    `);

    console.log(`Found ${workdiaryRecords.rows.length} mobile workdiary records`);

    if (workdiaryRecords.rows.length === 0) {
      console.log('No mobile workdiary records to process');
      return;
    }

    let inserted = 0;
    let skipped = 0;

    for (const record of workdiaryRecords.rows) {
      try {
        // Skip if task_id is null (required field)
        if (!record.task_id) {
          console.log(`  [SKIP] Record has no task_id (wd_id: ${record.wd_id})`);
          skipped++;
          continue;
        }

        // Look up org_id and loc_id from jobcard_head using job_id
        const jobInfo = await desktopPool.query(`
          SELECT org_id, loc_id, year_id FROM jobcard_head WHERE job_id = $1
        `, [record.job_id]);

        if (jobInfo.rows.length === 0) {
          console.log(`  [SKIP] Job ${record.job_id} not found in desktop database`);
          skipped++;
          continue;
        }

        const { org_id, loc_id, year_id } = jobInfo.rows[0];

        // Verify task exists in jobcard_det
        const taskExists = await desktopPool.query(`
          SELECT 1 FROM jobcard_det WHERE job_id = $1 AND task_id = $2
        `, [record.job_id, record.task_id]);

        if (taskExists.rows.length === 0) {
          console.log(`  [SKIP] Task ${record.task_id} not found for job ${record.job_id}`);
          skipped++;
          continue;
        }

        // Check if record already exists (by matching org_id, job_id, task_id, sporgid, work_dt)
        const existing = await desktopPool.query(`
          SELECT dw_id FROM daily_work
          WHERE org_id = $1 AND job_id = $2 AND task_id = $3
            AND sporgid = $4 AND work_dt = $5
        `, [org_id, record.job_id, record.task_id, record.sporgid, record.work_dt]);

        if (existing.rows.length > 0) {
          skipped++;
          console.log(`  [SKIP] Record already exists (dw_id: ${existing.rows[0].dw_id})`);
          continue;
        }

        // Insert into daily_work
        await desktopPool.query(`
          INSERT INTO daily_work (
            org_id, loc_id, work_dt, sporgid, task_id, job_id,
            work_det, manhrs_from, manhrs_to, work_man_min,
            year_id, jobdet_slno, work_id
          ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
          )
        `, [
          org_id,
          loc_id,
          record.work_dt,
          record.sporgid,
          record.task_id,
          record.job_id,
          record.work_det || 'Mobile entry',
          record.manhrs_from,
          record.manhrs_to,
          record.work_man_min || 0,
          year_id,
          1, // jobdet_slno - default to 1 (can be updated based on your logic)
          record.wd_id // Use wd_id as work_id for reference
        ]);

        inserted++;
        console.log(`  [OK] Inserted record for job_id: ${record.job_id}, task: ${record.task_id}, date: ${record.work_dt}`);
      } catch (error) {
        console.error(`  [ERROR] Failed to insert record:`, error.message);
      }
    }

    console.log(`\nSummary: ${inserted} inserted, ${skipped} skipped`);
  } catch (error) {
    console.error('[ERROR] Failed to process workdiary:', error.message);
    throw error;
  }
}

async function insertLearequestToAtleaverequest() {
  console.log('\n[2/2] Processing learequest → atleaverequest');
  console.log('='.repeat(60));

  try {
    // Fetch mobile-created learequest records with staff info
    const learequestRecords = await supabasePool.query(`
      SELECT
        l.org_id, l.loc_id, l.learequest_id, l.requestdate,
        l.fromdate, l.todate, l.fhvalue, l.shvalue,
        l.leavetype, l.leaveremarks, l.createdby, l.createddate,
        l.approval_status, l.approvedby, l.approveddate,
        lr.staff_id
      FROM learequest l
      LEFT JOIN (
        SELECT DISTINCT learequest_id,
          CAST(SUBSTRING(createdby FROM '[0-9]+') AS INTEGER) as staff_id
        FROM learequest
        WHERE createdby ~ '^[0-9]+'
      ) lr ON l.learequest_id = lr.learequest_id
      WHERE l.source = 'M'
      ORDER BY l.requestdate DESC
    `);

    console.log(`Found ${learequestRecords.rows.length} mobile learequest records`);

    if (learequestRecords.rows.length === 0) {
      console.log('No mobile learequest records to process');
      return;
    }

    let inserted = 0;
    let skipped = 0;

    for (const record of learequestRecords.rows) {
      try {
        // Check if record already exists (by learequest_id)
        const existing = await desktopPool.query(`
          SELECT learequest_id FROM atleaverequest
          WHERE learequest_id = $1
        `, [record.learequest_id]);

        if (existing.rows.length > 0) {
          skipped++;
          console.log(`  [SKIP] Record already exists (learequest_id: ${record.learequest_id})`);
          continue;
        }

        // Get year_id from requestdate (extract year)
        const year_id = new Date(record.requestdate).getFullYear();

        // Calculate leave days
        const fromDate = new Date(record.fromdate);
        const toDate = new Date(record.todate);
        const days = Math.ceil((toDate - fromDate) / (1000 * 60 * 60 * 24)) + 1;

        // Default attschedule_id to 1 (based on sample data analysis)
        const attschedule_id = 1;

        // Insert into atleaverequest
        await desktopPool.query(`
          INSERT INTO atleaverequest (
            attschedule_id, learequest_id, leareqdocdate, leareqfrom, leareqto,
            leareqdays, leareqreason, org_id, loc_id, year_id,
            leareq_fhvalue, leareq_shvalue, leareqapp, staff_id
          ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
          )
        `, [
          attschedule_id,
          record.learequest_id,
          record.requestdate,
          record.fromdate,
          record.todate,
          days,
          record.leaveremarks || 'Mobile leave request',
          record.org_id || 1, // Default org_id if null
          record.loc_id || 1, // Default loc_id if null
          year_id,
          record.fhvalue === 'F' ? 1 : record.fhvalue === 'H' ? 0.5 : 0,
          record.shvalue === 'F' ? 1 : record.shvalue === 'H' ? 0.5 : 0,
          record.approval_status || 'P',
          record.staff_id
        ]);

        inserted++;
        console.log(`  [OK] Inserted leave request: ${record.learequest_id}, from ${record.fromdate} to ${record.todate}`);
      } catch (error) {
        console.error(`  [ERROR] Failed to insert leave request:`, error.message);
      }
    }

    console.log(`\nSummary: ${inserted} inserted, ${skipped} skipped`);
  } catch (error) {
    console.error('[ERROR] Failed to process learequest:', error.message);
    throw error;
  }
}

async function main() {
  console.log('='.repeat(60));
  console.log('POST-SYNC: Insert Mobile Records to Parent Tables');
  console.log('='.repeat(60));

  try {
    await insertWorkdiaryToDailyWork();
    await insertLearequestToAtleaverequest();

    console.log('\n' + '='.repeat(60));
    console.log('[SUCCESS] Post-sync insert completed!');
    console.log('='.repeat(60));
  } catch (error) {
    console.error('\n[ERROR] Post-sync insert failed:', error.message);
    process.exit(1);
  } finally {
    await desktopPool.end();
    await supabasePool.end();
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { insertWorkdiaryToDailyWork, insertLearequestToAtleaverequest };
