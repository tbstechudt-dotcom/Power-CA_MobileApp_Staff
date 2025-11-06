/**
 * Compare remdetail columns between local and Supabase
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

async function compareColumns() {
  try {
    console.log('='.repeat(70));
    console.log('REMDETAIL COLUMN COMPARISON');
    console.log('='.repeat(70));

    const localCols = await localPool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'mbremdetail'
      ORDER BY ordinal_position
    `);

    const supaCols = await supabasePool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'remdetail'
      ORDER BY ordinal_position
    `);

    console.log('\nLocal mbremdetail columns:');
    const localNames = localCols.rows.map(r => r.column_name);
    localNames.forEach(c => console.log('  -', c));

    console.log('\nSupabase remdetail columns:');
    const supaNames = supaCols.rows.map(r => r.column_name);
    supaNames.forEach(c => console.log('  -', c));

    console.log('\nIn local but NOT in Supabase:');
    localNames.filter(c => !supaNames.includes(c)).forEach(c => console.log('  -', c));

    console.log('\nIn Supabase but NOT in local:');
    supaNames.filter(c => !localNames.includes(c)).forEach(c => console.log('  -', c));

    console.log('\n' + '='.repeat(70));

    await localPool.end();
    await supabasePool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

compareColumns();
