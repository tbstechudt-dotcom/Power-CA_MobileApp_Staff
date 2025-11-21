const { Pool } = require('pg');
require('dotenv').config();

// Desktop PostgreSQL connection (using environment variables)
const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'powerca',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD,
});

// Supabase connection
const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '6543'),
  database: 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres.jacqfogzgzvbjeizljqf',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function addJobIdToTaskchecklist() {
  console.log('='.repeat(60));
  console.log('Adding job_id column to taskchecklist table');
  console.log('='.repeat(60));

  try {
    // ========== DESKTOP DATABASE ==========
    console.log('\n[1/4] Checking desktop database structure...');

    // Check if job_id column already exists in desktop
    const desktopColumnCheck = await desktopPool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist' AND column_name = 'job_id'
    `);

    if (desktopColumnCheck.rows.length > 0) {
      console.log('[OK] job_id column already exists in desktop taskchecklist');
    } else {
      console.log('[INFO] Adding job_id column to desktop taskchecklist...');
      await desktopPool.query(`
        ALTER TABLE taskchecklist
        ADD COLUMN job_id INTEGER
      `);
      console.log('[OK] Added job_id column to desktop taskchecklist');
    }

    // Get count before update
    const desktopBeforeCount = await desktopPool.query(`
      SELECT COUNT(*) as total,
             COUNT(job_id) as with_job_id
      FROM taskchecklist
    `);
    console.log(`\n[2/4] Desktop taskchecklist: ${desktopBeforeCount.rows[0].total} total, ${desktopBeforeCount.rows[0].with_job_id} with job_id`);

    // Update job_id by matching task_id with jobtasks
    console.log('[INFO] Populating job_id from jobtasks (matching task_id)...');

    const desktopUpdateResult = await desktopPool.query(`
      UPDATE taskchecklist tc
      SET job_id = jt.job_id
      FROM (
        SELECT DISTINCT task_id, job_id
        FROM jobtasks
        WHERE task_id IS NOT NULL AND job_id IS NOT NULL
      ) jt
      WHERE tc.task_id = jt.task_id
      AND tc.job_id IS NULL
    `);

    console.log(`[OK] Updated ${desktopUpdateResult.rowCount} records in desktop taskchecklist`);

    // Verify desktop update
    const desktopAfterCount = await desktopPool.query(`
      SELECT COUNT(*) as total,
             COUNT(job_id) as with_job_id,
             COUNT(*) - COUNT(job_id) as without_job_id
      FROM taskchecklist
    `);
    console.log(`[OK] Desktop after update: ${desktopAfterCount.rows[0].with_job_id}/${desktopAfterCount.rows[0].total} have job_id`);
    if (desktopAfterCount.rows[0].without_job_id > 0) {
      console.log(`[WARN] ${desktopAfterCount.rows[0].without_job_id} records still without job_id (task_id not found in jobtasks)`);
    }

    // ========== SUPABASE DATABASE ==========
    console.log('\n[3/4] Checking Supabase database structure...');

    // Check if job_id column already exists in Supabase
    const supabaseColumnCheck = await supabasePool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist' AND column_name = 'job_id'
    `);

    if (supabaseColumnCheck.rows.length > 0) {
      console.log('[OK] job_id column already exists in Supabase taskchecklist');
    } else {
      console.log('[INFO] Adding job_id column to Supabase taskchecklist...');
      await supabasePool.query(`
        ALTER TABLE taskchecklist
        ADD COLUMN job_id INTEGER
      `);
      console.log('[OK] Added job_id column to Supabase taskchecklist');
    }

    // Get count before update
    const supabaseBeforeCount = await supabasePool.query(`
      SELECT COUNT(*) as total,
             COUNT(job_id) as with_job_id
      FROM taskchecklist
    `);
    console.log(`\n[4/4] Supabase taskchecklist: ${supabaseBeforeCount.rows[0].total} total, ${supabaseBeforeCount.rows[0].with_job_id} with job_id`);

    // Update job_id by matching task_id with jobtasks
    console.log('[INFO] Populating job_id from jobtasks (matching task_id)...');

    const supabaseUpdateResult = await supabasePool.query(`
      UPDATE taskchecklist tc
      SET job_id = jt.job_id
      FROM (
        SELECT DISTINCT task_id, job_id
        FROM jobtasks
        WHERE task_id IS NOT NULL AND job_id IS NOT NULL
      ) jt
      WHERE tc.task_id = jt.task_id
      AND tc.job_id IS NULL
    `);

    console.log(`[OK] Updated ${supabaseUpdateResult.rowCount} records in Supabase taskchecklist`);

    // Verify Supabase update
    const supabaseAfterCount = await supabasePool.query(`
      SELECT COUNT(*) as total,
             COUNT(job_id) as with_job_id,
             COUNT(*) - COUNT(job_id) as without_job_id
      FROM taskchecklist
    `);
    console.log(`[OK] Supabase after update: ${supabaseAfterCount.rows[0].with_job_id}/${supabaseAfterCount.rows[0].total} have job_id`);
    if (supabaseAfterCount.rows[0].without_job_id > 0) {
      console.log(`[WARN] ${supabaseAfterCount.rows[0].without_job_id} records still without job_id (task_id not found in jobtasks)`);
    }

    // ========== VERIFICATION ==========
    console.log('\n' + '='.repeat(60));
    console.log('VERIFICATION - Sample records with job_id populated');
    console.log('='.repeat(60));

    // Show sample from desktop
    const desktopSample = await desktopPool.query(`
      SELECT tc_id, task_id, job_id, checklistdesc
      FROM taskchecklist
      WHERE job_id IS NOT NULL
      ORDER BY tc_id DESC
      LIMIT 5
    `);

    console.log('\nDesktop sample (5 records):');
    desktopSample.rows.forEach((row, idx) => {
      console.log(`  ${idx + 1}. tc_id: ${row.tc_id}, task_id: ${row.task_id}, job_id: ${row.job_id}`);
      console.log(`     desc: ${(row.checklistdesc || '').substring(0, 50)}...`);
    });

    // Show sample from Supabase
    const supabaseSample = await supabasePool.query(`
      SELECT tc_id, task_id, job_id, checklistdesc
      FROM taskchecklist
      WHERE job_id IS NOT NULL
      ORDER BY tc_id DESC
      LIMIT 5
    `);

    console.log('\nSupabase sample (5 records):');
    supabaseSample.rows.forEach((row, idx) => {
      console.log(`  ${idx + 1}. tc_id: ${row.tc_id}, task_id: ${row.task_id}, job_id: ${row.job_id}`);
      console.log(`     desc: ${(row.checklistdesc || '').substring(0, 50)}...`);
    });

    console.log('\n' + '='.repeat(60));
    console.log('[SUCCESS] job_id column added and populated in both databases!');
    console.log('='.repeat(60));

  } catch (err) {
    console.error('[ERROR]', err.message);
    throw err;
  } finally {
    await desktopPool.end();
    await supabasePool.end();
  }
}

addJobIdToTaskchecklist();
