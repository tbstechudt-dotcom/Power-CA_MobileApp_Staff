/**
 * Report: Work Log Entry Dates
 * Shows which dates have work diary entries
 */

require('dotenv').config();
const { Pool } = require('pg');

// Supabase connection (use production config)
const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST || 'aws-0-ap-south-1.pooler.supabase.com',
  port: parseInt(process.env.SUPABASE_DB_PORT || '6543'),
  database: process.env.SUPABASE_DB_NAME || 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres.jacqfogzgzvbjeizljqf',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
  max: 5,
});

async function generateWorkLogReport() {
  try {
    console.log('\n=== WORK LOG ENTRY DATES REPORT ===\n');

    // Get total count
    const totalResult = await supabasePool.query(`
      SELECT COUNT(*) as total_entries
      FROM workdiary
    `);
    console.log(`[INFO] Total work log entries: ${totalResult.rows[0].total_entries}\n`);

    // Get date range
    const rangeResult = await supabasePool.query(`
      SELECT
        MIN(wdate) as earliest_date,
        MAX(wdate) as latest_date
      FROM workdiary
      WHERE wdate IS NOT NULL
    `);

    if (rangeResult.rows[0].earliest_date) {
      console.log(`[INFO] Date Range: ${rangeResult.rows[0].earliest_date} to ${rangeResult.rows[0].latest_date}\n`);
    }

    // Get entries grouped by date with counts
    const dateResult = await supabasePool.query(`
      SELECT
        wdate::date as work_date,
        COUNT(*) as entry_count,
        COUNT(DISTINCT staff_id) as staff_count,
        SUM(CASE WHEN whours IS NOT NULL THEN whours ELSE 0 END) as total_hours
      FROM workdiary
      WHERE wdate IS NOT NULL
      GROUP BY wdate::date
      ORDER BY wdate::date DESC
      LIMIT 100
    `);

    console.log('=== DATES WITH WORK LOG ENTRIES (Latest 100) ===\n');
    console.log('Date         | Entries | Staff | Total Hours');
    console.log('-------------|---------|-------|-------------');

    for (const row of dateResult.rows) {
      const date = row.work_date;
      const entries = String(row.entry_count).padStart(7, ' ');
      const staff = String(row.staff_count).padStart(5, ' ');
      const hours = row.total_hours ? parseFloat(row.total_hours).toFixed(2).padStart(11, ' ') : '          -';
      console.log(`${date} | ${entries} | ${staff} | ${hours}`);
    }

    // Get summary by month
    const monthlyResult = await supabasePool.query(`
      SELECT
        TO_CHAR(wdate, 'YYYY-MM') as month,
        COUNT(*) as entry_count,
        COUNT(DISTINCT staff_id) as staff_count,
        SUM(CASE WHEN whours IS NOT NULL THEN whours ELSE 0 END) as total_hours
      FROM workdiary
      WHERE wdate IS NOT NULL
      GROUP BY TO_CHAR(wdate, 'YYYY-MM')
      ORDER BY month DESC
      LIMIT 12
    `);

    console.log('\n\n=== MONTHLY SUMMARY (Last 12 Months) ===\n');
    console.log('Month   | Entries | Staff | Total Hours');
    console.log('--------|---------|-------|-------------');

    for (const row of monthlyResult.rows) {
      const month = row.month;
      const entries = String(row.entry_count).padStart(7, ' ');
      const staff = String(row.staff_count).padStart(5, ' ');
      const hours = row.total_hours ? parseFloat(row.total_hours).toFixed(2).padStart(11, ' ') : '          -';
      console.log(`${month} | ${entries} | ${staff} | ${hours}`);
    }

    // Get staff summary
    const staffResult = await supabasePool.query(`
      SELECT
        s.name as staff_name,
        COUNT(*) as entry_count,
        COUNT(DISTINCT w.wdate::date) as days_logged,
        SUM(CASE WHEN w.whours IS NOT NULL THEN w.whours ELSE 0 END) as total_hours
      FROM workdiary w
      LEFT JOIN mbstaff s ON w.staff_id = s.staff_id
      GROUP BY s.staff_id, s.name
      ORDER BY entry_count DESC
      LIMIT 20
    `);

    console.log('\n\n=== TOP 20 STAFF BY WORK LOG ENTRIES ===\n');
    console.log('Staff Name                    | Entries | Days | Total Hours');
    console.log('------------------------------|---------|------|-------------');

    for (const row of staffResult.rows) {
      const name = (row.staff_name || 'Unknown').substring(0, 29).padEnd(29, ' ');
      const entries = String(row.entry_count).padStart(7, ' ');
      const days = String(row.days_logged).padStart(4, ' ');
      const hours = row.total_hours ? parseFloat(row.total_hours).toFixed(2).padStart(11, ' ') : '          -';
      console.log(`${name} | ${entries} | ${days} | ${hours}`);
    }

    console.log('\n[SUCCESS] Report generated successfully!\n');

  } catch (error) {
    console.error('[ERROR] Failed to generate report:', error.message);
    throw error;
  } finally {
    await supabasePool.end();
  }
}

// Run report
generateWorkLogReport()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FATAL]', error);
    process.exit(1);
  });
