#!/usr/bin/env node
/**
 * Automated Multi-Client Sync Scheduler
 *
 * Automatically runs sync operations for all 6 clients on schedule.
 * Uses node-cron for scheduling and runs as a background service.
 *
 * Features:
 * - Staggered sync times for each client
 * - Daily incremental + Weekly full sync
 * - Error handling with retries
 * - Comprehensive logging
 * - Email notifications on failures
 *
 * Usage:
 *   node sync/scheduler/sync-scheduler.js
 *
 * Install as Windows Service:
 *   node sync/scheduler/install-service.js
 */

const cron = require('node-cron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const winston = require('winston');
const nodemailer = require('nodemailer');
const config = require('./clients-config');

// Initialize logger
const logger = winston.createLogger({
  level: config.settings.logLevel,
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'sync-scheduler' },
  transports: [
    // Write all logs to console
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.printf(({ timestamp, level, message, ...meta }) => {
          return `[${timestamp}] ${level}: ${message} ${Object.keys(meta).length ? JSON.stringify(meta, null, 2) : ''}`;
        })
      )
    }),
    // Write all logs to file
    new winston.transports.File({
      filename: path.join(__dirname, 'logs', 'error.log'),
      level: 'error'
    }),
    new winston.transports.File({
      filename: path.join(__dirname, 'logs', 'combined.log')
    })
  ]
});

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Email transporter (if notifications enabled)
let emailTransporter = null;
if (config.settings.emailNotifications.enabled) {
  emailTransporter = nodemailer.createTransporter(config.email);
}

/**
 * Send email notification
 */
async function sendEmail(subject, message, isError = false) {
  if (!config.settings.emailNotifications.enabled) return;
  if (isError && !config.settings.emailNotifications.onFailure) return;
  if (!isError && !config.settings.emailNotifications.onSuccess) return;

  try {
    await emailTransporter.sendMail({
      from: config.email.from,
      to: config.settings.emailNotifications.recipients.join(', '),
      subject: `[PowerCA Sync] ${subject}`,
      text: message,
      html: `<pre>${message}</pre>`
    });
    logger.info('Email notification sent', { subject });
  } catch (error) {
    logger.error('Failed to send email notification', { error: error.message });
  }
}

/**
 * Run sync for a specific client
 */
async function runSync(client, mode) {
  const startTime = Date.now();
  const logPrefix = `[Client ${client.id}: ${client.name}]`;

  logger.info(`${logPrefix} Starting ${mode} sync (org_id=${client.org_id})`);

  return new Promise((resolve, reject) => {
    const scriptPath = path.join(__dirname, '..', 'full-sync.js');
    const args = [`--mode=${mode}`, `--org-id=${client.org_id}`];

    const child = spawn('node', [scriptPath, ...args], {
      cwd: path.join(__dirname, '..', '..'),
      env: { ...process.env, ORG_ID: client.org_id.toString() },
      stdio: ['ignore', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    // Timeout handling
    const timeout = setTimeout(() => {
      child.kill();
      const error = new Error('Sync timeout');
      logger.error(`${logPrefix} Sync timeout after ${config.settings.syncTimeout}ms`);
      reject(error);
    }, config.settings.syncTimeout);

    child.on('close', (code) => {
      clearTimeout(timeout);
      const duration = ((Date.now() - startTime) / 1000).toFixed(2);

      if (code === 0) {
        logger.info(`${logPrefix} Sync completed successfully in ${duration}s`);
        resolve({ client, mode, duration, success: true });
      } else {
        const error = new Error(`Sync failed with exit code ${code}`);
        logger.error(`${logPrefix} Sync failed in ${duration}s`, {
          exitCode: code,
          stderr: stderr.substring(0, 500)
        });
        reject({ client, mode, duration, error, stderr });
      }
    });

    child.on('error', (error) => {
      clearTimeout(timeout);
      logger.error(`${logPrefix} Sync process error`, { error: error.message });
      reject({ client, mode, error });
    });
  });
}

/**
 * Run sync with retry logic
 */
async function runSyncWithRetry(client, mode) {
  const maxRetries = config.settings.retryOnFailure ? config.settings.maxRetries : 0;
  let lastError = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      if (attempt > 0) {
        logger.info(`[Client ${client.id}] Retry attempt ${attempt}/${maxRetries} after ${config.settings.retryDelay}ms`);
        await new Promise(resolve => setTimeout(resolve, config.settings.retryDelay));
      }

      const result = await runSync(client, mode);

      // Success notification (if enabled)
      if (attempt > 0) {
        await sendEmail(
          `Sync Recovered for ${client.name}`,
          `Sync succeeded on retry attempt ${attempt} after previous failures.\n\nClient: ${client.name}\nMode: ${mode}\nDuration: ${result.duration}s`,
          false
        );
      }

      return result;

    } catch (error) {
      lastError = error;
      logger.warn(`[Client ${client.id}] Sync attempt ${attempt + 1} failed`, {
        error: error.message || error.error?.message
      });
    }
  }

  // All retries failed - send error notification
  await sendEmail(
    `Sync Failed for ${client.name}`,
    `All sync attempts failed after ${maxRetries} retries.\n\nClient: ${client.name}\nMode: ${mode}\nError: ${lastError.message || lastError.error?.message}\n\nPlease check logs for details.`,
    true
  );

  throw lastError;
}

/**
 * Schedule sync for a client
 */
function scheduleClientSync(client) {
  if (!client.enabled) {
    logger.info(`[Client ${client.id}: ${client.name}] Sync disabled, skipping schedule`);
    return;
  }

  // Schedule incremental sync (daily)
  const incrementalJob = cron.schedule(client.schedule.incremental, async () => {
    logger.info(`[CRON] Triggered incremental sync for ${client.name}`);
    try {
      await runSyncWithRetry(client, 'incremental');
    } catch (error) {
      logger.error(`[CRON] Incremental sync failed for ${client.name}`, { error });
    }
  }, {
    scheduled: true,
    timezone: 'Asia/Kolkata' // Adjust to your timezone
  });

  // Schedule full sync (weekly)
  const fullJob = cron.schedule(client.schedule.full, async () => {
    logger.info(`[CRON] Triggered full sync for ${client.name}`);
    try {
      await runSyncWithRetry(client, 'full');
    } catch (error) {
      logger.error(`[CRON] Full sync failed for ${client.name}`, { error });
    }
  }, {
    scheduled: true,
    timezone: 'Asia/Kolkata' // Adjust to your timezone
  });

  logger.info(`[Client ${client.id}: ${client.name}] Scheduled syncs`, {
    incremental: client.schedule.incremental,
    full: client.schedule.full
  });

  return { incrementalJob, fullJob };
}

/**
 * Main function - Start scheduler
 */
async function main() {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║        PowerCA Multi-Client Sync Scheduler               ║
║        Automated Sync Service for 6 Clients              ║
╚═══════════════════════════════════════════════════════════╝
`);

  logger.info('Starting sync scheduler...');
  logger.info(`Timezone: Asia/Kolkata`);
  logger.info(`Auto-sync enabled: ${config.settings.autoSyncEnabled}`);
  logger.info(`Email notifications: ${config.settings.emailNotifications.enabled}`);

  if (!config.settings.autoSyncEnabled) {
    logger.warn('Auto-sync is DISABLED in configuration. No syncs will run automatically.');
    logger.info('Set settings.autoSyncEnabled = true in clients-config.js to enable.');
    return;
  }

  // Schedule all enabled clients
  const scheduledJobs = [];
  config.clients.forEach(client => {
    const jobs = scheduleClientSync(client);
    if (jobs) scheduledJobs.push(jobs);
  });

  logger.info(`Successfully scheduled ${scheduledJobs.length} clients`);

  // Print schedule summary
  console.log('\n📅 Sync Schedule Summary:\n');
  config.clients.filter(c => c.enabled).forEach(client => {
    console.log(`${client.name} (org_id=${client.org_id}):`);
    console.log(`  Incremental: ${client.schedule.incremental} (Daily)`);
    console.log(`  Full:        ${client.schedule.full} (Weekly)\n`);
  });

  logger.info('Scheduler is now running. Press Ctrl+C to stop.');

  // Keep process alive
  process.on('SIGINT', () => {
    logger.info('Received SIGINT. Shutting down gracefully...');
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    logger.info('Received SIGTERM. Shutting down gracefully...');
    process.exit(0);
  });
}

// Handle uncaught errors
process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', { error: error.message, stack: error.stack });
  sendEmail('Critical Error in Sync Scheduler', `Uncaught exception:\n\n${error.stack}`, true);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled promise rejection', { reason });
  sendEmail('Critical Error in Sync Scheduler', `Unhandled rejection:\n\n${reason}`, true);
});

// Start the scheduler
main().catch(error => {
  logger.error('Failed to start scheduler', { error: error.message });
  process.exit(1);
});
