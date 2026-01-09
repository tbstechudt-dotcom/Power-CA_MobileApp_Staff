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

async function removeWorkdiaryTaskFK() {
  try {
    console.log('[INFO] Removing workdiary_task_id_fkey constraint...\n');

    // Remove the constraint
    await pool.query(`
      ALTER TABLE workdiary
      DROP CONSTRAINT IF EXISTS workdiary_task_id_fkey
    `);

    console.log('[OK] Successfully removed workdiary_task_id_fkey constraint!');
    console.log('[INFO] workdiary.task_id can now accept any value (including NULL)');
    console.log('[INFO] This matches desktop behavior where taskmaster is empty\n');

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
    process.exit(1);
  }
}

removeWorkdiaryTaskFK();
