#!/usr/bin/env node
/**
 * Sync Runner - Entry Point
 *
 * Command-line tool to run Power CA → Supabase data synchronization.
 *
 * Usage:
 *   node sync/runner.js --mode=full          # Full sync (all tables)
 *   node sync/runner.js --mode=incremental   # Incremental sync
 *   node sync/runner.js --test               # Test connections only
 *   node sync/runner.js --table=jobshead     # Sync single table
 *   node sync/runner.js --dry-run            # Dry run (no changes)
 */

const SyncEngine = require('./engine');
const config = require('./config');

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    mode: 'full',
    test: false,
    table: null,
    dryRun: false,
    help: false,
  };

  args.forEach(arg => {
    if (arg.startsWith('--mode=')) {
      options.mode = arg.split('=')[1];
    } else if (arg === '--test') {
      options.test = true;
    } else if (arg.startsWith('--table=')) {
      options.table = arg.split('=')[1];
    } else if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--help' || arg === '-h') {
      options.help = true;
    }
  });

  return options;
}

// Show help message
function showHelp() {
  console.log(`
Power CA → Supabase Sync Tool
==============================

Usage:
  node sync/runner.js [options]

Options:
  --mode=full           Run full sync (replace all data)
  --mode=incremental    Run incremental sync (only changes)
  --table=<name>        Sync single table only
  --test                Test database connections only
  --dry-run             Run without making changes
  --help, -h            Show this help message

Examples:
  # Full sync of all tables
  node sync/runner.js --mode=full

  # Incremental sync (daily operation)
  node sync/runner.js --mode=incremental

  # Test connections
  node sync/runner.js --test

  # Sync single table
  node sync/runner.js --table=jobshead --mode=full

  # Dry run to see what would happen
  node sync/runner.js --mode=full --dry-run

Configuration:
  - Edit sync/config.js for database settings
  - Create .env file for sensitive credentials
  - See docs/NEXT-STEPS-SUMMARY.md for setup guide
`);
}

// Main execution
async function main() {
  const options = parseArgs();

  // Show help if requested
  if (options.help) {
    showHelp();
    process.exit(0);
  }

  // Apply dry run mode
  if (options.dryRun) {
    config.sync.dryRun = true;
    console.log('🔍 DRY RUN MODE - No changes will be made\n');
  }

  const engine = new SyncEngine();

  try {
    // Initialize database connections
    await engine.initialize();

    // Test mode - just check connections
    if (options.test) {
      console.log('\n--- CONNECTION TEST ---\n');
      const testResult = await engine.testConnections();

      if (testResult) {
        console.log('\n✓ All connections working!\n');
        process.exit(0);
      } else {
        console.log('\n✗ Connection test failed!\n');
        process.exit(1);
      }
    }

    // Validate mode
    if (!['full', 'incremental'].includes(options.mode)) {
      console.error(`Error: Invalid mode '${options.mode}'. Use 'full' or 'incremental'.`);
      process.exit(1);
    }

    // Single table sync
    if (options.table) {
      console.log(`\n--- SINGLE TABLE SYNC ---`);
      console.log(`Table: ${options.table}`);
      console.log(`Mode: ${options.mode}\n`);

      await engine.syncTable(options.table, options.mode);

      console.log('\n✓ Table sync completed!\n');
    }
    // Full sync of all tables
    else {
      await engine.syncAll(options.mode);
      console.log('\n✓ Sync completed successfully!\n');
    }

    process.exit(0);

  } catch (error) {
    console.error('\n✗ Sync failed with error:');
    console.error(error);
    process.exit(1);

  } finally {
    // Always cleanup connections
    await engine.cleanup();
  }
}

// Error handlers
process.on('unhandledRejection', (error) => {
  console.error('\n✗ Unhandled error:', error);
  process.exit(1);
});

process.on('SIGINT', async () => {
  console.log('\n\nSync interrupted by user. Cleaning up...\n');
  process.exit(0);
});

// Run
main();
