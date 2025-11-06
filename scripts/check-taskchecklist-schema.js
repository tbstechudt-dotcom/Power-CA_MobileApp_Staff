/**
 * Check taskchecklist schema in Supabase
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
  database: process.env.SUPABASE_DB_NAME || 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkSchema() {
  try {
    console.log('='.repeat(70));
    console.log('SUPABASE TASKCHECKLIST SCHEMA');
    console.log('='.repeat(70));

    const result = await pool.query(`
      SELECT column_name, is_nullable, column_default, data_type
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist'
      ORDER BY ordinal_position
    `);

    console.log('\nColumn'.padEnd(25) + 'Type'.padEnd(20) + 'Nullable'.padEnd(12) + 'Default');
    console.log('-'.repeat(70));

    result.rows.forEach(r => {
      const nullable = r.is_nullable === 'YES' ? 'YES' : 'NO';
      const def = r.column_default || 'none';
      console.log(
        r.column_name.padEnd(25) +
        r.data_type.padEnd(20) +
        nullable.padEnd(12) +
        def
      );
    });

    console.log('\n' + '='.repeat(70));

    await pool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkSchema();
