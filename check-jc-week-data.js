const { Pool } = require('pg');
require('dotenv').config();

const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkJcWeek() {
  console.log('Checking jc_week table for year_id 20212022...\n');

  try {
    // Check if jc_week has any records for year_id 20212022
    const yearCheck = await desktopPool.query(`
      SELECT COUNT(*) as count, MIN(week_start) as min_date, MAX(week_end) as max_date
      FROM jc_week
      WHERE year_id = 20212022
    `);

    console.log('Year 20212022 coverage:');
    console.log(`  Records: ${yearCheck.rows[0].count}`);
    console.log(`  Date range: ${yearCheck.rows[0].min_date} to ${yearCheck.rows[0].max_date}\n`);

    // Check specifically for Nov 21, 2025
    const dateCheck = await desktopPool.query(`
      SELECT week_id, week_no, week_start, week_end
      FROM jc_week
      WHERE org_id = 1
        AND year_id = 20212022
        AND '2025-11-21' BETWEEN week_start AND week_end
    `);

    if (dateCheck.rows.length > 0) {
      console.log('Week found for 2025-11-21:');
      console.log(`  week_id: ${dateCheck.rows[0].week_id}`);
      console.log(`  week_no: ${dateCheck.rows[0].week_no}`);
      console.log(`  week_start: ${dateCheck.rows[0].week_start}`);
      console.log(`  week_end: ${dateCheck.rows[0].week_end}\n`);
    } else {
      console.log('[ERROR] No week found for date 2025-11-21 in year_id 20212022!\n');

      // Show available weeks
      const allWeeks = await desktopPool.query(`
        SELECT week_id, week_no, week_start, week_end
        FROM jc_week
        WHERE org_id = 1 AND year_id = 20212022
        ORDER BY week_start
        LIMIT 10
      `);

      console.log('Available weeks (first 10):');
      for (const week of allWeeks.rows) {
        console.log(`  week ${week.week_no}: ${week.week_start} to ${week.week_end}`);
      }
    }

    // Check all year_ids available
    console.log('\nAll available year_ids in jc_week:');
    const years = await desktopPool.query(`
      SELECT DISTINCT year_id, COUNT(*) as week_count
      FROM jc_week
      GROUP BY year_id
      ORDER BY year_id DESC
      LIMIT 10
    `);

    for (const year of years.rows) {
      console.log(`  year_id ${year.year_id}: ${year.week_count} weeks`);
    }

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await desktopPool.end();
  }
}

checkJcWeek();
