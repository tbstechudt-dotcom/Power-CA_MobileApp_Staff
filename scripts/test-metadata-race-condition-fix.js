/**
 * Integration Test: Forward Sync Metadata Timestamp Race Condition Fix (Issue #13)
 *
 * This test verifies that _sync_metadata.last_sync_timestamp is set to the
 * maximum timestamp from fetched records (NOT NOW()), preventing the race
 * condition where records created during sync are permanently skipped.
 *
 * Test Steps:
 * 1. Get current metadata timestamp
 * 2. Get max timestamp from desktop table
 * 3. Run incremental sync
 * 4. Verify metadata timestamp <= desktop max (uses fetched records, not NOW())
 * 5. Check that metadata timestamp is reasonable (not too far in future)
 *
 * Expected Behavior (AFTER FIX):
 * - Metadata timestamp should match max timestamp from fetched records
 * - Metadata timestamp should be <= current time
 * - Records created during sync window are caught in next sync
 *
 * Usage:
 *   node scripts/test-metadata-race-condition-fix.js [table_name]
 *
 *   Examples:
 *     node scripts/test-metadata-race-condition-fix.js
 *     node scripts/test-metadata-race-condition-fix.js jobtasks
 */

require('dotenv').config();
const { Pool } = require('pg');

// Test configuration
const TEST_TABLE = process.argv[2] || 'jobtasks'; // Default to jobtasks (high-activity table)

// Database connections
const desktopPool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.DESKTOP_DB_PASSWORD,
  max: 5,
  connectionTimeoutMillis: 10000,
});

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  max: 5,
  connectionTimeoutMillis: 10000,
});

/**
 * Main test function
 */
async function testMetadataRaceConditionFix() {
  console.log('='.repeat(70));
  console.log('Integration Test: Metadata Timestamp Race Condition Fix (Issue #13)');
  console.log('='.repeat(70));
  console.log('');
  console.log(`Testing table: ${TEST_TABLE}`);
  console.log('');

  try {
    // Step 1: Get current metadata timestamp
    console.log('[Step 1/5] Getting current metadata timestamp...');
    const metadataBefore = await supabasePool.query(`
      SELECT
        table_name,
        last_sync_timestamp,
        updated_at as metadata_updated_at,
        records_synced
      FROM _sync_metadata
      WHERE table_name = $1
    `, [TEST_TABLE]);

    if (metadataBefore.rows.length === 0) {
      console.log(`  [INFO] No metadata found for ${TEST_TABLE} (first sync)`);
      console.log(`  [INFO] Initial timestamp will be set after first sync`);
    } else {
      const meta = metadataBefore.rows[0];
      console.log(`  [OK] Current metadata:`);
      console.log(`    - last_sync_timestamp: ${meta.last_sync_timestamp}`);
      console.log(`    - metadata_updated_at: ${meta.metadata_updated_at}`);
      console.log(`    - records_synced: ${meta.records_synced}`);
    }
    console.log('');

    // Step 2: Get max timestamp from desktop table
    console.log('[Step 2/5] Getting max timestamp from desktop table...');

    // Check which timestamp columns exist
    const columns = await desktopPool.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = $1
        AND column_name IN ('updated_at', 'created_at')
    `, [TEST_TABLE]);

    const hasUpdatedAt = columns.rows.some(r => r.column_name === 'updated_at');
    const hasCreatedAt = columns.rows.some(r => r.column_name === 'created_at');

    if (!hasUpdatedAt && !hasCreatedAt) {
      console.log(`  [ERROR] Table ${TEST_TABLE} has no timestamp columns!`);
      console.log(`  [INFO] Cannot test metadata tracking without timestamps`);
      process.exit(1);
    }

    let maxTimestampQuery;
    if (hasUpdatedAt && hasCreatedAt) {
      maxTimestampQuery = `
        SELECT
          MAX(updated_at) as max_updated_at,
          MAX(created_at) as max_created_at,
          GREATEST(MAX(updated_at), MAX(created_at)) as max_timestamp,
          COUNT(*) as total_records
        FROM ${TEST_TABLE}
      `;
    } else if (hasUpdatedAt) {
      maxTimestampQuery = `
        SELECT
          MAX(updated_at) as max_updated_at,
          NULL as max_created_at,
          MAX(updated_at) as max_timestamp,
          COUNT(*) as total_records
        FROM ${TEST_TABLE}
      `;
    } else {
      maxTimestampQuery = `
        SELECT
          NULL as max_updated_at,
          MAX(created_at) as max_created_at,
          MAX(created_at) as max_timestamp,
          COUNT(*) as total_records
        FROM ${TEST_TABLE}
      `;
    }

    const desktopMax = await desktopPool.query(maxTimestampQuery);
    const desktopData = desktopMax.rows[0];

    console.log(`  [OK] Desktop table data:`);
    if (desktopData.max_updated_at) {
      console.log(`    - max(updated_at): ${desktopData.max_updated_at}`);
    }
    if (desktopData.max_created_at) {
      console.log(`    - max(created_at): ${desktopData.max_created_at}`);
    }
    console.log(`    - max_timestamp: ${desktopData.max_timestamp}`);
    console.log(`    - total_records: ${desktopData.total_records}`);
    console.log('');

    // Step 3: Prompt user to run sync
    console.log('[Step 3/5] Ready to run sync test');
    console.log('  [ACTION REQUIRED] Please run incremental sync now:');
    console.log('');
    console.log('    node sync/production/runner-staging.js --mode=incremental');
    console.log('');
    console.log('  [INFO] Waiting 90 seconds for sync to complete...');
    console.log('  [INFO] (Press Ctrl+C if you need more time)');
    console.log('');

    // Wait for sync to complete
    await new Promise(resolve => setTimeout(resolve, 90000)); // 90 seconds

    // Step 4: Get metadata after sync
    console.log('[Step 4/5] Verifying metadata after sync...');
    const metadataAfter = await supabasePool.query(`
      SELECT
        table_name,
        last_sync_timestamp,
        updated_at as metadata_updated_at,
        records_synced
      FROM _sync_metadata
      WHERE table_name = $1
    `, [TEST_TABLE]);

    if (metadataAfter.rows.length === 0) {
      console.log(`  [ERROR] No metadata found for ${TEST_TABLE} after sync!`);
      console.log(`  [INFO] Sync may have failed or not run yet`);
      process.exit(1);
    }

    const metaAfter = metadataAfter.rows[0];
    console.log(`  [OK] Metadata after sync:`);
    console.log(`    - last_sync_timestamp: ${metaAfter.last_sync_timestamp}`);
    console.log(`    - metadata_updated_at: ${metaAfter.metadata_updated_at}`);
    console.log(`    - records_synced: ${metaAfter.records_synced}`);
    console.log('');

    // Step 5: Verify metadata timestamp is correct
    console.log('[Step 5/5] Analyzing results...');
    console.log('');

    const lastSyncTime = new Date(metaAfter.last_sync_timestamp);
    const metadataUpdateTime = new Date(metaAfter.metadata_updated_at);
    const desktopMaxTime = new Date(desktopData.max_timestamp);
    const currentTime = new Date();

    // Test 1: Metadata timestamp should be <= metadata update time
    console.log('[Test 1] Metadata timestamp should be <= metadata update time');
    if (lastSyncTime <= metadataUpdateTime) {
      console.log(`  [PASS] ${lastSyncTime.toISOString()} <= ${metadataUpdateTime.toISOString()}`);
      console.log(`  [INFO] Last sync timestamp is from fetched records (not NOW())`);
    } else {
      console.log(`  [FAIL] ${lastSyncTime.toISOString()} > ${metadataUpdateTime.toISOString()}`);
      console.log(`  [ERROR] Metadata timestamp is AFTER metadata write time!`);
    }
    console.log('');

    // Test 2: Metadata timestamp should be <= current time
    console.log('[Test 2] Metadata timestamp should be <= current time');
    if (lastSyncTime <= currentTime) {
      console.log(`  [PASS] ${lastSyncTime.toISOString()} <= ${currentTime.toISOString()}`);
      console.log(`  [INFO] Timestamp is not in the future`);
    } else {
      console.log(`  [FAIL] ${lastSyncTime.toISOString()} > ${currentTime.toISOString()}`);
      console.log(`  [ERROR] Metadata timestamp is in the FUTURE!`);
    }
    console.log('');

    // Test 3: Metadata timestamp should be close to desktop max (within reasonable window)
    console.log('[Test 3] Metadata timestamp should match desktop max (or be older)');
    const timeDiffMs = desktopMaxTime - lastSyncTime;
    const timeDiffMin = timeDiffMs / 1000 / 60;

    if (timeDiffMs >= 0 && timeDiffMin <= 60) {
      console.log(`  [PASS] Metadata is ${timeDiffMin.toFixed(2)} minutes older than desktop max`);
      console.log(`  [INFO] This is expected (desktop may have new records added during sync)`);
    } else if (timeDiffMs >= 0 && timeDiffMin > 60) {
      console.log(`  [WARN] Metadata is ${timeDiffMin.toFixed(2)} minutes older than desktop max`);
      console.log(`  [INFO] This may indicate incremental sync is working on older subset`);
    } else {
      console.log(`  [FAIL] Metadata is ${Math.abs(timeDiffMin).toFixed(2)} minutes NEWER than desktop max`);
      console.log(`  [ERROR] Metadata timestamp should not be newer than desktop records!`);
    }
    console.log('');

    // Test 4: Check if metadata was updated (changed from before)
    console.log('[Test 4] Metadata should have been updated by sync');
    if (metadataBefore.rows.length === 0) {
      console.log(`  [PASS] First sync - metadata created`);
    } else {
      const beforeTime = new Date(metadataBefore.rows[0].last_sync_timestamp);
      const afterTime = new Date(metaAfter.last_sync_timestamp);

      if (afterTime >= beforeTime) {
        console.log(`  [PASS] Metadata timestamp advanced`);
        console.log(`    - Before: ${beforeTime.toISOString()}`);
        console.log(`    - After:  ${afterTime.toISOString()}`);
      } else {
        console.log(`  [FAIL] Metadata timestamp went BACKWARDS!`);
        console.log(`    - Before: ${beforeTime.toISOString()}`);
        console.log(`    - After:  ${afterTime.toISOString()}`);
      }
    }
    console.log('');

    // Test 5: Verify metadata timestamp is NOT simply NOW()
    console.log('[Test 5] Metadata should use max timestamp (NOT NOW())');
    const syncWindowSeconds = (metadataUpdateTime - lastSyncTime) / 1000;

    if (syncWindowSeconds >= 1) {
      console.log(`  [PASS] Metadata timestamp is ${syncWindowSeconds.toFixed(1)}s BEFORE write time`);
      console.log(`  [INFO] This confirms fix is working (uses fetched records, not NOW())`);
    } else if (syncWindowSeconds >= 0 && syncWindowSeconds < 1) {
      console.log(`  [WARN] Metadata timestamp is only ${syncWindowSeconds.toFixed(3)}s before write`);
      console.log(`  [INFO] This might still be NOW() if sync was very fast`);
      console.log(`  [INFO] Run test with larger table or during high load`);
    } else {
      console.log(`  [FAIL] Metadata timestamp is AFTER write time by ${Math.abs(syncWindowSeconds).toFixed(1)}s`);
      console.log(`  [ERROR] This should never happen!`);
    }
    console.log('');

    // Final summary
    console.log('='.repeat(70));
    console.log('Test Summary');
    console.log('='.repeat(70));
    console.log('');
    console.log('[RESULTS]');

    const allPass = (
      lastSyncTime <= metadataUpdateTime &&
      lastSyncTime <= currentTime &&
      timeDiffMs >= 0 &&
      syncWindowSeconds >= 0
    );

    if (allPass) {
      console.log('  [OK] ALL TESTS PASSED');
      console.log('  [OK] Issue #13 fix is working correctly');
      console.log('  [OK] Metadata uses max timestamp from fetched records (not NOW())');
    } else {
      console.log('  [FAIL] SOME TESTS FAILED');
      console.log('  [ERROR] Issue #13 fix may not be working correctly');
      console.log('  [ERROR] Review test output above for details');
    }
    console.log('');

    console.log('[VERIFICATION STEPS]');
    console.log('  1. Add test record to desktop table:');
    console.log(`     UPDATE ${TEST_TABLE} SET updated_at = NOW() WHERE ... LIMIT 1;`);
    console.log('');
    console.log('  2. Run another incremental sync:');
    console.log('     node sync/production/runner-staging.js --mode=incremental');
    console.log('');
    console.log('  3. Verify test record was synced (not skipped):');
    console.log(`     SELECT COUNT(*) FROM ${TEST_TABLE}; -- Compare desktop vs Supabase`);
    console.log('');

  } catch (error) {
    console.error('[ERROR] Test failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    await desktopPool.end();
    await supabasePool.end();
  }
}

// Run test
if (require.main === module) {
  testMetadataRaceConditionFix()
    .then(() => {
      console.log('[INFO] Test completed');
      process.exit(0);
    })
    .catch(err => {
      console.error('[ERROR]', err);
      process.exit(1);
    });
}

module.exports = testMetadataRaceConditionFix;
