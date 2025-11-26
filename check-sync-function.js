const { Pool } = require('pg');
require('dotenv').config();

const desktopPool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres',
  max: 10
});

async function checkSyncFunction() {
  console.log('Checking sync_views_to_tables() function in desktop database...\n');

  try {
    // Check if function exists
    const functionCheck = await desktopPool.query(`
      SELECT
        p.proname as function_name,
        pg_get_functiondef(p.oid) as function_definition
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'sync_views_to_tables'
        AND n.nspname = 'public'
    `);

    if (functionCheck.rows.length === 0) {
      console.log('[X] Function sync_views_to_tables() not found in database');
      return;
    }

    console.log('[OK] Function sync_views_to_tables() exists\n');
    console.log('Function Definition:');
    console.log('='.repeat(80));
    console.log(functionCheck.rows[0].function_definition);
    console.log('='.repeat(80));

    // Try to call the function
    console.log('\nAttempting to call sync_views_to_tables()...\n');

    const startTime = Date.now();
    await desktopPool.query('SELECT sync_views_to_tables()');
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`[OK] sync_views_to_tables() completed successfully in ${duration}s\n`);

    // Check what tables were updated
    console.log('Checking mobile sync tables in desktop database...\n');
    const tables = ['jobshead', 'jobtasks', 'taskchecklist', 'workdiary', 'climaster', 'mbstaff'];

    for (const table of tables) {
      const result = await desktopPool.query(`SELECT COUNT(*) FROM ${table}`);
      console.log(`  ${table}: ${result.rows[0].count} records`);
    }

  } catch (error) {
    console.error('[X] Error:', error.message);
    console.error(error);
  } finally {
    await desktopPool.end();
  }
}

checkSyncFunction();
