/**
 * Targeted sync for remaining tables only
 * Tables: taskchecklist, reminder, remdetail
 */

require('dotenv').config();
const SyncEngine = require('./engine-optimized');

async function syncRemainingTables() {
  const engine = new SyncEngine();

  try {
    console.log('='.repeat(70));
    console.log('TARGETED SYNC - REMAINING TABLES ONLY');
    console.log('='.repeat(70));
    console.log('Tables to sync: taskchecklist, reminder, remdetail');
    console.log('='.repeat(70));

    await engine.initialize();

    // Pre-load FK cache
    await engine.preloadForeignKeys();

    // Sync only the 3 remaining tables
    const tablesToSync = ['taskchecklist', 'mbreminder', 'mbremdetail'];
    const tableMapping = {
      'taskchecklist': 'taskchecklist',
      'mbreminder': 'reminder',
      'mbremdetail': 'remdetail'
    };

    for (const sourceTable of tablesToSync) {
      const targetTable = tableMapping[sourceTable];

      console.log(`\n${'='.repeat(70)}`);
      console.log(`Syncing: ${sourceTable} → ${targetTable}`);
      console.log('='.repeat(70));

      try {
        // Extract from source
        const data = await engine.extractData(sourceTable);
        console.log(`  ✓ Extracted ${data.length} records from source`);

        if (data.length === 0) {
          console.log('  ⚪ No records to sync, skipping...\n');
          continue;
        }

        // Transform data
        const transformed = await engine.transformData(sourceTable, data, targetTable);
        console.log(`  ✓ Transformed ${transformed.length} records`);

        // Filter by FK (for those that still have FK constraints)
        const filtered = engine.filterByForeignKeys(targetTable, transformed);

        if (filtered.invalidRecords.length > 0) {
          console.log(`  ⚠️  Filtered ${filtered.invalidRecords.length} invalid records`);
        }

        console.log(`  ✓ Will sync ${filtered.validRecords.length} valid records`);

        // Clear existing records
        await engine.clearTable(targetTable);
        console.log(`  ✓ Cleared existing records from ${targetTable}`);

        // Load to target
        const result = await engine.loadData(targetTable, filtered.validRecords, 'full');
        console.log(`  ✓ Loaded ${result.recordsLoaded} records to target`);

        if (result.recordsFailed > 0) {
          console.log(`  ⚠️  ${result.recordsFailed} records failed`);
        }

        console.log(`  ⏱️  Duration: ${result.duration}s\n`);

      } catch (error) {
        console.error(`  ❌ Error syncing ${sourceTable}:`, error.message);
      }
    }

    console.log('\n' + '='.repeat(70));
    console.log('✅ TARGETED SYNC COMPLETE!');
    console.log('='.repeat(70));

    await engine.close();

  } catch (error) {
    console.error('\n❌ Sync failed:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

syncRemainingTables();
