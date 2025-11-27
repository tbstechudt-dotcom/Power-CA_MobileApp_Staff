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
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres',
  max: 10
});

async function checkReverseSyncData() {
  console.log('Checking reverse sync data for workdiary and learequest...\n');

  try {
    // Check Supabase workdiary
    const supabaseWorkdiary = await supabasePool.query('SELECT COUNT(*) FROM workdiary');
    console.log(`Supabase workdiary records: ${supabaseWorkdiary.rows[0].count}`);

    // Check Desktop workdiary
    const desktopWorkdiary = await desktopPool.query('SELECT COUNT(*) FROM workdiary');
    console.log(`Desktop workdiary records: ${desktopWorkdiary.rows[0].count}`);

    // Check Supabase learequest
    const supabaseLearequest = await supabasePool.query('SELECT COUNT(*) FROM learequest');
    console.log(`Supabase learequest records: ${supabaseLearequest.rows[0].count}`);

    // Check Desktop learequest
    const desktopLearequest = await desktopPool.query('SELECT COUNT(*) FROM learequest');
    console.log(`Desktop learequest records: ${desktopLearequest.rows[0].count}`);

    console.log('\n--- Checking for mobile-created records (source=M) ---');

    // Check for mobile-created workdiary in Supabase
    const mobileWorkdiary = await supabasePool.query("SELECT COUNT(*) FROM workdiary WHERE source = 'M'");
    console.log(`Supabase workdiary with source='M': ${mobileWorkdiary.rows[0].count}`);

    // Check for mobile-created learequest in Supabase
    const mobileLearequest = await supabasePool.query("SELECT COUNT(*) FROM learequest WHERE source = 'M'");
    console.log(`Supabase learequest with source='M': ${mobileLearequest.rows[0].count}`);

    console.log('\n--- Sample workdiary records from Supabase ---');
    const sampleWorkdiary = await supabasePool.query('SELECT * FROM workdiary LIMIT 5');
    console.log(`Found ${sampleWorkdiary.rows.length} sample records`);
    if (sampleWorkdiary.rows.length > 0) {
      console.log('Columns:', Object.keys(sampleWorkdiary.rows[0]));
      sampleWorkdiary.rows.forEach((row, i) => {
        console.log(`${i + 1}. wd_id=${row.wd_id}, job_id=${row.job_id}, staff_id=${row.staff_id}, source=${row.source}`);
      });
    }

    console.log('\n--- Sample learequest records from Supabase ---');
    const sampleLearequest = await supabasePool.query('SELECT * FROM learequest LIMIT 5');
    console.log(`Found ${sampleLearequest.rows.length} sample records`);
    if (sampleLearequest.rows.length > 0) {
      console.log('Columns:', Object.keys(sampleLearequest.rows[0]));
      sampleLearequest.rows.forEach((row, i) => {
        console.log(`${i + 1}. lea_id=${row.lea_id}, staff_id=${row.staff_id}, source=${row.source}`);
      });
    }

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await supabasePool.end();
    await desktopPool.end();
  }
}

checkReverseSyncData();
