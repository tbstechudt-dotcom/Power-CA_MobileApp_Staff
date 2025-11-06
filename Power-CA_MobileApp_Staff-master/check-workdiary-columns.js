const { Pool } = require('pg');

const pool = new Pool({
  host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Powerca@2025',
  ssl: { rejectUnauthorized: false }
});

async function checkColumns() {
  try {
    // Get column names for workdiary table
    const result = await pool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'workdiary'
      ORDER BY ordinal_position
    `);

    console.log('Columns in workdiary table:');
    console.log('============================');
    result.rows.forEach(row => {
      console.log(`${row.column_name} (${row.data_type})`);
    });

    // Check specific columns we're using
    const columnsWeUse = ['staff_id', 'staffid', 'job_id'];
    console.log('\nChecking columns we use:');
    columnsWeUse.forEach(col => {
      const exists = result.rows.some(row => row.column_name === col);
      console.log(`${col}: ${exists ? '✓ EXISTS' : '✗ NOT FOUND'}`);
    });

    // Check mbstaff table to see how staff is tracked
    console.log('\n\nChecking mbstaff table columns:');
    const staffResult = await pool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'mbstaff'
      ORDER BY ordinal_position
    `);

    console.log('\nColumns in mbstaff table:');
    console.log('============================');
    staffResult.rows.forEach(row => {
      console.log(`${row.column_name} (${row.data_type})`);
    });

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkColumns();
