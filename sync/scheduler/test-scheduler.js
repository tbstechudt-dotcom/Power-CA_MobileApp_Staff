#!/usr/bin/env node
/**
 * Test Script for Sync Scheduler
 *
 * Validates configuration and tests scheduler without actually running syncs
 */

const config = require('./clients-config');
const cron = require('node-cron');

console.log(`
╔═══════════════════════════════════════════════════════════╗
║     PowerCA Sync Scheduler - Configuration Test          ║
╚═══════════════════════════════════════════════════════════╝
`);

// Test 1: Validate configuration
console.log('✓ Testing configuration...\n');

console.log(`Auto-sync enabled: ${config.settings.autoSyncEnabled ? '✓ YES' : '✗ NO'}`);
console.log(`Email notifications: ${config.settings.emailNotifications.enabled ? '✓ Enabled' : '✗ Disabled'}`);
console.log(`Retry on failure: ${config.settings.retryOnFailure ? '✓ YES' : '✗ NO'}`);
if (config.settings.retryOnFailure) {
  console.log(`  Max retries: ${config.settings.maxRetries}`);
  console.log(`  Retry delay: ${config.settings.retryDelay / 1000}s`);
}

// Test 2: Validate clients
console.log(`\n✓ Client Configuration:\n`);

const enabledClients = config.clients.filter(c => c.enabled);
const disabledClients = config.clients.filter(c => !c.enabled);

console.log(`  Total clients: ${config.clients.length}`);
console.log(`  Enabled: ${enabledClients.length}`);
console.log(`  Disabled: ${disabledClients.length}\n`);

// Test 3: Validate cron expressions
console.log('✓ Validating cron schedules...\n');

let hasErrors = false;

config.clients.forEach(client => {
  console.log(`${client.name} (org_id=${client.org_id}) ${client.enabled ? '✓' : '✗ DISABLED'}:`);

  // Validate incremental schedule
  try {
    if (cron.validate(client.schedule.incremental)) {
      console.log(`  ✓ Incremental: ${client.schedule.incremental} - Valid`);
    } else {
      console.log(`  ✗ Incremental: ${client.schedule.incremental} - INVALID`);
      hasErrors = true;
    }
  } catch (e) {
    console.log(`  ✗ Incremental: ${client.schedule.incremental} - ERROR: ${e.message}`);
    hasErrors = true;
  }

  // Validate full schedule
  try {
    if (cron.validate(client.schedule.full)) {
      console.log(`  ✓ Full: ${client.schedule.full} - Valid`);
    } else {
      console.log(`  ✗ Full: ${client.schedule.full} - INVALID`);
      hasErrors = true;
    }
  } catch (e) {
    console.log(`  ✗ Full: ${client.schedule.full} - ERROR: ${e.message}`);
    hasErrors = true;
  }

  console.log();
});

// Test 4: Show next execution times
if (!hasErrors && enabledClients.length > 0) {
  console.log('✓ Next scheduled execution times:\n');

  enabledClients.forEach(client => {
    console.log(`${client.name}:`);

    // This is an approximation - actual execution depends on current time
    const now = new Date();
    console.log(`  Current time: ${now.toLocaleString('en-US', { timeZone: 'Asia/Kolkata' })}`);
    console.log(`  Next incremental sync: Check cron expression ${client.schedule.incremental}`);
    console.log(`  Next full sync: Check cron expression ${client.schedule.full}\n`);
  });
}

// Test 5: Email configuration (if enabled)
if (config.settings.emailNotifications.enabled) {
  console.log('✓ Email Notification Configuration:\n');
  console.log(`  Service: ${config.email.service}`);
  console.log(`  From: ${config.email.from}`);
  console.log(`  Recipients: ${config.settings.emailNotifications.recipients.join(', ')}`);
  console.log(`  Notify on failure: ${config.settings.emailNotifications.onFailure ? 'YES' : 'NO'}`);
  console.log(`  Notify on success: ${config.settings.emailNotifications.onSuccess ? 'YES' : 'NO'}\n`);

  if (!config.email.auth.user || !config.email.auth.pass) {
    console.log('  ⚠️  WARNING: Email credentials not configured!');
    console.log('     Please set email.auth.user and email.auth.pass in clients-config.js\n');
  }
}

// Summary
console.log('═'.repeat(60));

if (hasErrors) {
  console.log('\n❌ ERRORS FOUND! Please fix the issues above before running the scheduler.\n');
  process.exit(1);
} else {
  console.log('\n✅ Configuration is valid! The scheduler is ready to run.\n');

  if (!config.settings.autoSyncEnabled) {
    console.log('⚠️  NOTE: Auto-sync is DISABLED in configuration.');
    console.log('   Set settings.autoSyncEnabled = true to enable automatic syncs.\n');
  }

  console.log('Next steps:');
  console.log('  1. Test manually: node sync-scheduler.js');
  console.log('  2. Install service: node install-service.js install');
  console.log('  3. Start service: node install-service.js start\n');
  process.exit(0);
}
