const { Pool } = require('pg');
require('dotenv').config();

const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkTriggers() {
  console.log('Checking triggers on daily_work table...\n');

  try {
    const result = await desktopPool.query(`
      SELECT
        t.tgname as trigger_name,
        t.tgenabled as enabled,
        pg_get_triggerdef(t.oid) as trigger_definition
      FROM pg_trigger t
      JOIN pg_class c ON t.tgrelid = c.oid
      WHERE c.relname = 'daily_work'
        AND t.tgisinternal = false
      ORDER BY t.tgname
    `);

    if (result.rows.length === 0) {
      console.log('No triggers found on daily_work table.');
    } else {
      console.log(`Found ${result.rows.length} trigger(s):\n`);

      for (const row of result.rows) {
        console.log(`Trigger: ${row.trigger_name}`);
        console.log(`Enabled: ${row.enabled === 'O' ? 'Yes' : 'No'}`);
        console.log(`Definition:\n${row.trigger_definition}\n`);
        console.log('-'.repeat(80));
      }
    }

    // Also check jc_weeklyplan table structure
    console.log('\nChecking jc_weeklyplan table columns...\n');
    const columns = await desktopPool.query(`
      SELECT column_name, data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'jc_weeklyplan'
      ORDER BY ordinal_position
    `);

    if (columns.rows.length > 0) {
      console.log('jc_weeklyplan columns:');
      for (const col of columns.rows) {
        console.log(`  - ${col.column_name} (${col.data_type}) ${col.is_nullable === 'NO' ? 'NOT NULL' : 'NULL'} ${col.column_default ? `DEFAULT ${col.column_default}` : ''}`);
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await desktopPool.end();
  }
}

checkTriggers();
