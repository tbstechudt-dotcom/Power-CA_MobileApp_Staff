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

async function addJobUidColumn() {
  try {
    console.log('[INFO] Adding job_uid column to Supabase jobshead table...\n');

    // Add the column
    await pool.query(`
      ALTER TABLE jobshead
      ADD COLUMN IF NOT EXISTS job_uid VARCHAR(25)
    `);

    console.log('[OK] Column added successfully!');

    // Verify it was added
    const columnCheck = await pool.query(`
      SELECT column_name, data_type, character_maximum_length
      FROM information_schema.columns
      WHERE table_name = 'jobshead' AND column_name = 'job_uid'
    `);

    if (columnCheck.rows.length > 0) {
      console.log(`[OK] Verified: job_uid column exists`);
      console.log(`    Type: ${columnCheck.rows[0].data_type}(${columnCheck.rows[0].character_maximum_length})`);
    }

    console.log('\n[INFO] Next step: Run sync to populate job_uid values');
    console.log('       Command: node sync/production/runner-staging.js --mode=full');

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
  }
}

addJobUidColumn();
