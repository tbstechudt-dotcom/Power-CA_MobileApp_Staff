const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function getFunctionDefinition() {
  try {
    const result = await pool.query(`
      SELECT pg_get_functiondef(p.oid) as definition
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'sync_views_to_tables'
        AND n.nspname = 'public'
    `);

    if (result.rows.length === 0) {
      console.log('[X] Function not found');
    } else {
      console.log('Current Function Definition:\n');
      console.log(result.rows[0].definition);
    }

    await pool.end();
  } catch (error) {
    console.error('[ERROR]', error.message);
    await pool.end();
    process.exit(1);
  }
}

getFunctionDefinition();
