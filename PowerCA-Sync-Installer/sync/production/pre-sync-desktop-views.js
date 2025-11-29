#!/usr/bin/env node
/**
 * Pre-Sync Desktop Views to Tables (PRODUCTION)
 *
 * Calls sync_views_to_tables() function in desktop database to sync
 * data from parent tables (via views) to mobile sync tables.
 *
 * This ensures that any updates in parent tables are reflected in
 * mobile sync tables before forward sync to Supabase.
 *
 * Usage:
 *   node sync/production/pre-sync-desktop-views.js
 */

const { Pool } = require('pg');
const config = require('./config');

async function preSyncDesktopViews() {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║     PRE-SYNC: Desktop Views to Mobile Sync Tables         ║
║     Syncing parent table updates to mobile sync tables    ║
╚═══════════════════════════════════════════════════════════╝
`);

  const desktopPool = new Pool(config.source);

  try {
    // Connect to desktop database
    await desktopPool.query('SELECT NOW()');
    console.log('[OK] Connected to Desktop PostgreSQL\n');

    // Check if function exists
    const functionCheck = await desktopPool.query(`
      SELECT proname
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'sync_views_to_tables'
        AND n.nspname = 'public'
    `);

    if (functionCheck.rows.length === 0) {
      console.error('[X] Function sync_views_to_tables() not found in database');
      console.error('[X] Please create this function before running forward sync\n');
      process.exit(1);
    }

    console.log('[OK] Function sync_views_to_tables() found');
    console.log('[...] Running sync_views_to_tables()...\n');

    const startTime = Date.now();
    const result = await desktopPool.query('SELECT sync_views_to_tables()');
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`[OK] sync_views_to_tables() completed in ${duration}s\n`);

    // Show record counts for key tables
    console.log('Mobile Sync Table Counts:');
    console.log('─'.repeat(60));

    const tables = [
      'orgmaster',
      'locmaster',
      'conmaster',
      'climaster',
      'mbstaff',
      'jobshead',
      'jobtasks',
      'taskchecklist',
      'mbreminder',
      'mbremdetail'
    ];

    for (const table of tables) {
      try {
        const countResult = await desktopPool.query(`SELECT COUNT(*) FROM ${table}`);
        const count = parseInt(countResult.rows[0].count).toLocaleString();
        console.log(`  ${table.padEnd(20)} ${count.padStart(10)} records`);
      } catch (error) {
        console.log(`  ${table.padEnd(20)} [ERROR] ${error.message}`);
      }
    }

    console.log('─'.repeat(60));
    console.log('\n[OK] Pre-sync completed successfully!');
    console.log('[OK] Mobile sync tables are ready for forward sync to Supabase\n');

    process.exit(0);

  } catch (error) {
    console.error('\n[X] Pre-sync failed:', error.message);
    console.error(error);
    process.exit(1);

  } finally {
    await desktopPool.end();
  }
}

// Error handlers
process.on('unhandledRejection', (error) => {
  console.error('\n[X] Unhandled error:', error);
  process.exit(1);
});

process.on('SIGINT', async () => {
  console.log('\n\nPre-sync interrupted by user.\n');
  process.exit(0);
});

// Run
preSyncDesktopViews();
