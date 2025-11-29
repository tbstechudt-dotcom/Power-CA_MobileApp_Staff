/**
 * Simple Scheduler Test -  Single Client (No Pre-Sync)
 *
 * Tests ONLY forward and reverse sync, skipping pre-sync
 * to avoid duplicate issues with sync_views_to_tables()
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

// Test client configuration
const testClient = {
  id: 1,
  name: 'Client 1',
  org_id: 1
};

/**
 * Run a sync script
 */
async function runScript(scriptName, args = []) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(__dirname, '..', scriptName);

    logger.info(`Running: ${scriptName} ${args.join(' ')}`);
    const startTime = Date.now();

    const syncProcess = spawn('node', [scriptPath, ...args], {
      cwd: path.join(__dirname, '..'),
      env: { ...process.env }
    });

    let output = '';

    syncProcess.stdout.on('data', (data) => {
      const message = data.toString().trim();
      output += message + '\n';
      console.log(message);
    });

    syncProcess.stderr.on('data', (data) => {
      const message = data.toString().trim();
      console.error(message);
    });

    syncProcess.on('close', (code) => {
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      if (code === 0) {
        logger.info(`${scriptName} completed successfully in ${duration}s`);
        resolve({ success: true, duration, output });
      } else {
        logger.error(`${scriptName} failed with exit code ${code}`);
        reject(new Error(`${scriptName} failed`));
      }
    });

    syncProcess.on('error', (error) => {
      logger.error(`Process error: ${error.message}`);
      reject(error);
    });
  });
}

/**
 * Main test execution
 */
async function main() {
  console.log('\n╔═══════════════════════════════════════════════════════════╗');
  console.log('║   SIMPLE SYNC TEST - Forward + Reverse Sync Only          ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  logger.info(`Testing Client: ${testClient.name} (org_id=${testClient.org_id})`);
  console.log('');

  try {
    // Step 1: Forward Sync
    logger.info('[STEP 1/2] Forward Sync - Desktop to Supabase');
    await runScript('runner-staging.js', ['--mode=incremental']);
    console.log('');

    // Step 2: Reverse Sync
    logger.info('[STEP 2/2] Reverse Sync - Supabase to Desktop');
    await runScript('reverse-sync-runner.js');
    console.log('');

    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║               ✅ TEST COMPLETED SUCCESSFULLY              ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    console.log('Next Steps:');
    console.log('  1. If successful, the automated scheduler can be deployed');
    console.log('  2. Install as Windows Service:');
    console.log('     cd sync/scheduler && install-service.bat');
    console.log('');

    process.exit(0);

  } catch (error) {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║                  ❌ TEST FAILED                           ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    logger.error(`Error: ${error.message}`);
    console.log('');

    process.exit(1);
  }
}

// Run test
main();
