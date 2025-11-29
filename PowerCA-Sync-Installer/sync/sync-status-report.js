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

function formatDate(date) {
  return new Date(date).toLocaleDateString('en-IN', {
    year: 'numeric',
    month: 'short',
    day: '2-digit',
    weekday: 'short'
  });
}

async function generateDailySyncReport() {
  console.log('='.repeat(80));
  console.log('DAILY SYNC STATUS REPORT');
  console.log('='.repeat(80));

  try {
    // Get workdiary records grouped by date
    console.log('\n[1] WORKDIARY SYNC STATUS (Mobile → Desktop)');
    console.log('-'.repeat(80));

    const workdiaryByDate = await supabasePool.query(`
      SELECT
        DATE(date) as sync_date,
        COUNT(*) as total_records,
        COUNT(CASE WHEN source = 'M' THEN 1 END) as mobile_records,
        COUNT(CASE WHEN source = 'D' THEN 1 END) as desktop_records,
        STRING_AGG(DISTINCT CAST(job_id AS TEXT), ', ') as job_ids
      FROM workdiary
      WHERE date >= CURRENT_DATE - INTERVAL '30 days'
      GROUP BY DATE(date)
      ORDER BY DATE(date) DESC
    `);

    console.log('\nDate              | Total | Mobile | Desktop | Jobs');
    console.log('-'.repeat(80));

    let totalMobile = 0;
    let totalDesktop = 0;

    for (const row of workdiaryByDate.rows) {
      const dateStr = formatDate(row.sync_date).padEnd(15);
      const total = row.total_records.toString().padStart(5);
      const mobile = row.mobile_records.toString().padStart(6);
      const desktop = row.desktop_records.toString().padStart(7);
      const jobs = row.job_ids.substring(0, 30);

      console.log(`${dateStr} | ${total} | ${mobile} | ${desktop} | ${jobs}`);

      totalMobile += parseInt(row.mobile_records);
      totalDesktop += parseInt(row.desktop_records);
    }

    console.log('-'.repeat(80));
    console.log(`Total Mobile Records: ${totalMobile}`);
    console.log(`Total Desktop Records: ${totalDesktop}`);

    // Check which mobile records have been inserted to daily_work
    console.log('\n[2] WORKDIARY → DAILY_WORK INSERT STATUS');
    console.log('-'.repeat(80));

    const insertStatus = await desktopPool.query(`
      SELECT
        DATE(work_dt) as work_date,
        COUNT(*) as records_in_daily_work,
        STRING_AGG(DISTINCT CAST(job_id AS TEXT), ', ') as job_ids
      FROM daily_work
      WHERE work_dt >= CURRENT_DATE - INTERVAL '30 days'
        AND work_id IS NOT NULL  -- work_id = wd_id from mobile
      GROUP BY DATE(work_dt)
      ORDER BY DATE(work_dt) DESC
    `);

    console.log('\nDate              | Inserted | Jobs');
    console.log('-'.repeat(80));

    let totalInserted = 0;

    for (const row of insertStatus.rows) {
      const dateStr = formatDate(row.work_date).padEnd(15);
      const inserted = row.records_in_daily_work.toString().padStart(8);
      const jobs = row.job_ids.substring(0, 40);

      console.log(`${dateStr} | ${inserted} | ${jobs}`);
      totalInserted += parseInt(row.records_in_daily_work);
    }

    console.log('-'.repeat(80));
    console.log(`Total Inserted to daily_work: ${totalInserted}`);

    // Get learequest records grouped by date
    console.log('\n[3] LEAVE REQUEST SYNC STATUS (Mobile → Desktop)');
    console.log('-'.repeat(80));

    const learequestByDate = await supabasePool.query(`
      SELECT
        DATE(requestdate) as request_date,
        COUNT(*) as total_requests,
        COUNT(CASE WHEN source = 'M' THEN 1 END) as mobile_requests,
        COUNT(CASE WHEN source = 'D' THEN 1 END) as desktop_requests,
        COUNT(CASE WHEN approval_status = 'A' THEN 1 END) as approved,
        COUNT(CASE WHEN approval_status = 'P' THEN 1 END) as pending
      FROM learequest
      WHERE requestdate >= CURRENT_DATE - INTERVAL '30 days'
      GROUP BY DATE(requestdate)
      ORDER BY DATE(requestdate) DESC
    `);

    console.log('\nDate              | Total | Mobile | Desktop | Approved | Pending');
    console.log('-'.repeat(80));

    let totalLeaMobile = 0;
    let totalLeaDesktop = 0;

    for (const row of learequestByDate.rows) {
      const dateStr = formatDate(row.request_date).padEnd(15);
      const total = row.total_requests.toString().padStart(5);
      const mobile = row.mobile_requests.toString().padStart(6);
      const desktop = row.desktop_requests.toString().padStart(7);
      const approved = row.approved.toString().padStart(8);
      const pending = row.pending.toString().padStart(7);

      console.log(`${dateStr} | ${total} | ${mobile} | ${desktop} | ${approved} | ${pending}`);

      totalLeaMobile += parseInt(row.mobile_requests);
      totalLeaDesktop += parseInt(row.desktop_requests);
    }

    console.log('-'.repeat(80));
    console.log(`Total Mobile Leave Requests: ${totalLeaMobile}`);
    console.log(`Total Desktop Leave Requests: ${totalLeaDesktop}`);

    // Check which mobile leave requests have been inserted to atleaverequest
    console.log('\n[4] LEAREQUEST → ATLEAVEREQUEST INSERT STATUS');
    console.log('-'.repeat(80));

    const leaInsertStatus = await desktopPool.query(`
      SELECT
        DATE(leareqdocdate) as request_date,
        COUNT(*) as records_in_atleaverequest,
        COUNT(CASE WHEN leareqapp = 'Y' THEN 1 END) as approved,
        COUNT(CASE WHEN leareqapp = 'P' OR leareqapp IS NULL THEN 1 END) as pending
      FROM atleaverequest
      WHERE leareqdocdate >= CURRENT_DATE - INTERVAL '30 days'
      GROUP BY DATE(leareqdocdate)
      ORDER BY DATE(leareqdocdate) DESC
    `);

    console.log('\nDate              | Inserted | Approved | Pending');
    console.log('-'.repeat(80));

    let totalLeaInserted = 0;

    for (const row of leaInsertStatus.rows) {
      const dateStr = formatDate(row.request_date).padEnd(15);
      const inserted = row.records_in_atleaverequest.toString().padStart(8);
      const approved = row.approved.toString().padStart(8);
      const pending = row.pending.toString().padStart(7);

      console.log(`${dateStr} | ${inserted} | ${approved} | ${pending}`);
      totalLeaInserted += parseInt(row.records_in_atleaverequest);
    }

    console.log('-'.repeat(80));
    console.log(`Total Inserted to atleaverequest: ${totalLeaInserted}`);

    // Summary
    console.log('\n[5] SYNC SUMMARY');
    console.log('-'.repeat(80));
    console.log(`Workdiary (Mobile):          ${totalMobile} records`);
    console.log(`  - Inserted to daily_work:  ${totalInserted} records`);
    console.log(`  - Pending:                 ${totalMobile - totalInserted} records`);
    console.log('');
    console.log(`Leave Requests (Mobile):     ${totalLeaMobile} requests`);
    console.log(`  - Inserted to atleavereq:  ${totalLeaInserted} requests`);
    console.log(`  - Pending:                 ${totalLeaMobile - totalLeaInserted} requests`);

    console.log('\n' + '='.repeat(80));
    console.log('[SUCCESS] Daily sync report generated!');
    console.log('='.repeat(80));

  } catch (error) {
    console.error('\n[ERROR] Failed to generate report:', error.message);
    process.exit(1);
  } finally {
    await desktopPool.end();
    await supabasePool.end();
  }
}

// Run if called directly
if (require.main === module) {
  generateDailySyncReport();
}

module.exports = { generateDailySyncReport };
