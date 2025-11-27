const { Pool } = require('pg');
require('dotenv').config();

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '6543'),
  database: 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres.jacqfogzgzvbjeizljqf',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkColumns() {
  const result = await supabasePool.query(`
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_name = 'jobshead'
    ORDER BY ordinal_position
  `);

  console.log('jobshead columns:');
  result.rows.forEach(row => {
    console.log(`  - ${row.column_name} (${row.data_type})`);
  });

  await supabasePool.end();
}

checkColumns().catch(console.error);
