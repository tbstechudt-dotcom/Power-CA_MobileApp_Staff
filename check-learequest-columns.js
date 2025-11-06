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
    // Get column names for learequest table
    const result = await pool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'learequest'
      ORDER BY ordinal_position
    `);

    console.log('Columns in learequest table:');
    console.log('============================');
    result.rows.forEach(row => {
      console.log(`${row.column_name} (${row.data_type})`);
    });

    // Check specific columns we're using
    const columnsWeUse = ['lr_id', 'lrid', 'lr_status', 'lrstatus', 'staff_id', 'staffid'];
    console.log('\nChecking columns we use:');
    columnsWeUse.forEach(col => {
      const exists = result.rows.some(row => row.column_name === col);
      console.log(`${col}: ${exists ? '✓ EXISTS' : '✗ NOT FOUND'}`);
    });

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkColumns();
