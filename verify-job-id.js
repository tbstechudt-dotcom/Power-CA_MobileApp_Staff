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

async function verify() {
  const result = await supabasePool.query(`
    SELECT tc_id, task_id, job_id, checklistdesc
    FROM taskchecklist
    WHERE job_id IS NOT NULL
    ORDER BY tc_id DESC
    LIMIT 5
  `);

  console.log('Supabase taskchecklist with job_id populated:');
  result.rows.forEach((row, idx) => {
    console.log(`${idx + 1}. tc_id: ${row.tc_id}, task_id: ${row.task_id}, job_id: ${row.job_id}`);
  });

  await supabasePool.end();
}
verify();
