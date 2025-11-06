/**
 * Sync missing jobs and tasks (after FK constraint removal)
 *
 * This syncs the 3,942 jobs that were previously filtered out
 * and the 11,842 tasks that reference those jobs
 */

require('dotenv').config();
const { Pool } = require('pg');
const config = require('./config');

const localPool = new Pool(config.source);
const supabasePool = new Pool({
  ...config.target,
  ssl: { rejectUnauthorized: false }
});

async function syncTable(sourceTable, targetTable, skipColumns = []) {
  try {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`Syncing: ${sourceTable} → ${targetTable}`);
    console.log('='.repeat(70));

    // 1. Extract from source
    const sourceData = await localPool.query(`SELECT * FROM ${sourceTable}`);
    console.log(`  ✓ Extracted ${sourceData.rows.length} records from source`);

    if (sourceData.rows.length === 0) {
      console.log('  ⚪ No records to sync\n');
      return { succeeded: 0, failed: 0, skipped: 0 };
    }

    // 2. Clear target table (full replacement) - Note: FK dependencies handled by caller

    // 3. Prepare insert
    const sampleRow = sourceData.rows[0];
    const columns = Object.keys(sampleRow).filter(col => !skipColumns.includes(col));

    // Add sync columns if not present
    const syncColumns = ['source', 'created_at', 'updated_at'];
    const finalColumns = [...columns, ...syncColumns.filter(c => !columns.includes(c))];

    let succeeded = 0;
    let failed = 0;

    for (const row of sourceData.rows) {
      const values = finalColumns.map(col => {
        if (col === 'source') return row[col] || 'D';
        if (col === 'created_at' || col === 'updated_at') return new Date();
        return row[col];
      });

      const placeholders = finalColumns.map((_, i) => `$${i + 1}`).join(', ');
      const insertQuery = `
        INSERT INTO ${targetTable} (${finalColumns.join(', ')})
        VALUES (${placeholders})
        ON CONFLICT DO NOTHING
      `;

      try {
        await supabasePool.query(insertQuery, values);
        succeeded++;
        if (succeeded % 1000 === 0) {
          console.log(`  ⏳ Processed ${succeeded}/${sourceData.rows.length} records...`);
        }
      } catch (error) {
        failed++;
        if (failed <= 5) {
          console.log(`  ⚠️  Error: ${error.message}`);
        }
      }
    }

    console.log(`  ✅ Synced ${succeeded} records`);
    if (failed > 0) {
      console.log(`  ⚠️  Failed ${failed} records`);
    }

    return { succeeded, failed };

  } catch (error) {
    console.error(`  ❌ Error syncing ${sourceTable}:`, error.message);
    return { succeeded: 0, failed: 0 };
  }
}

async function main() {
  try {
    console.log('='.repeat(70));
    console.log('SYNCING MISSING JOBS AND TASKS (FK Constraints Removed)');
    console.log('='.repeat(70));
    console.log('\nPreviously filtered records will now sync:');
    console.log('  - 3,942 jobs with invalid client_id');
    console.log('  - 11,842 tasks referencing those jobs\n');

    // IMPORTANT: Clear tables in FK dependency order (child before parent)
    console.log('\n🗑️  Clearing tables in FK dependency order...');
    console.log('   1. Clearing jobtasks (child table)...');
    await supabasePool.query(`DELETE FROM jobtasks`);
    console.log('   ✓ Cleared jobtasks');

    console.log('   2. Clearing jobshead (parent table)...');
    await supabasePool.query(`DELETE FROM jobshead`);
    console.log('   ✓ Cleared jobshead\n');

    // Sync jobshead (all 24,568 jobs)
    console.log('\n📋 Syncing ALL jobs (including previously filtered)...');
    const jobsResult = await syncTable('jobshead', 'jobshead', ['job_uid', 'sporg_id', 'jctincharge', 'jt_id', 'tc_id']);

    // Sync jobtasks (all 64,711 tasks)
    console.log('\n📋 Syncing ALL tasks (including previously filtered)...');
    const tasksResult = await syncTable('jobtasks', 'jobtasks', ['jt_id']);

    console.log('\n' + '='.repeat(70));
    console.log('SYNC SUMMARY');
    console.log('='.repeat(70));
    console.log(`  jobshead:  ${jobsResult.succeeded} succeeded, ${jobsResult.failed} failed`);
    console.log(`  jobtasks:  ${tasksResult.succeeded} succeeded, ${tasksResult.failed} failed`);
    console.log('='.repeat(70));

    console.log('\nExpected results:');
    console.log('  - jobshead: 24,568 total (previously 20,626)');
    console.log('  - jobtasks: 64,711 total (previously 52,869)');
    console.log('  - Gain: +3,942 jobs, +11,842 tasks');
    console.log('='.repeat(70));

    await localPool.end();
    await supabasePool.end();

  } catch (error) {
    console.error('\n❌ Sync failed:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

main();
