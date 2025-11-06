const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres'
});

async function checkColumns() {
  try {
    const result = await pool.query(`
      SELECT column_name, data_type, character_maximum_length
      FROM information_schema.columns
      WHERE table_name = 'mbstaff'
      ORDER BY ordinal_position
    `);

    console.log('\n=== Desktop mbstaff columns ===\n');
    result.rows.forEach(col => {
      const length = col.character_maximum_length ? `(${col.character_maximum_length})` : '';
      console.log(`  ${col.column_name.padEnd(25)} ${col.data_type}${length}`);
    });

    await pool.end();
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkColumns();
