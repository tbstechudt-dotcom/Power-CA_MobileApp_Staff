const { Pool } = require('pg');
require('dotenv').config();

const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkTriggerFunctions() {
  console.log('Checking trigger functions...\n');

  try {
    const functions = ['bi_dailywork_func', 'ai_dailywork_func', 'au_dailywork_func', 'ad_dailywork_func'];

    for (const funcName of functions) {
      const result = await desktopPool.query(`
        SELECT pg_get_functiondef(oid) as function_definition
        FROM pg_proc
        WHERE proname = $1
      `, [funcName]);

      if (result.rows.length > 0) {
        console.log(`Function: ${funcName}`);
        console.log('='.repeat(80));
        console.log(result.rows[0].function_definition);
        console.log('\n\n');
      } else {
        console.log(`Function ${funcName} not found\n`);
      }
    }

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await desktopPool.end();
  }
}

checkTriggerFunctions();
