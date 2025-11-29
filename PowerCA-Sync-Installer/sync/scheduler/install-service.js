#!/usr/bin/env node
/**
 * Windows Service Installer for PowerCA Sync Scheduler
 *
 * Installs the sync scheduler as a Windows Service that runs 24/7
 * and automatically starts when the server boots.
 *
 * Usage:
 *   node sync/scheduler/install-service.js install
 *   node sync/scheduler/install-service.js uninstall
 *   node sync/scheduler/install-service.js start
 *   node sync/scheduler/install-service.js stop
 *   node sync/scheduler/install-service.js restart
 */

const Service = require('node-windows').Service;
const path = require('path');

const command = process.argv[2];

// Create a new service object
const svc = new Service({
  name: 'PowerCA Sync Scheduler',
  description: 'Automated sync service for PowerCA Mobile - syncs 6 clients between Desktop and Supabase',
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
  workingDirectory: path.join(__dirname, '..', '..')
});

// Event handlers
svc.on('install', () => {
  console.log('✅ Service installed successfully!');
  console.log('   Service Name: PowerCA Sync Scheduler');
  console.log('   Status: Installed (not started)');
  console.log('\nNext steps:');
  console.log('   1. Configure clients in sync/scheduler/clients-config.js');
  console.log('   2. Start service: node sync/scheduler/install-service.js start');
  console.log('   3. Check logs: sync/scheduler/logs/combined.log\n');
  console.log('To start the service automatically, run:');
  console.log('   sc config "PowerCA Sync Scheduler" start=auto\n');
});

svc.on('uninstall', () => {
  console.log('✅ Service uninstalled successfully!');
});

svc.on('start', () => {
  console.log('✅ Service started successfully!');
  console.log('   The sync scheduler is now running in the background.');
  console.log('   Check logs: sync/scheduler/logs/combined.log\n');
});

svc.on('stop', () => {
  console.log('✅ Service stopped successfully!');
});

svc.on('error', (err) => {
  console.error('❌ Service error:', err.message);
});

svc.on('alreadyinstalled', () => {
  console.log('⚠️  Service is already installed.');
  console.log('   To reinstall: node sync/scheduler/install-service.js uninstall');
  console.log('                 node sync/scheduler/install-service.js install\n');
});

svc.on('alreadyuninstalled', () => {
  console.log('⚠️  Service is already uninstalled.');
});

svc.on('invalidinstallation', () => {
  console.log('❌ Invalid installation detected.');
  console.log('   Please uninstall and reinstall the service.\n');
});

// Execute command
switch (command) {
  case 'install':
    console.log('Installing PowerCA Sync Scheduler as Windows Service...\n');
    svc.install();
    break;

  case 'uninstall':
    console.log('Uninstalling PowerCA Sync Scheduler service...\n');
    svc.uninstall();
    break;

  case 'start':
    console.log('Starting PowerCA Sync Scheduler service...\n');
    svc.start();
    break;

  case 'stop':
    console.log('Stopping PowerCA Sync Scheduler service...\n');
    svc.stop();
    break;

  case 'restart':
    console.log('Restarting PowerCA Sync Scheduler service...\n');
    svc.restart();
    break;

  default:
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║     PowerCA Sync Scheduler - Windows Service Manager     ║
╚═══════════════════════════════════════════════════════════╝

Usage:
  node sync/scheduler/install-service.js <command>

Commands:
  install     Install service (run as administrator)
  uninstall   Uninstall service (run as administrator)
  start       Start the service
  stop        Stop the service
  restart     Restart the service

Example:
  node sync/scheduler/install-service.js install
  node sync/scheduler/install-service.js start

Note: Installation and uninstallation require administrator privileges.
      Right-click Command Prompt and select "Run as administrator"
`);
    process.exit(1);
}
