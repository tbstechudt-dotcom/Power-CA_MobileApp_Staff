/**
 * Simple sync for remaining tables
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
      return;
    }

    // 2. Clear target table
    await supabasePool.query(`DELETE FROM ${targetTable}`);
    console.log(`  ✓ Cleared ${targetTable} table`);

    // 3. Prepare insert
    const sampleRow = sourceData.rows[0];
    const columns = Object.keys(sampleRow).filter(col => !skipColumns.includes(col));

    // Add sync columns if not present
    const syncColumns = ['source', 'created_at', 'updated_at'];
    const finalColumns = [...columns, ...syncColumns.filter(c => !columns.includes(c))];

    const insertPromises = [];
    let succeeded = 0;
    let failed = 0;

    for (const row of sourceData.rows) {
      const values = finalColumns.map(col => {
        if (col === 'source') return 'D';
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
        if (succeeded % 100 === 0) {
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

  } catch (error) {
    console.error(`  ❌ Error syncing ${sourceTable}:`, error.message);
  }
}

async function main() {
  try {
    console.log('='.repeat(70));
    console.log('INCREMENTAL SYNC - REMAINING TABLES');
    console.log('='.repeat(70));

    // Sync taskchecklist (skip tc_id column)
    await syncTable('taskchecklist', 'taskchecklist', ['tc_id']);

    // Sync reminder (mbreminder)
    await syncTable('mbreminder', 'reminder');

    // Sync remdetail (mbremdetail)
    await syncTable('mbremdetail', 'remdetail');

    console.log('\n' + '='.repeat(70));
    console.log('✅ INCREMENTAL SYNC COMPLETE!');
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
