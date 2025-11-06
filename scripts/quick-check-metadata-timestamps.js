/**
 * Quick Check: Verify Metadata Timestamps Are Correct (Issue #13)
 *
 * This script quickly checks all tables to verify that:
 * 1. Metadata timestamps are not in the future
 * 2. Metadata timestamps are reasonable (not using NOW())
 * 3. All synced tables have proper metadata
 *
 * Usage:
 *   node scripts/quick-check-metadata-timestamps.js
 */

require('dotenv').config();
const { Pool } = require('pg');

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  max: 5,
  connectionTimeoutMillis: 10000,
});

async function quickCheckMetadataTimestamps() {
  console.log('='.repeat(60));
  console.log('Quick Check: Metadata Timestamps (Issue #13 Verification)');
  console.log('='.repeat(60));
  console.log('');

  try {
    // Get all metadata entries
    const result = await supabasePool.query(`
      SELECT
        table_name,
        last_sync_timestamp,
        updated_at as metadata_updated_at,
        records_synced,
        EXTRACT(EPOCH FROM (updated_at - last_sync_timestamp)) as time_diff_seconds
      FROM _sync_metadata
      ORDER BY table_name
    `);

    if (result.rows.length === 0) {
      console.log('[INFO] No metadata entries found (no syncs run yet)');
      return;
    }

    console.log(`[OK] Found ${result.rows.length} synced tables`);
    console.log('');

    let issues = 0;
    let warnings = 0;

    for (const row of result.rows) {
      const lastSyncTime = new Date(row.last_sync_timestamp);
      const metadataTime = new Date(row.metadata_updated_at);
      const timeDiffSeconds = parseFloat(row.time_diff_seconds) || 0;

      console.log(`Table: ${row.table_name}`);
      console.log(`  Last sync: ${lastSyncTime.toISOString()}`);
      console.log(`  Metadata updated: ${metadataTime.toISOString()}`);
      console.log(`  Time difference: ${timeDiffSeconds.toFixed(1)}s`);

      // Check 1: Last sync should be <= metadata update
      if (lastSyncTime > metadataTime) {
        console.log(`  [ERROR] Last sync timestamp is AFTER metadata write!`);
        issues++;
      }

      // Check 2: Time difference should be positive (metadata written after data fetch)
      if (timeDiffSeconds < 0) {
        console.log(`  [ERROR] Negative time difference (impossible!)`)
        issues++;
      } else if (timeDiffSeconds < 1) {
        console.log(`  [WARN] Very small time difference (${timeDiffSeconds.toFixed(3)}s)`);
        console.log(`  [INFO] May still be using NOW() - test with larger table`);
        warnings++;
      } else if (timeDiffSeconds >= 1 && timeDiffSeconds <= 300) {
        console.log(`  [OK] Good time difference (using max timestamp, not NOW())`);
      } else {
        console.log(`  [WARN] Large time difference (${timeDiffSeconds.toFixed(1)}s)`);
        console.log(`  [INFO] Metadata may be stale or sync was very slow`);
        warnings++;
      }

      console.log('');
    }

    // Summary
    console.log('='.repeat(60));
    console.log('Summary');
    console.log('='.repeat(60));
    console.log('');
    console.log(`[OK] Tables checked: ${result.rows.length}`);
    console.log(`[WARN] Warnings: ${warnings}`);
    console.log(`[ERROR] Issues: ${issues}`);
    console.log('');

    if (issues === 0 && warnings === 0) {
      console.log('[OK] All metadata timestamps are correct!');
      console.log('[OK] Issue #13 fix is working as expected');
    } else if (issues === 0) {
      console.log('[WARN] No critical issues, but some warnings detected');
      console.log('[INFO] Review warnings above for details');
    } else {
      console.log('[ERROR] Critical issues detected!');
      console.log('[ERROR] Issue #13 fix may not be working correctly');
    }
    console.log('');

  } catch (error) {
    console.error('[ERROR]', error.message);
    throw error;
  } finally {
    await supabasePool.end();
  }
}

// Run check
if (require.main === module) {
  quickCheckMetadataTimestamps()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('[ERROR]', err);
      process.exit(1);
    });
}

module.exports = quickCheckMetadataTimestamps;
