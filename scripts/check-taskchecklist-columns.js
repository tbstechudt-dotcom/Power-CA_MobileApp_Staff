/**
 * Check taskchecklist columns in local and Supabase
 */

require('dotenv').config();
const { Pool } = require('pg');

const localPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
  database: process.env.SUPABASE_DB_NAME || 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkColumns() {
  try {
    console.log('='.repeat(60));
    console.log('TASKCHECKLIST COLUMN COMPARISON');
    console.log('='.repeat(60));

    // Local columns
    console.log('\nLocal (enterprise_db) columns:');
    const localCols = await localPool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist'
      ORDER BY ordinal_position
    `);
    localCols.rows.forEach(r => console.log('  -', r.column_name));

    // Supabase columns
    console.log('\nSupabase columns:');
    const supabaseCols = await supabasePool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist'
      ORDER BY ordinal_position
    `);
    supabaseCols.rows.forEach(r => console.log('  -', r.column_name));

    // Comparison
    const localColNames = localCols.rows.map(r => r.column_name);
    const supabaseColNames = supabaseCols.rows.map(r => r.column_name);

    console.log('\nColumns in local but NOT in Supabase:');
    localColNames.filter(c => !supabaseColNames.includes(c)).forEach(c => console.log('  -', c));

    console.log('\nColumns in Supabase but NOT in local:');
    supabaseColNames.filter(c => !localColNames.includes(c)).forEach(c => console.log('  -', c));

    console.log('\n' + '='.repeat(60));

    await localPool.end();
    await supabasePool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkColumns();
