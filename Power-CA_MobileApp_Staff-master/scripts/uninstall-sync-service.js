/**
 * PowerCA Mobile - Uninstall Sync Scheduler Windows Service
 *
 * Removes the PowerCA Mobile Sync Scheduler Windows service.
 *
 * Usage:
 *   node scripts/uninstall-sync-service.js
 */

const Service = require('node-windows').Service;
const path = require('path');

// Create a new service object (same configuration as install)
const svc = new Service({
  name: 'PowerCA Mobile Sync Scheduler',
  script: path.join(__dirname, 'sync-scheduler.js')
});

// Listen for the "uninstall" event
svc.on('uninstall', function() {
  console.log('[OK] Service uninstalled successfully!');
  console.log('[INFO] The sync scheduler service has been removed from Windows Services');
  console.log('\nTo reinstall:');
  console.log('  node scripts/install-sync-service.js');
});

// Listen for the "alreadyuninstalled" event
svc.on('alreadyuninstalled', function() {
  console.log('[WARN] Service is not installed!');
  console.log('[INFO] Nothing to uninstall.');
});

// Listen for errors
svc.on('error', function(err) {
  console.error('[ERROR] Service uninstallation failed:', err.message);
});

// Uninstall the service
console.log('[INFO] Uninstalling PowerCA Mobile Sync Scheduler service...');
console.log('[INFO] This may take a few seconds...\n');
svc.uninstall();
