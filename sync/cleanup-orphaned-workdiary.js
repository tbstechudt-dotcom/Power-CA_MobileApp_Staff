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

const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5432'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function cleanupOrphanedWorkdiary() {
  console.log('='.repeat(80));
  console.log('CLEANUP ORPHANED WORKDIARY RECORDS');
  console.log('='.repeat(80));

  try {
    // Get mobile workdiary records
    const mobileRecords = await supabasePool.query(`
      SELECT wd_id, job_id, task_id, staff_id, date, tasknotes
      FROM workdiary
      WHERE source = 'M'
      ORDER BY date DESC
    `);

    console.log(`\nFound ${mobileRecords.rows.length} mobile workdiary records\n`);

    let deleted = 0;
    let fixed = 0;
    let kept = 0;

    for (const record of mobileRecords.rows) {
      console.log(`Processing wd_id: ${record.wd_id} (Job: ${record.job_id}, Task: ${record.task_id})`);

      // Skip if task_id is NULL - keep for manual review
      if (!record.task_id) {
        console.log('  [SKIP] task_id is NULL - keeping for manual review\n');
        kept++;
        continue;
      }

      // Check if job exists in desktop
      const jobExists = await desktopPool.query(
        'SELECT job_id FROM jobcard_head WHERE job_id = $1',
        [record.job_id]
      );

      if (jobExists.rows.length === 0) {
        console.log(`  [DELETE] Job ${record.job_id} not found in desktop\n`);
        await supabasePool.query('DELETE FROM workdiary WHERE wd_id = $1', [record.wd_id]);
        deleted++;
        continue;
      }

      // Check if task exists in desktop
      const taskExists = await desktopPool.query(
        'SELECT task_id FROM jobcard_det WHERE job_id = $1 AND task_id = $2',
        [record.job_id, record.task_id]
      );

      if (taskExists.rows.length === 0) {
        // Task doesn't exist - check if it exists in Supabase
        const supabaseTask = await supabasePool.query(
          'SELECT task_id FROM jobtasks WHERE job_id = $1 AND task_id = $2',
          [record.job_id, record.task_id]
        );

        if (supabaseTask.rows.length === 0) {
          // Orphaned - delete it
          console.log(`  [DELETE] Task ${record.task_id} not found anywhere (orphaned)\n`);
          await supabasePool.query('DELETE FROM workdiary WHERE wd_id = $1', [record.wd_id]);
          deleted++;
        } else {
          console.log(`  [KEEP] Task exists in Supabase (needs sync to desktop)\n`);
          kept++;
        }
      } else {
        console.log('  [OK] Task exists in desktop\n');
        kept++;
      }
    }

    console.log('='.repeat(80));
    console.log('CLEANUP SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total processed: ${mobileRecords.rows.length}`);
    console.log(`  - Deleted:     ${deleted} records`);
    console.log(`  - Kept:        ${kept} records`);

    console.log('\n' + '='.repeat(80));
    console.log('[SUCCESS] Cleanup completed!');
    console.log('='.repeat(80));

  } catch (error) {
    console.error('\n[ERROR] Cleanup failed:', error.message);
    process.exit(1);
  } finally {
    await supabasePool.end();
    await desktopPool.end();
  }
}

// Run if called directly
if (require.main === module) {
  cleanupOrphanedWorkdiary();
}

module.exports = { cleanupOrphanedWorkdiary };
