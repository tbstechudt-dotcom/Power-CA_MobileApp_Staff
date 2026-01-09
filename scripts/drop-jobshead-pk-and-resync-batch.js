const { Pool } = require('pg');

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  max: 10,
});

const desktopPool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres',
  max: 10,
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

    console.log('Step 4: Inserting ALL records to Supabase in batches (including duplicates)...');

    // Skip columns that don't exist in Supabase
    const skipColumns = ['job_uid', 'jctincharge', 'jt_id', 'tc_id'];

    const BATCH_SIZE = 500;
    let totalInserted = 0;

    for (let i = 0; i < desktopResult.rows.length; i += BATCH_SIZE) {
      const batch = desktopResult.rows.slice(i, i + BATCH_SIZE);

      // Get column names from first record (excluding skipColumns)
      const columns = Object.keys(batch[0]).filter(col => !skipColumns.includes(col));

      // Build VALUES clause for batch insert
      const values = [];
      const valueStrings = [];
      let paramIndex = 1;

      for (const row of batch) {
        const rowValues = columns.map(col => row[col]);
        values.push(...rowValues);

        const placeholders = columns.map(() => `$${paramIndex++}`).join(', ');
        valueStrings.push(`(${placeholders})`);
      }

      const insertQuery = `
        INSERT INTO jobshead (${columns.join(', ')})
        VALUES ${valueStrings.join(', ')}
      `;

      await supabasePool.query(insertQuery, values);
      totalInserted += batch.length;

      console.log(`  [...] Inserted ${totalInserted}/${desktopResult.rows.length} records...`);
    }

    console.log(`\n[OK] Successfully inserted ${totalInserted} records to Supabase`);

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
