/**
 * PowerCA Mobile - Install Sync Scheduler as Windows Service
 *
 * Installs the Node.js sync scheduler as a persistent Windows service
 * that runs automatically on system startup.
 *
 * Prerequisites:
 *   npm install -g node-windows
 *
 * Usage:
 *   node scripts/install-sync-service.js
 *
 * To uninstall:
 *   node scripts/uninstall-sync-service.js
 */

const Service = require('node-windows').Service;
const path = require('path');

// Create a new service object
const svc = new Service({
  name: 'PowerCA Mobile Sync Scheduler',
  description: 'Automated bidirectional sync between Desktop PostgreSQL and Supabase Cloud for PowerCA Mobile',
  script: path.join(__dirname, 'sync-scheduler.js'),
  nodeOptions: [
    '--harmony',
    '--max_old_space_size=4096'
  ],
  env: [
    {
      name: 'NODE_ENV',
      value: 'production'
    }
  ],
  wait: 2,
  grow: 0.5,
  maxRestarts: 10
});

// Listen for the "install" event
svc.on('install', function() {
  console.log('[OK] Service installed successfully!');
  console.log('\nService Details:');
  console.log('  Name: PowerCA Mobile Sync Scheduler');
  console.log('  Status: Installed (not started)');
  console.log('\nTo start the service:');
  console.log('  1. Open Services (services.msc)');
  console.log('  2. Find "PowerCA Mobile Sync Scheduler"');
  console.log('  3. Right-click -> Start');
  console.log('\nOr use command line:');
  console.log('  net start "PowerCA Mobile Sync Scheduler"');
  console.log('\nTo check service status:');
  console.log('  sc query "PowerCA Mobile Sync Scheduler"');
  console.log('\nLogs location:');
  console.log('  ' + path.join(__dirname, '..', 'logs'));
  console.log('\nService will start automatically on system reboot.');

  // Auto-start the service
  svc.start();
});

// Listen for the "start" event
svc.on('start', function() {
  console.log('\n[OK] Service started successfully!');
  console.log('[INFO] Sync scheduler is now running');
});

// Listen for the "alreadyinstalled" event
svc.on('alreadyinstalled', function() {
  console.log('[WARN] Service is already installed!');
  console.log('\nTo reinstall:');
  console.log('  1. Run: node scripts/uninstall-sync-service.js');
  console.log('  2. Run: node scripts/install-sync-service.js');
});

// Listen for errors
svc.on('error', function(err) {
  console.error('[ERROR] Service installation failed:', err.message);
});

// Install the service
console.log('[INFO] Installing PowerCA Mobile Sync Scheduler as Windows Service...');
console.log('[INFO] This may take a few seconds...\n');
svc.install();
