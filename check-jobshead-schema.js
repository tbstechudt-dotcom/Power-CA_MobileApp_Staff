const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkJobsheadSchema() {
  try {
    console.log('[INFO] Checking jobshead table schema...\n');

    // Get column info
    const columns = await pool.query(`
      SELECT column_name, data_type, character_maximum_length,
             is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'jobshead'
      ORDER BY ordinal_position
    `);

    console.log('jobshead table columns:');
    columns.rows.forEach(col => {
      const length = col.character_maximum_length ? `(${col.character_maximum_length})` : '';
      const nullable = col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL';
      const defaultVal = col.column_default ? ` DEFAULT ${col.column_default}` : '';
      console.log(`  - ${col.column_name}: ${col.data_type}${length} ${nullable}${defaultVal}`);
    });

    // Check sample data with client name
    const sampleData = await pool.query(`
      SELECT
        j.job_id,
        j.job_uid,
        j.sporg_id,
        j.job_status,
        j.jobdate,
        j.targetdate,
        j.work_desc,
        j.client_id,
        c.clientname
      FROM jobshead j
      LEFT JOIN climaster c ON j.client_id = c.client_id
      WHERE j.sporg_id IS NOT NULL
      ORDER BY j.job_id DESC
      LIMIT 5
    `);

    console.log(`\n\nSample records (${sampleData.rows.length} records):`);
    sampleData.rows.forEach((row, idx) => {
      console.log(`\n${idx + 1}. Job:`);
      Object.keys(row).forEach(key => {
        console.log(`   ${key}: ${row[key]}`);
      });
    });

    // Check status values
    const statuses = await pool.query(`
      SELECT DISTINCT job_status, COUNT(*) as count
      FROM jobshead
      WHERE job_status IS NOT NULL
      GROUP BY job_status
      ORDER BY count DESC
    `);

    console.log('\n\nJob statuses in database:');
    statuses.rows.forEach(row => {
      console.log(`  - ${row.job_status}: ${row.count} jobs`);
    });

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
  }
}

checkJobsheadSchema();
