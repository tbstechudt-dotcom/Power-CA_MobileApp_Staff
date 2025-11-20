const { Pool } = require('pg');
require('dotenv').config();

const desktopPool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: 'Postgres',
  max: 10,
});

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
  max: 10,
});

async function syncSporgIdData() {
  try {
    console.log('[INFO] Syncing sporg_id values from desktop to Supabase...\n');

    // Fetch job_id and sporg_id from desktop where sporg_id is NOT NULL
    const desktopData = await desktopPool.query(`
      SELECT job_id, sporg_id
      FROM jobshead
      WHERE sporg_id IS NOT NULL
      ORDER BY job_id
    `);

    console.log(`[INFO] Found ${desktopData.rows.length} jobs with sporg_id in desktop database\n`);

    if (desktopData.rows.length === 0) {
      console.log('[INFO] No sporg_id values to sync');
      await desktopPool.end();
      await supabasePool.end();
      return;
    }

    // Show sample data
    console.log('[INFO] Sample sporg_id values:');
    desktopData.rows.slice(0, 5).forEach(row => {
      console.log(`      job_id: ${row.job_id}, sporg_id: ${row.sporg_id}`);
    });
    console.log('');

    // Update Supabase in batches
    const BATCH_SIZE = 100;
    let updated = 0;
    let notFound = 0;

    for (let i = 0; i < desktopData.rows.length; i += BATCH_SIZE) {
      const batch = desktopData.rows.slice(i, i + BATCH_SIZE);

      for (const row of batch) {
        // Update sporg_id in Supabase where job_id matches
        const result = await supabasePool.query(`
          UPDATE jobshead
          SET sporg_id = $1, updated_at = NOW()
          WHERE job_id = $2
        `, [row.sporg_id, row.job_id]);

        if (result.rowCount > 0) {
          updated++;
        } else {
          notFound++;
        }
      }

      const progress = Math.min(i + BATCH_SIZE, desktopData.rows.length);
      console.log(`[...] Progress: ${progress}/${desktopData.rows.length} (${Math.round(progress / desktopData.rows.length * 100)}%)`);
    }

    console.log('\n[OK] Sync completed!');
    console.log(`    Updated: ${updated} jobs`);
    console.log(`    Not found in Supabase: ${notFound} jobs`);

    // Verify results
    const verification = await supabasePool.query(`
      SELECT COUNT(*) as count
      FROM jobshead
      WHERE sporg_id IS NOT NULL
    `);

    console.log(`\n[OK] Verification: ${verification.rows[0].count} jobs in Supabase now have sporg_id`);

    await desktopPool.end();
    await supabasePool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await desktopPool.end();
    await supabasePool.end();
  }
}

syncSporgIdData();
