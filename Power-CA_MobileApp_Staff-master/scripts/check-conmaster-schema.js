/**
 * Check conmaster schema
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
    console.log('Checking conmaster schema...\n');

    // Get all columns
    const columns = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'conmaster'
      ORDER BY ordinal_position
    `);

    console.log('conmaster columns:');
    columns.rows.forEach(col => {
      console.log(`  - ${col.column_name} (${col.data_type}, nullable: ${col.is_nullable})`);
    });

    // Get sample record
    console.log('\nSample records:');
    const sample = await pool.query('SELECT * FROM conmaster LIMIT 3');
    console.log(sample.rows);

    await pool.end();

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkSchema();
