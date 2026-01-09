const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkDuplicates() {
  try {
    // Get sample client (ALAGAMMAI based on screenshot)
    const clientResult = await pool.query(`
      SELECT client_id FROM climaster WHERE clientname = 'ALAGAMMAI' LIMIT 1
    `);

    if (clientResult.rows.length === 0) {
      console.log('Client ALAGAMMAI not found');
      await pool.end();
      return;
    }

    const clientId = clientResult.rows[0].client_id;
    console.log('Client ID:', clientId);
    console.log('');

    // Get jobs for this client
    const jobsResult = await pool.query(`
      SELECT job_id, work_desc, client_id
      FROM jobshead
      WHERE client_id = $1
      ORDER BY work_desc
    `, [clientId]);

    console.log('Jobs for ALAGAMMAI:');
    console.log('Total:', jobsResult.rows.length);
    console.log('');

    jobsResult.rows.forEach((row, index) => {
      console.log(`${index + 1}. job_id: ${row.job_id}, work_desc: ${row.work_desc}`);
    });

    // Check for duplicate work_desc
    const workDescCounts = {};
    jobsResult.rows.forEach(row => {
      const desc = row.work_desc || 'NULL';
      workDescCounts[desc] = (workDescCounts[desc] || 0) + 1;
    });

    console.log('');
    console.log('Duplicate work_desc values:');
    let hasDuplicates = false;
    Object.entries(workDescCounts).forEach(([desc, count]) => {
      if (count > 1) {
        console.log(`  "${desc}": ${count} times`);
        hasDuplicates = true;
      }
    });

    if (!hasDuplicates) {
      console.log('  No duplicates found');
    }

    await pool.end();
  } catch (err) {
    console.log('Error:', err.message);
    await pool.end();
  }
}

checkDuplicates();
