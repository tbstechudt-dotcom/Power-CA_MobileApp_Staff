require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkTables() {
  const tables = ['orgmaster', 'locmaster', 'conmaster', 'climaster', 'mbstaff', 'jobshead', 'mbreminder'];

  for (const table of tables) {
    const result = await pool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = $1
      ORDER BY ordinal_position
    `, [table]);

    console.log(`${table}: ${result.rows.map(r => r.column_name).join(', ')}`);
  }

  await pool.end();
}

checkTables();
