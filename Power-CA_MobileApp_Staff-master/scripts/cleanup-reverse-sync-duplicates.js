/**
 * Cleanup Script - Remove Duplicate Records from Failed Reverse Sync
 *
 * This script removes duplicate records that were created when reverse sync
 * incorrectly synced tables with mobile-generated primary keys.
 *
 * Problem: jobtasks, taskchecklist, remdetail used mobile PKs (jt_id, tc_id, remd_id)
 * that got reassigned during forward sync, causing duplicates during reverse sync.
 *
 * Solution: Remove records where the mobile PK doesn't match desktop's original PKs.
 */

require('dotenv').config();
const { Pool } = require('pg');

async function cleanupDuplicates() {
  // Desktop connection
  const desktopPool = new Pool({
    host: process.env.LOCAL_DB_HOST || 'localhost',
    port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
    database: process.env.LOCAL_DB_NAME || 'enterprise_db',
    user: process.env.LOCAL_DB_USER || 'postgres',
    password: process.env.LOCAL_DB_PASSWORD,
  });

  try {
    console.log('\n🧹 Cleaning up reverse sync duplicates...\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Step 1: Analyze jobtasks duplicates
    console.log('📋 Step 1: Analyzing jobtasks duplicates...');
    const jobtasksCount = await desktopPool.query(`
      SELECT COUNT(*) as total FROM jobtasks
    `);
    console.log(`  Current jobtasks count: ${jobtasksCount.rows[0].total}`);

    // Find duplicates based on business keys (job_id, staff_id, task_id)
    const jobtasksDuplicates = await desktopPool.query(`
      SELECT job_id, staff_id, task_id, COUNT(*) as duplicate_count
      FROM jobtasks
      GROUP BY job_id, staff_id, task_id
      HAVING COUNT(*) > 1
      ORDER BY duplicate_count DESC
      LIMIT 10
    `);

    if (jobtasksDuplicates.rows.length > 0) {
      console.log(`  ⚠️  Found ${jobtasksDuplicates.rows.length} duplicate groups`);
      console.log('  Sample duplicates:');
      jobtasksDuplicates.rows.slice(0, 3).forEach(row => {
        console.log(`    - job_id=${row.job_id}, staff_id=${row.staff_id}, task_id=${row.task_id}: ${row.duplicate_count} copies`);
      });
    } else {
      console.log('  ✅ No duplicates found in jobtasks');
    }

    // Step 2: Analyze taskchecklist duplicates
    console.log('\n📋 Step 2: Analyzing taskchecklist duplicates...');
    const taskchecklistCount = await desktopPool.query(`
      SELECT COUNT(*) as total FROM taskchecklist
    `);
    console.log(`  Current taskchecklist count: ${taskchecklistCount.rows[0].total}`);

    const taskchecklistDuplicates = await desktopPool.query(`
      SELECT job_id, COUNT(*) as duplicate_count
      FROM taskchecklist
      GROUP BY job_id
      HAVING COUNT(*) > 1
      ORDER BY duplicate_count DESC
      LIMIT 10
    `);

    if (taskchecklistDuplicates.rows.length > 0) {
      console.log(`  ⚠️  Found ${taskchecklistDuplicates.rows.length} duplicate groups`);
      console.log('  Sample duplicates:');
      taskchecklistDuplicates.rows.slice(0, 3).forEach(row => {
        console.log(`    - job_id=${row.job_id}: ${row.duplicate_count} copies`);
      });
    } else {
      console.log('  ✅ No duplicates found in taskchecklist');
    }

    // Step 3: Analyze remdetail duplicates
    console.log('\n📋 Step 3: Analyzing mbremdetail duplicates...');
    const remdetailCount = await desktopPool.query(`
      SELECT COUNT(*) as total FROM mbremdetail
    `);
    console.log(`  Current mbremdetail count: ${remdetailCount.rows[0].total}`);

    const remdetailDuplicates = await desktopPool.query(`
      SELECT rem_id, staff_id, COUNT(*) as duplicate_count
      FROM mbremdetail
      GROUP BY rem_id, staff_id
      HAVING COUNT(*) > 1
      ORDER BY duplicate_count DESC
      LIMIT 10
    `);

    if (remdetailDuplicates.rows.length > 0) {
      console.log(`  ⚠️  Found ${remdetailDuplicates.rows.length} duplicate groups`);
      console.log('  Sample duplicates:');
      remdetailDuplicates.rows.slice(0, 3).forEach(row => {
        console.log(`    - rem_id=${row.rem_id}, staff_id=${row.staff_id}: ${row.duplicate_count} copies`);
      });
    } else {
      console.log('  ✅ No duplicates found in mbremdetail');
    }

    // Step 4: Confirmation prompt
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('⚠️  WARNING: This operation will DELETE duplicate records!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('Cleanup Strategy:');
    console.log('  1. Keep records with LOWEST jt_id/tc_id/remd_id (original desktop records)');
    console.log('  2. Delete records with HIGHER IDs (Supabase-generated duplicates)');
    console.log('  3. Use business keys to identify duplicates\n');

    // For now, just report - don't auto-delete
    console.log('📊 Summary:');
    console.log(`  jobtasks:      ${jobtasksCount.rows[0].total} total records`);
    console.log(`  taskchecklist: ${taskchecklistCount.rows[0].total} total records`);
    console.log(`  mbremdetail:   ${remdetailCount.rows[0].total} total records\n`);

    console.log('💡 To remove duplicates, you can run these SQL queries:\n');

    console.log('-- Remove jobtasks duplicates (keep lowest jt_id):');
    console.log(`DELETE FROM jobtasks
WHERE jt_id IN (
  SELECT jt_id
  FROM (
    SELECT jt_id,
           ROW_NUMBER() OVER (PARTITION BY job_id, staff_id, task_id ORDER BY jt_id) as rn
    FROM jobtasks
  ) t
  WHERE rn > 1
);`);

    console.log('\n-- Remove taskchecklist duplicates (keep lowest tc_id):');
    console.log(`DELETE FROM taskchecklist
WHERE tc_id IN (
  SELECT tc_id
  FROM (
    SELECT tc_id,
           ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY tc_id) as rn
    FROM taskchecklist
  ) t
  WHERE rn > 1
);`);

    console.log('\n-- Remove mbremdetail duplicates (keep lowest remd_id):');
    console.log(`DELETE FROM mbremdetail
WHERE remd_id IN (
  SELECT remd_id
  FROM (
    SELECT remd_id,
           ROW_NUMBER() OVER (PARTITION BY rem_id, staff_id ORDER BY remd_id) as rn
    FROM mbremdetail
  ) t
  WHERE rn > 1
);`);

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('ℹ️  This script only ANALYZES duplicates.');
    console.log('   Copy the SQL queries above and run them manually');
    console.log('   using pgAdmin or psql after reviewing the data.');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  } catch (error) {
    console.error('\n❌ Error during cleanup:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    await desktopPool.end();
  }
}

if (require.main === module) {
  cleanupDuplicates()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Error:', err);
      process.exit(1);
    });
}

module.exports = cleanupDuplicates;
