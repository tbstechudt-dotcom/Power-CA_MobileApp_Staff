const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkTables() {
  try {
    // Check dailywork table structure
    const dailywork = await pool.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'dailywork'
      ORDER BY ordinal_position
    `);

    console.log('dailywork table columns:');
    console.log('========================');
    dailywork.rows.forEach(row => {
      console.log(`  ${row.column_name.padEnd(25)} ${row.data_type.padEnd(20)} ${row.is_nullable === 'YES' ? 'NULL' : 'NOT NULL'}`);
    });

    // Check workdiary structure in Supabase
    const supabasePool = new Pool({
      host: process.env.SUPABASE_DB_HOST,
      port: parseInt(process.env.SUPABASE_DB_PORT || '6543'),
      database: 'postgres',
      user: process.env.SUPABASE_DB_USER || 'postgres.jacqfogzgzvbjeizljqf',
      password: process.env.SUPABASE_DB_PASSWORD,
      ssl: { rejectUnauthorized: false }
    });

    const workdiary = await supabasePool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'workdiary'
      ORDER BY ordinal_position
    `);

    console.log('\nworkdiary table columns (Supabase):');
    console.log('====================================');
    workdiary.rows.forEach(row => {
      console.log(`  ${row.column_name.padEnd(25)} ${row.data_type}`);
    });

    await pool.end();
    await supabasePool.end();
  } catch (error) {
    console.error('Error:', error.message);
    await pool.end();
  }
}

checkTables();
