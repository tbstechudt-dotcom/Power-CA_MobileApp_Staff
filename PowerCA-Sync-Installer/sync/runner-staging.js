#!/usr/bin/env node
/**
 * SAFE Sync Runner - Uses Staging Table Pattern
 *
 * This runner uses the staging table pattern for safe, atomic syncs.
 *
 * USAGE:
 *   node sync/runner-staging.js --mode=full
 *   node sync/runner-staging.js --mode=incremental
 *
 * SAFETY GUARANTEE:
 *   If sync fails for ANY reason (connection drop, error, etc.),
 *   your production data remains UNTOUCHED!
 */

const StagingSyncEngine = require('./engine-staging');

async function main() {
  // Parse command line args
  const args = process.argv.slice(2);
  const modeArg = args.find(arg => arg.startsWith('--mode='));
  const mode = modeArg ? modeArg.split('=')[1] : 'full';

  if (!['full', 'incremental'].includes(mode)) {
    console.error('[ERROR] Invalid mode. Use --mode=full or --mode=incremental');
    process.exit(1);
  }

  console.log('[SAFE]  SAFE SYNC ENGINE - Staging Table Pattern');
  console.log('   Production data protected from failures!\n');

  const engine = new StagingSyncEngine();

  try {
    await engine.syncAll(mode);
    console.log('\n[OK] Sync completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n[ERROR] Sync failed:', error.message);
    console.error('\n[SAFE]  Your production data is SAFE and unchanged!');
    process.exit(1);
  }
}

main();
