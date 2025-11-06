/**
 * Check jobshead table structure
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

(async () => {
  const cols = await pool.query(`
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = 'jobshead'
    ORDER BY ordinal_position
  `);

  console.log('Columns in jobshead:');
  cols.rows.forEach(r => console.log('  -', r.column_name));

  const sample = await pool.query('SELECT * FROM jobshead LIMIT 1');
  console.log('\nSample record:');
  console.log(JSON.stringify(sample.rows[0], null, 2));

  await pool.end();
})();
