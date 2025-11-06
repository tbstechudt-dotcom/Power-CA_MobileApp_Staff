#!/usr/bin/env node
/**
 * Reverse Sync Runner - Supabase -> Desktop
 *
 * Pulls mobile-generated data from Supabase back to Desktop PostgreSQL
 *
 * Usage:
 *   node sync/reverse-sync-runner.js
 */

const ReverseSyncEngine = require('./reverse-sync-engine');

async function main() {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║        REVERSE SYNC - Mobile Data to Desktop              ║
║        Supabase Cloud -> Desktop PostgreSQL                ║
╚═══════════════════════════════════════════════════════════╝
`);

  const engine = new ReverseSyncEngine();

  try {
    // Initialize connections
    await engine.initialize();

    // Sync mobile data back to desktop
    await engine.syncMobileData();

    console.log('\n[OK] Reverse sync completed successfully!\n');
    process.exit(0);

  } catch (error) {
    console.error('\n[X] Reverse sync failed:', error.message);
    console.error(error);
    process.exit(1);

  } finally {
    await engine.cleanup();
  }
}

// Error handlers
process.on('unhandledRejection', (error) => {
  console.error('\n[X] Unhandled error:', error);
  process.exit(1);
});

process.on('SIGINT', async () => {
  console.log('\n\nReverse sync interrupted by user. Cleaning up...\n');
  process.exit(0);
});

// Run
main();
