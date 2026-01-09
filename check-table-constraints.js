const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkConstraints() {
  try {
    const tables = ['orgmaster', 'locmaster', 'conmaster', 'climaster', 'mbstaff',
                    'jobshead', 'jobtasks', 'taskchecklist', 'mbreminder', 'mbremdetail'];

    for (const table of tables) {
      console.log(`\n=== ${table} ===`);

      // Check primary keys
      const pk = await pool.query(`
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = $1::regclass
          AND i.indisprimary
      `, [table]);

      if (pk.rows.length === 0) {
        console.log('  Primary Key: NONE');
      } else {
        console.log(`  Primary Key: ${pk.rows.map(r => r.attname).join(', ')}`);
      }

      // Check unique constraints
      const unique = await pool.query(`
        SELECT
          conname AS constraint_name,
          array_agg(a.attname) AS columns
        FROM pg_constraint c
        JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
        WHERE c.conrelid = $1::regclass
          AND c.contype IN ('u', 'p')
        GROUP BY conname
      `, [table]);

      if (unique.rows.length === 0) {
        console.log('  Unique Constraints: NONE');
      } else {
        unique.rows.forEach(row => {
          console.log(`  Unique: ${row.constraint_name} (${row.columns.join(', ')})`);
        });
      }
    }

    await pool.end();
  } catch (error) {
    console.error('[ERROR]', error.message);
    await pool.end();
    process.exit(1);
  }
}

checkConstraints();
