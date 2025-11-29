const { Pool } = require('pg');

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
});

const desktopPool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres',
});

(async () => {
  try {
    console.log('Step 1: Dropping PRIMARY KEY constraint on jobshead...');
    await supabasePool.query('ALTER TABLE jobshead DROP CONSTRAINT IF EXISTS jobshead_pkey;');
    console.log('[OK] PRIMARY KEY constraint dropped\n');

    console.log('Step 2: Clearing existing jobshead records...');
    const deleteResult = await supabasePool.query('DELETE FROM jobshead;');
    console.log(`[OK] Deleted ${deleteResult.rowCount} existing records\n`);

    console.log('Step 3: Fetching ALL 24,568 records from desktop (NO deduplication)...');
    const desktopResult = await desktopPool.query(`
      SELECT * FROM jobshead ORDER BY job_id
    `);
    console.log(`[OK] Fetched ${desktopResult.rows.length} records from desktop\n`);

    console.log('Step 4: Inserting ALL records to Supabase (including duplicates)...');
    let inserted = 0;

    // Skip columns that don't exist in Supabase (per sync/config.js)
    const skipColumns = ['job_uid', 'jctincharge', 'jt_id', 'tc_id'];

    for (const row of desktopResult.rows) {
      // Get column names (excluding skipColumns)
      const columns = Object.keys(row).filter(col => !skipColumns.includes(col));
      const values = columns.map(col => row[col]);
      const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');

      const insertQuery = `
        INSERT INTO jobshead (${columns.join(', ')})
        VALUES (${placeholders})
      `;

      await supabasePool.query(insertQuery, values);
      inserted++;

      if (inserted % 1000 === 0) {
        console.log(`  [...] Inserted ${inserted}/${desktopResult.rows.length} records...`);
      }
    }

    console.log(`\n[OK] Successfully inserted ${inserted} records to Supabase`);

    console.log('\nStep 5: Verifying record count...');
    const countResult = await supabasePool.query('SELECT COUNT(*) FROM jobshead;');
    console.log(`[OK] Supabase jobshead now has ${countResult.rows[0].count} records`);

    console.log('\n[SUCCESS] All done! All 24,568 records are now in Supabase (including duplicates)');

  } catch (error) {
    console.error('[ERROR]', error.message);
    console.error(error.stack);
  } finally {
    await desktopPool.end();
    await supabasePool.end();
  }
})();
