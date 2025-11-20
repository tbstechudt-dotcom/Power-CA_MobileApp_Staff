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

async function addSporgIdColumn() {
  try {
    console.log('[INFO] Adding sporg_id column to Supabase jobshead table...\n');

    // Check if column already exists
    const columnCheck = await pool.query(`
      SELECT column_name, data_type, numeric_precision, numeric_scale, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'jobshead' AND column_name = 'sporg_id'
    `);

    if (columnCheck.rows.length > 0) {
      console.log('[WARN] sporg_id column already exists in Supabase jobshead table!');
      console.log(`      Type: ${columnCheck.rows[0].data_type}(${columnCheck.rows[0].numeric_precision},${columnCheck.rows[0].numeric_scale})`);
      console.log(`      Nullable: ${columnCheck.rows[0].is_nullable}`);
      await pool.end();
      return;
    }

    // Add the column (matching desktop schema: numeric(8,0), nullable)
    await pool.query(`
      ALTER TABLE jobshead
      ADD COLUMN sporg_id NUMERIC(8,0)
    `);

    console.log('[OK] Column added successfully!');

    // Verify it was added
    const verifyCheck = await pool.query(`
      SELECT column_name, data_type, numeric_precision, numeric_scale, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'jobshead' AND column_name = 'sporg_id'
    `);

    if (verifyCheck.rows.length > 0) {
      console.log(`[OK] Verified: sporg_id column exists`);
      console.log(`    Type: ${verifyCheck.rows[0].data_type}(${verifyCheck.rows[0].numeric_precision},${verifyCheck.rows[0].numeric_scale})`);
      console.log(`    Nullable: ${verifyCheck.rows[0].is_nullable}`);
    }

    // Check if there's any data in desktop database that has sporg_id values
    console.log('\n[INFO] Next step: Sync sporg_id values from desktop to Supabase');
    console.log('       This will populate the new column with existing data from desktop database');

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
  }
}

addSporgIdColumn();
