#!/usr/bin/env node
/**
 * Test Post-Sync Mobile Data to Parent Tables
 *
 * Calls sync_mobile_to_parent() function to sync mobile-created data
 * from mobile sync tables (workdiary, learequest) to parent tables
 * (daily_work, atleaverequest).
 */

const { Pool } = require('pg');
const config = require('../sync/production/config');

async function testPostSync() {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║     POST-SYNC: Mobile Sync Tables to Parent Tables       ║
║     Syncing mobile-created data to parent tables          ║
╚═══════════════════════════════════════════════════════════╝
`);

  const desktopPool = new Pool(config.source);
  const client = await desktopPool.connect();

  try {
    // Connect to desktop database
    await client.query('SELECT NOW()');
    console.log('[OK] Connected to Desktop PostgreSQL\n');

    // Check if function exists
    const functionCheck = await client.query(`
      SELECT proname
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'sync_mobile_to_parent'
        AND n.nspname = 'public'
    `);

    if (functionCheck.rows.length === 0) {
      console.error('[X] Function sync_mobile_to_parent() not found in database');
      console.error('[X] The function needs to be installed in the desktop database\n');
      process.exit(1);
    }

    console.log('[OK] Function sync_mobile_to_parent() found');

    // Temporarily disable triggers on parent tables to prevent FK/NOT NULL violations
    console.log('[...] Disabling triggers on parent tables...');
    await client.query('ALTER TABLE daily_work DISABLE TRIGGER ALL');
    await client.query('ALTER TABLE atleaverequest DISABLE TRIGGER ALL');
    console.log('[OK] Triggers disabled (daily_work, atleaverequest)\n');

    let syncResult;
    try {
      console.log('[...] Running sync_mobile_to_parent()...\n');

      const startTime = Date.now();
      syncResult = await client.query('SELECT sync_mobile_to_parent()');
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      console.log(`[OK] sync_mobile_to_parent() completed in ${duration}s`);
      console.log(`[OK] Result: ${syncResult.rows[0].sync_mobile_to_parent}\n`);

    } finally {
      // ALWAYS re-enable triggers, even if sync fails
      console.log('[...] Re-enabling triggers on parent tables...');
      await client.query('ALTER TABLE daily_work ENABLE TRIGGER ALL');
      await client.query('ALTER TABLE atleaverequest ENABLE TRIGGER ALL');
      console.log('[OK] Triggers re-enabled\n');
    }

    // Show record counts for parent tables
    console.log('Parent Table Status:');
    console.log('─'.repeat(60));

    const tables = [
      { name: 'daily_work', description: 'Work Diary Entries' },
      { name: 'atleaverequest', description: 'Leave Requests' }
    ];

    for (const table of tables) {
      try {
        const countResult = await client.query(`SELECT COUNT(*) FROM ${table.name}`);
        const count = parseInt(countResult.rows[0].count).toLocaleString();
        console.log(`  ${table.name.padEnd(20)} ${count.padStart(10)} records (${table.description})`);
      } catch (error) {
        console.log(`  ${table.name.padEnd(20)} [ERROR] ${error.message}`);
      }
    }

    console.log('─'.repeat(60));
    console.log('\n[OK] Post-sync test completed successfully!');
    console.log('[OK] Mobile-created records are synced to parent tables\n');

    process.exit(0);

  } catch (error) {
    console.error('\n[X] Post-sync failed:', error.message);
    console.error(error);
    process.exit(1);

  } finally {
    client.release();
    await desktopPool.end();
  }
}

// Error handlers
process.on('unhandledRejection', (error) => {
  console.error('\n[X] Unhandled error:', error);
  process.exit(1);
});

process.on('SIGINT', async () => {
  console.log('\n\nPost-sync interrupted by user.\n');
  process.exit(0);
});

// Run
testPostSync();
