/**
 * PowerCA Mobile - Node.js Sync Scheduler
 *
 * Alternative to Windows Task Scheduler - runs as a persistent Node.js process
 * that schedules and executes forward and reverse sync operations.
 *
 * Installation:
 *   npm install node-cron
 *
 * Usage:
 *   node scripts/sync-scheduler.js
 *
 * Run as Windows Service:
 *   npm install -g node-windows
 *   node scripts/install-sync-service.js
 */

const cron = require('node-cron');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// Ensure logs directory exists
const logsDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir);
}

// Helper function to run sync commands
function runSync(command, description) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const logFile = path.join(logsDir, `${description}_${timestamp}.log`);

  console.log(`\n${'='.repeat(60)}`);
  console.log(`[INFO] ${new Date().toISOString()}`);
  console.log(`[INFO] Running: ${description}`);
  console.log(`[INFO] Log: ${logFile}`);
  console.log(`${'='.repeat(60)}\n`);

  const logStream = fs.createWriteStream(logFile);

  const child = exec(command, {
    cwd: path.join(__dirname, '..'),
    env: process.env
  });

  child.stdout.pipe(logStream);
  child.stderr.pipe(logStream);

  child.stdout.on('data', (data) => {
    process.stdout.write(data);
  });

  child.stderr.on('data', (data) => {
    process.stderr.write(data);
  });

  child.on('close', (code) => {
    logStream.end();
    if (code === 0) {
      console.log(`[OK] ${description} completed successfully\n`);
    } else {
      console.error(`[ERROR] ${description} failed with exit code ${code}\n`);
      // Optional: Send notification on failure
      // sendErrorNotification(description, logFile);
    }
  });
}

// Forward Sync (Full) - Daily at 2:00 AM
console.log('[INFO] Scheduling Forward Sync (Full) - Daily at 2:00 AM...');
cron.schedule('0 2 * * *', () => {
  runSync(
    'node sync/production/runner-staging.js --mode=full',
    'forward-sync-full'
  );
}, {
  timezone: 'Asia/Manila' // Change to your timezone
});

// Forward Sync (Incremental) - Every 4 hours at 8 AM, 12 PM, 4 PM, 8 PM
console.log('[INFO] Scheduling Forward Sync (Incremental) - Every 4 hours...');
cron.schedule('0 8,12,16,20 * * *', () => {
  runSync(
    'node sync/production/runner-staging.js --mode=incremental',
    'forward-sync-incremental'
  );
}, {
  timezone: 'Asia/Manila'
});

// Reverse Sync - Every hour
console.log('[INFO] Scheduling Reverse Sync - Every hour...');
cron.schedule('0 * * * *', () => {
  runSync(
    'node sync/production/reverse-sync-engine.js',
    'reverse-sync'
  );
}, {
  timezone: 'Asia/Manila'
});

console.log('\n' + '='.repeat(60));
console.log('[SUCCESS] PowerCA Mobile Sync Scheduler Started');
console.log('='.repeat(60));
console.log('\nScheduled Tasks:');
console.log('  1. Forward Sync (Full)       - Daily at 2:00 AM');
console.log('  2. Forward Sync (Incremental) - Every 4 hours (8 AM, 12 PM, 4 PM, 8 PM)');
console.log('  3. Reverse Sync              - Every hour');
console.log('\nLogs directory: ' + logsDir);
console.log('\nPress Ctrl+C to stop the scheduler\n');

// Keep the process running
process.on('SIGINT', () => {
  console.log('\n[INFO] Shutting down sync scheduler...');
  process.exit(0);
});

// Optional: Health check endpoint (if you want to monitor the scheduler)
const http = require('http');
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'running',
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    }));
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(3001, () => {
  console.log('[INFO] Health check server running on http://localhost:3001/health\n');
});
