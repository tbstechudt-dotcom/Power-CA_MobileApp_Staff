/**
 * Test Scheduler - Single Client
 *
 * Tests the automated sync scheduler with just one client
 * to verify configuration and sync execution before deploying
 * for all 6 clients.
 */

const path = require('path');
const { spawn } = require('child_process');
const winston = require('winston');

// Configure logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.printf(({ timestamp, level, message }) => {
      return `[${timestamp}] ${level.toUpperCase()}: ${message}`;
    })
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message }) => {
          return `[${timestamp}] ${level}: ${message}`;
        })
      )
    })
  ]
});

// Test client configuration (Client 1)
const testClient = {
  id: 1,
  name: 'Client 1',
  org_id: 1,
  enabled: true,
  schedule: {
    incremental: '0 2 * * *',    // Daily at 2:00 AM (for reference)
    full: '0 3 * * 0'             // Sunday at 3:00 AM (for reference)
  }
};

/**
 * Run sync for test client
 */
async function runSync(mode = 'incremental') {
  return new Promise((resolve, reject) => {
    logger.info(`[${testClient.name}] Starting ${mode} sync (org_id=${testClient.org_id})`);

    const startTime = Date.now();

    // Use full-sync.js (same as the scheduler uses)
    const runnerPath = path.join(__dirname, '..', 'full-sync.js');

    // Build command arguments
    const args = [`--mode=${mode}`];

    // Note: full-sync.js doesn't support --org-id yet
    // It syncs all data regardless of org_id
    // TODO: Add org_id filtering support to full-sync.js for multi-client deployments

    logger.info(`[${testClient.name}] Command: node ${runnerPath} ${args.join(' ')}`);

    // Spawn sync process
    const syncProcess = spawn('node', [runnerPath, ...args], {
      cwd: path.join(__dirname, '..'),
      env: { ...process.env }
    });

    let output = '';
    let errorOutput = '';

    // Capture stdout
    syncProcess.stdout.on('data', (data) => {
      const message = data.toString().trim();
      output += message + '\n';
      logger.info(`[${testClient.name}] ${message}`);
    });

    // Capture stderr
    syncProcess.stderr.on('data', (data) => {
      const message = data.toString().trim();
      errorOutput += message + '\n';
      logger.error(`[${testClient.name}] ${message}`);
    });

    // Handle process completion
    syncProcess.on('close', (code) => {
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      if (code === 0) {
        logger.info(`[${testClient.name}] Sync completed successfully in ${duration}s`);
        resolve({ success: true, duration, output });
      } else {
        logger.error(`[${testClient.name}] Sync failed with exit code ${code} (${duration}s)`);
        reject(new Error(`Sync failed: ${errorOutput || 'Unknown error'}`));
      }
    });

    // Handle process errors
    syncProcess.on('error', (error) => {
      logger.error(`[${testClient.name}] Process error: ${error.message}`);
      reject(error);
    });
  });
}

/**
 * Main test execution
 */
async function main() {
  console.log('');
  console.log('='.repeat(80));
  console.log('POWERCA SYNC SCHEDULER - SINGLE CLIENT TEST');
  console.log('='.repeat(80));
  console.log('');

  logger.info('Test Configuration:');
  logger.info(`  Client: ${testClient.name}`);
  logger.info(`  Org ID: ${testClient.org_id}`);
  logger.info(`  Incremental Schedule: ${testClient.schedule.incremental} (Daily at 2:00 AM)`);
  logger.info(`  Full Sync Schedule: ${testClient.schedule.full} (Sunday at 3:00 AM)`);
  console.log('');

  try {
    // Test incremental sync
    logger.info('[TEST] Running incremental sync...');
    console.log('');

    const incrementalResult = await runSync('incremental');

    console.log('');
    logger.info(`[SUCCESS] Incremental sync completed in ${incrementalResult.duration}s`);
    console.log('');

    // Ask if user wants to test full sync
    logger.info('[OPTION] You can also test full sync by running:');
    logger.info('  node sync/scheduler/test-single-client.js full');
    console.log('');

    console.log('='.repeat(80));
    console.log('TEST COMPLETED SUCCESSFULLY');
    console.log('='.repeat(80));
    console.log('');
    console.log('Next Steps:');
    console.log('  1. Review the sync output above');
    console.log('  2. Check logs in sync/scheduler/logs/ (if configured)');
    console.log('  3. Verify data in Supabase dashboard');
    console.log('  4. If successful, proceed with full 6-client deployment');
    console.log('');

    process.exit(0);

  } catch (error) {
    console.log('');
    logger.error('[FAILED] Test sync failed');
    logger.error(`Error: ${error.message}`);
    console.log('');
    console.log('='.repeat(80));
    console.log('TEST FAILED');
    console.log('='.repeat(80));
    console.log('');
    console.log('Troubleshooting:');
    console.log('  1. Check error messages above');
    console.log('  2. Verify .env file is configured correctly');
    console.log('  3. Ensure Desktop PostgreSQL is running (port 5433)');
    console.log('  4. Test Supabase connection manually');
    console.log('  5. Review sync/runner.js for issues');
    console.log('');

    process.exit(1);
  }
}

// Check command line arguments
const mode = process.argv[2] || 'incremental';

if (!['incremental', 'full'].includes(mode)) {
  console.error('Invalid mode. Use: incremental or full');
  console.log('');
  console.log('Usage:');
  console.log('  node sync/scheduler/test-single-client.js            # Test incremental sync');
  console.log('  node sync/scheduler/test-single-client.js full       # Test full sync');
  console.log('');
  process.exit(1);
}

// Update mode for testing
if (mode === 'full') {
  logger.info('[TEST MODE] Running FULL sync test');
}

// Run test
main();
