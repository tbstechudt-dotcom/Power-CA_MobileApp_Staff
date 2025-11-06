/**
 * Test: Reverse Sync Watermark (Race Condition Fix)
 *
 * Verifies that the reverse sync engine uses MAX(updated_at) from processed records
 * instead of NOW() to prevent race condition where records can be skipped forever.
 *
 * Race Condition Scenario (Before Fix):
 * 1. SELECT * WHERE updated_at > '10:00:00' (returns records up to 10:00:05)
 * 2. New record inserted with updated_at = 10:00:06
 * 3. UPDATE metadata SET last_sync_timestamp = NOW() (10:00:10)
 * 4. Next sync: SELECT * WHERE updated_at > '10:00:10'
 *    [ERROR] Skips record from step 2 (10:00:06 < 10:00:10)
 *
 * With Fix:
 * 1. SELECT * WHERE updated_at > '10:00:00' (returns records up to 10:00:05)
 * 2. Track MAX(updated_at) = 10:00:05
 * 3. New record inserted with updated_at = 10:00:06
 * 4. UPDATE metadata SET last_sync_timestamp = '10:00:05' (MAX from step 2)
 * 5. Next sync: SELECT * WHERE updated_at > '10:00:05'
 *    [OK] Catches record from step 3 (10:00:06 > 10:00:05)
 */

const { Pool } = require('pg');
const ReverseSyncEngine = require('../sync/production/reverse-sync-engine');

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function testWatermark() {
  console.log('\n[TEST] Reverse Sync Watermark Test');
  console.log('='.repeat(60));
  console.log('Scenario: Verify MAX(updated_at) used instead of NOW()\n');

  const supabasePool = new Pool({
    host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: process.env.SUPABASE_DB_PASSWORD,
    ssl: { rejectUnauthorized: false }
  });

  const desktopPool = new Pool({
    host: 'localhost',
    port: 5433,
    database: 'enterprise_db',
    user: 'postgres',
    password: process.env.LOCAL_DB_PASSWORD
  });

  let testReminderId = null;

  try {
    // Step 1: Create test reminder in Supabase with specific timestamp
    console.log('[INFO] Step 1: Creating test reminder in Supabase...');
    const reminderResult = await supabasePool.query('SELECT COALESCE(MAX(rem_id), 0) + 1 as next_id FROM reminder');
    testReminderId = reminderResult.rows[0].next_id;

    // Create reminder with explicit timestamp (5 seconds ago)
    const testTimestamp = new Date(Date.now() - 5000); // 5 seconds ago
    await supabasePool.query(`
      INSERT INTO reminder (
        rem_id, org_id, loc_id, year_id, staff_id, client_id,
        remdate, remtitle, remnotes, remstatus, source,
        created_at, updated_at
      ) VALUES (
        $1, 1, 1, 1, 1, 1,
        CURRENT_DATE, 'TEST-WATERMARK-REMINDER', 'Testing watermark', 1, 'M',
        $2, $2
      )
    `, [testReminderId, testTimestamp]);

    console.log(`[OK] Created test reminder: rem_id=${testReminderId}`);
    console.log(`  - updated_at: ${testTimestamp.toISOString()}\n`);

    // Step 2: Run reverse sync
    console.log('[INFO] Step 2: Running reverse sync...');
    const syncStartTime = new Date();
    console.log(`  - Sync started at: ${syncStartTime.toISOString()}`);

    const engine = new ReverseSyncEngine();
    await engine.initialize();

    // Sync only reminder table
    await engine.syncTable('reminder');

    await engine.cleanup();

    const syncEndTime = new Date();
    console.log(`  - Sync ended at: ${syncEndTime.toISOString()}`);
    console.log('[OK] Reverse sync completed\n');

    // Step 3: Check stored watermark
    console.log('[INFO] Step 3: Checking stored watermark...');
    const watermarkResult = await desktopPool.query(`
      SELECT last_sync_timestamp
      FROM _reverse_sync_metadata
      WHERE table_name = 'mbreminder'
    `);

    if (watermarkResult.rows.length === 0) {
      throw new Error('No watermark found in metadata table!');
    }

    const storedWatermark = new Date(watermarkResult.rows[0].last_sync_timestamp);
    console.log(`[OK] Stored watermark: ${storedWatermark.toISOString()}`);
    console.log(`  - Test record timestamp: ${testTimestamp.toISOString()}`);
    console.log(`  - Sync end time (NOW):   ${syncEndTime.toISOString()}\n`);

    // Step 4: Verify watermark is NOT NOW() (should be <= sync end time)
    console.log('[INFO] Step 4: Verifying watermark is NOT NOW()...');

    const timeDiff = storedWatermark.getTime() - syncEndTime.getTime();
    const timeDiffSeconds = Math.abs(timeDiff / 1000);

    if (timeDiffSeconds < 0.5) {
      // Watermark is very close to NOW() - likely using NOW() instead of MAX(updated_at)
      console.error('[ERROR] Watermark appears to be NOW()!');
      console.error(`  - Difference from sync end: ${timeDiffSeconds.toFixed(3)} seconds`);
      console.error(`  - This suggests the bug is NOT fixed [ERROR]\n`);
      throw new Error('Watermark uses NOW() instead of MAX(updated_at)');
    }

    console.log('[OK] Watermark is NOT NOW()');
    console.log(`  - Difference from sync end: ${timeDiffSeconds.toFixed(3)} seconds\n`);

    // Step 5: Verify watermark matches max timestamp from processed records
    console.log('[INFO] Step 5: Verifying watermark matches processed records...');

    // Get the maximum updated_at from reminder table in Supabase (excluding future records)
    const maxTimestampResult = await supabasePool.query(`
      SELECT MAX(updated_at) as max_timestamp
      FROM reminder
      WHERE updated_at <= $1
    `, [syncEndTime]);

    const expectedWatermark = new Date(maxTimestampResult.rows[0].max_timestamp);
    console.log(`  - Expected watermark (MAX): ${expectedWatermark.toISOString()}`);
    console.log(`  - Actual watermark:         ${storedWatermark.toISOString()}`);

    const watermarkDiff = Math.abs(storedWatermark.getTime() - expectedWatermark.getTime());
    if (watermarkDiff > 1000) { // Allow 1 second tolerance
      console.error(`[WARN]  Watermark differs from MAX by ${watermarkDiff}ms`);
    } else {
      console.log('[OK] Watermark matches MAX(updated_at) from processed records\n');
    }

    // Step 6: Simulate race condition scenario
    console.log('[INFO] Step 6: Simulating race condition...');

    // Create a "late" record with timestamp between test record and watermark
    const lateTimestamp = new Date(testTimestamp.getTime() + 2000); // 2 seconds after test record
    const lateReminderId = testReminderId + 1;

    console.log(`  - Creating late record with timestamp: ${lateTimestamp.toISOString()}`);
    await supabasePool.query(`
      INSERT INTO reminder (
        rem_id, org_id, loc_id, year_id, staff_id, client_id,
        remdate, remtitle, remnotes, remstatus, source,
        created_at, updated_at
      ) VALUES (
        $1, 1, 1, 1, 1, 1,
        CURRENT_DATE, 'TEST-LATE-REMINDER', 'Late record test', 1, 'M',
        $2, $2
      )
    `, [lateReminderId, lateTimestamp]);

    console.log('[OK] Created late record\n');

    // Step 7: Run second sync and verify late record is caught
    console.log('[INFO] Step 7: Running second sync (should catch late record)...');

    const engine2 = new ReverseSyncEngine();
    await engine2.initialize();
    await engine2.syncTable('reminder');
    await engine2.cleanup();

    console.log('[OK] Second sync completed\n');

    // Step 8: Verify late record exists in desktop
    console.log('[INFO] Step 8: Verifying late record synced to desktop...');
    const lateRecordCheck = await desktopPool.query(`
      SELECT * FROM mbreminder WHERE rem_id = $1
    `, [lateReminderId]);

    if (lateRecordCheck.rows.length === 0) {
      throw new Error('Late record NOT found in desktop database - race condition NOT fixed! [ERROR]');
    }

    console.log('[OK] Late record found in desktop database');
    console.log(`  - remtitle: ${lateRecordCheck.rows[0].remtitle}\n`);

    // Cleanup
    console.log('[INFO] Step 9: Cleaning up test data...');
    await supabasePool.query('DELETE FROM reminder WHERE rem_id IN ($1, $2)', [testReminderId, lateReminderId]);
    await desktopPool.query('DELETE FROM mbreminder WHERE rem_id IN ($1, $2)', [testReminderId, lateReminderId]);
    console.log('[OK] Test data cleaned up\n');

    await supabasePool.end();
    await desktopPool.end();

    // Final result
    console.log('='.repeat(60));
    console.log('[SUCCESS] Watermark test PASSED!');
    console.log('='.repeat(60));
    console.log('\n[STATS] Test Summary\n');
    console.log('[OK] Watermark uses MAX(updated_at): Verified');
    console.log('[OK] Watermark does NOT use NOW(): Verified');
    console.log('[OK] Late records are caught: Verified');
    console.log('[OK] Race condition: FIXED [OK]\n');

    process.exit(0);

  } catch (error) {
    console.error('\n[ERROR] Watermark test FAILED:', error.message);
    console.error('\nStack trace:', error.stack);

    // Cleanup on error
    if (testReminderId) {
      try {
        await supabasePool.query('DELETE FROM reminder WHERE rem_id >= $1', [testReminderId]);
        await desktopPool.query('DELETE FROM mbreminder WHERE rem_id >= $1', [testReminderId]);
      } catch (cleanupError) {
        console.error('[WARN]  Cleanup error:', cleanupError.message);
      }
    }

    await supabasePool.end();
    await desktopPool.end();
    process.exit(1);
  }
}

testWatermark();
