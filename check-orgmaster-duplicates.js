const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function checkDuplicates() {
  try {
    // Check orgmaster table
    const result = await pool.query(`
      SELECT org_id, COUNT(*) as count
      FROM orgmaster
      GROUP BY org_id
      HAVING COUNT(*) > 1
      ORDER BY count DESC
    `);

    console.log('\n=== Duplicate org_id values in orgmaster ===\n');

    if (result.rows.length === 0) {
      console.log('[OK] No duplicates found!');
    } else {
      console.log(`[WARN] Found ${result.rows.length} duplicate org_id values:\n`);
      result.rows.forEach(row => {
        console.log(`  org_id: ${row.org_id}, count: ${row.count}`);
      });

      // Show the actual duplicate rows
      for (const dup of result.rows) {
        console.log(`\n--- Rows with org_id = ${dup.org_id} ---`);
        const rows = await pool.query(`
          SELECT * FROM orgmaster WHERE org_id = $1
        `, [dup.org_id]);

        rows.rows.forEach((row, i) => {
          console.log(`Row ${i+1}:`, JSON.stringify(row, null, 2));
        });
      }
    }

    await pool.end();
  } catch (error) {
    console.error('[ERROR]', error.message);
    process.exit(1);
  }
}

checkDuplicates();
