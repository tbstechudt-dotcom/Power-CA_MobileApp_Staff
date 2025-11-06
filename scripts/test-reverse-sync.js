/**
 * Test Reverse Sync - Create mobile record and verify sync to desktop
 *
 * This script:
 * 1. Creates a test reminder in Supabase (source='M')
 * 2. Runs the reverse sync engine
 * 3. Verifies the record appears in desktop database
 */

require('dotenv').config();
const { Pool } = require('pg');

// Supabase connection
const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

// Desktop connection
const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD,
  max: 5,
});

async function testReverseSync() {
  try {
    console.log('\n[TEST] Testing Reverse Sync (Supabase -> Desktop)\n');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Step 1: Check reminder table structure in Supabase
    console.log('\n[INFO] Step 1: Checking reminder table structure...');
    const tableInfo = await supabasePool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'reminder'
      ORDER BY ordinal_position
    `);

    console.log('Reminder table columns:');
    tableInfo.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.data_type}`);
    });

    // Step 2: Get next available rem_id
    console.log('\n[INFO] Step 2: Generating test reminder ID...');
    const maxRemIdResult = await supabasePool.query(`
      SELECT COALESCE(MAX(rem_id), 0) + 1 as next_rem_id
      FROM reminder
    `);
    const testRemId = maxRemIdResult.rows[0].next_rem_id;
    console.log(`  Next available rem_id: ${testRemId}`);

    // Step 3: Get valid FK references for NOT NULL columns
    console.log('\n[INFO] Step 3: Getting valid FK references...');

    // Get org_id
    const orgResult = await supabasePool.query(`
      SELECT org_id FROM orgmaster LIMIT 1
    `);

    // Get loc_id
    const locResult = await supabasePool.query(`
      SELECT loc_id FROM locmaster LIMIT 1
    `);

    // Get staff_id
    const staffResult = await supabasePool.query(`
      SELECT staff_id FROM mbstaff LIMIT 1
    `);

    // Get client_id
    const clientResult = await supabasePool.query(`
      SELECT client_id FROM climaster LIMIT 1
    `);

    if (staffResult.rows.length === 0 || clientResult.rows.length === 0 ||
        orgResult.rows.length === 0 || locResult.rows.length === 0) {
      console.error('[ERROR] Missing required FK references!');
      process.exit(1);
    }

    const testOrgId = orgResult.rows[0].org_id;
    const testLocId = locResult.rows[0].loc_id;
    const testStaffId = staffResult.rows[0].staff_id;
    const testClientId = clientResult.rows[0].client_id;

    console.log(`  Using org_id: ${testOrgId}`);
    console.log(`  Using loc_id: ${testLocId}`);
    console.log(`  Using staff_id: ${testStaffId}`);
    console.log(`  Using client_id: ${testClientId}`);

    // Step 4: Create test reminder in Supabase
    console.log('\n[INFO] Step 4: Creating test reminder in Supabase...');
    const testReminder = {
      rem_id: testRemId,
      org_id: testOrgId,
      loc_id: testLocId,
      year_id: 2025,  // Current year
      staff_id: testStaffId,
      client_id: testClientId,
      remtitle: 'TEST - Reverse Sync Verification',
      remnotes: 'This is a test reminder created to verify reverse sync functionality',
      remdate: new Date().toISOString().split('T')[0], // Today's date
      remtime: '14:00:00',
      remstatus: 1,  // Numeric status
      remtype: 'Test',
      source: 'M',  // Mark as mobile-created
      created_at: new Date(),
      updated_at: new Date()
    };

    const insertResult = await supabasePool.query(`
      INSERT INTO reminder (
        rem_id, org_id, loc_id, year_id, staff_id, client_id,
        remtitle, remnotes, remdate, remtime, remstatus, remtype,
        source, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
      RETURNING *
    `, [
      testReminder.rem_id,
      testReminder.org_id,
      testReminder.loc_id,
      testReminder.year_id,
      testReminder.staff_id,
      testReminder.client_id,
      testReminder.remtitle,
      testReminder.remnotes,
      testReminder.remdate,
      testReminder.remtime,
      testReminder.remstatus,
      testReminder.remtype,
      testReminder.source,
      testReminder.created_at,
      testReminder.updated_at
    ]);

    console.log('[OK] Test reminder created in Supabase:');
    console.log('  ID:', insertResult.rows[0].rem_id);
    console.log('  Title:', insertResult.rows[0].remtitle);
    console.log('  Source:', insertResult.rows[0].source);
    console.log('  Date:', insertResult.rows[0].remdate);

    // Step 5: Check if reminder exists in desktop BEFORE sync
    console.log('\n[INFO] Step 5: Checking desktop database BEFORE sync...');
    const beforeSyncResult = await desktopPool.query(`
      SELECT * FROM mbreminder WHERE rem_id = $1
    `, [testRemId]);

    if (beforeSyncResult.rows.length > 0) {
      console.log('[WARN]  Reminder already exists in desktop (cleaning up)...');
      await desktopPool.query(`DELETE FROM mbreminder WHERE rem_id = $1`, [testRemId]);
      console.log('[OK] Cleaned up existing reminder');
    } else {
      console.log('[OK] Reminder does NOT exist in desktop yet (as expected)');
    }

    // Step 6: Run reverse sync
    console.log('\n[INFO] Step 6: Running reverse sync engine...');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Import and run reverse sync
    const ReverseSyncEngine = require('../sync/production/reverse-sync-engine');
    const engine = new ReverseSyncEngine();

    await engine.initialize();
    await engine.syncMobileData();
    await engine.cleanup();

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Step 7: Verify reminder synced to desktop
    console.log('\n[INFO] Step 7: Verifying reminder synced to desktop...');
    const afterSyncResult = await desktopPool.query(`
      SELECT * FROM mbreminder WHERE rem_id = $1
    `, [testRemId]);

    if (afterSyncResult.rows.length > 0) {
      console.log('[OK] SUCCESS - Reminder found in desktop database!');
      console.log('\nSynced Reminder Details:');
      console.log('  rem_id:', afterSyncResult.rows[0].rem_id);
      console.log('  staff_id:', afterSyncResult.rows[0].staff_id);
      console.log('  client_id:', afterSyncResult.rows[0].client_id);
      console.log('  remtitle:', afterSyncResult.rows[0].remtitle);
      console.log('  remnotes:', afterSyncResult.rows[0].remnotes);
      console.log('  remdate:', afterSyncResult.rows[0].remdate);
      console.log('  remstatus:', afterSyncResult.rows[0].remstatus);
    } else {
      console.log('[ERROR] FAILED - Reminder NOT found in desktop database!');
      console.log('   Reverse sync may have failed or skipped the record.');
      process.exit(1);
    }

    // Step 8: Cleanup (optional)
    console.log('\n[INFO] Step 8: Cleanup test data...');
    console.log('Would you like to keep or remove the test reminder?');
    console.log('  - Keeping for manual verification');
    console.log('  - To remove manually:');
    console.log(`    Supabase: DELETE FROM reminder WHERE rem_id = ${testRemId};`);
    console.log(`    Desktop:  DELETE FROM mbreminder WHERE rem_id = ${testRemId};`);

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('[OK] Reverse Sync Test PASSED!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('Summary:');
    console.log('  1. [OK] Created mobile reminder in Supabase (source=\'M\')');
    console.log('  2. [OK] Ran reverse sync engine');
    console.log('  3. [OK] Verified reminder synced to desktop database');
    console.log('  4. [OK] Desktop table: mbreminder (mapped from reminder)');
    console.log(`  5. [OK] Test reminder ID: ${testRemId}\n`);

  } catch (error) {
    console.error('\n[ERROR] Error during reverse sync test:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    await supabasePool.end();
    await desktopPool.end();
  }
}

testReverseSync();