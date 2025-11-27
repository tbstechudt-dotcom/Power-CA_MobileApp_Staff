#!/usr/bin/env node
/**
 * Full Sync Script - Complete Bidirectional Sync
 *
 * Runs the complete sync workflow:
 * 1. Pre-sync: Sync desktop parent tables to mobile sync tables
 * 2. Forward sync: Sync mobile sync tables to Supabase
 * 3. Reverse sync: Sync mobile-created data (workdiary, learequest) back to desktop
 *
 * Usage:
 *   node sync/full-sync.js --mode=full
 *   node sync/full-sync.js --mode=incremental
 */

const { spawn } = require('child_process');
const path = require('path');

// Parse command line arguments
const args = process.argv.slice(2);
const modeArg = args.find(arg => arg.startsWith('--mode='));
const mode = modeArg ? modeArg.split('=')[1] : 'full';

if (!['full', 'incremental'].includes(mode)) {
  console.error('[X] Invalid mode. Use --mode=full or --mode=incremental');
  process.exit(1);
}

console.log(`
╔═══════════════════════════════════════════════════════════╗
║              FULL BIDIRECTIONAL SYNC                      ║
║   Desktop Parent Tables ↔ Mobile Sync Tables ↔ Supabase  ║
╚═══════════════════════════════════════════════════════════╝

Mode: ${mode.toUpperCase()}
`);

/**
 * Run a Node.js script and wait for completion
 */
function runScript(scriptPath, args = []) {
  return new Promise((resolve, reject) => {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Running: ${scriptPath} ${args.join(' ')}`);
    console.log('='.repeat(60) + '\n');

    const child = spawn('node', [scriptPath, ...args], {
      stdio: 'inherit',
      cwd: process.cwd()
    });

    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`Script failed with exit code ${code}`));
      } else {
        resolve();
      }
    });

    child.on('error', (error) => {
      reject(error);
    });
  });
}

async function fullSync() {
  const startTime = Date.now();

  try {
    // Step 1: Pre-sync - Sync desktop parent tables to mobile sync tables
    console.log('\n📋 STEP 1/3: Pre-Sync Desktop Views to Mobile Sync Tables');
    await runScript(path.join(__dirname, 'pre-sync-desktop-views.js'));

    // Step 2: Forward sync - Desktop to Supabase
    console.log('\n📤 STEP 2/3: Forward Sync - Desktop to Supabase');
    await runScript(path.join(__dirname, 'runner-staging.js'), [`--mode=${mode}`]);

    // Step 3: Reverse sync - Supabase to Desktop (mobile-created data only)
    console.log('\n📥 STEP 3/3: Reverse Sync - Supabase to Desktop (workdiary, learequest)');
    await runScript(path.join(__dirname, 'reverse-sync-runner.js'));

    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`
╔═══════════════════════════════════════════════════════════╗
║                  ✅ FULL SYNC COMPLETED                   ║
╚═══════════════════════════════════════════════════════════╝

Total Duration: ${duration}s

Summary:
  ✅ Pre-sync: Desktop parent tables synced to mobile sync tables
  ✅ Forward sync: Desktop data synced to Supabase (${mode} mode)
  ✅ Reverse sync: Mobile data synced back to desktop

All sync operations completed successfully!
`);

    process.exit(0);

  } catch (error) {
    console.error(`
╔═══════════════════════════════════════════════════════════╗
║                  ❌ SYNC FAILED                           ║
╚═══════════════════════════════════════════════════════════╝

Error: ${error.message}
`);
    process.exit(1);
  }
}

// Error handlers
process.on('unhandledRejection', (error) => {
  console.error('\n[X] Unhandled error:', error);
  process.exit(1);
});

process.on('SIGINT', () => {
  console.log('\n\nSync interrupted by user.\n');
  process.exit(1);
});

// Run
fullSync();
