/**
 * PowerCA Mobile - Test Scheduling Setup
 *
 * Verifies that the local machine is ready for automated sync scheduling.
 * Checks prerequisites, database connections, and file permissions.
 *
 * Usage:
 *   node scripts/test-scheduling-setup.js
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

require('dotenv').config();

async function testSchedulingSetup() {
  console.log('='.repeat(60));
  console.log('PowerCA Mobile - Scheduling Setup Test');
  console.log('='.repeat(60));
  console.log('');

  let allTestsPassed = true;

  // Test 1: Check Node.js version
  console.log('[TEST] 1. Checking Node.js version...');
  try {
    const nodeVersion = process.version;
    const majorVersion = parseInt(nodeVersion.split('.')[0].substring(1));

    if (majorVersion >= 14) {
      console.log(`[OK] Node.js ${nodeVersion} (>= 14.x required)\n`);
    } else {
      console.log(`[ERROR] Node.js ${nodeVersion} is too old (>= 14.x required)\n`);
      allTestsPassed = false;
    }
  } catch (error) {
    console.log(`[ERROR] Failed to check Node.js version: ${error.message}\n`);
    allTestsPassed = false;
  }

  // Test 2: Check environment variables
  console.log('[TEST] 2. Checking environment variables...');
  const requiredEnvVars = [
    'DESKTOP_DB_PASSWORD',
    'SUPABASE_DB_HOST',
    'SUPABASE_DB_PASSWORD'
  ];

  let envVarsPassed = true;
  for (const envVar of requiredEnvVars) {
    if (process.env[envVar]) {
      console.log(`[OK] ${envVar} is set`);
    } else {
      console.log(`[ERROR] ${envVar} is missing`);
      envVarsPassed = false;
      allTestsPassed = false;
    }
  }

  if (envVarsPassed) {
    console.log('[OK] All required environment variables present\n');
  } else {
    console.log('[ERROR] Missing environment variables - check .env file\n');
  }

  // Test 3: Check Desktop PostgreSQL connection
  console.log('[TEST] 3. Testing Desktop PostgreSQL connection...');
  const desktopPool = new Pool({
    host: process.env.LOCAL_DB_HOST || 'localhost',
    port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
    database: process.env.LOCAL_DB_NAME || 'enterprise_db',
    user: process.env.LOCAL_DB_USER || 'postgres',
    password: process.env.DESKTOP_DB_PASSWORD,
    max: 1,
    connectionTimeoutMillis: 5000
  });

  try {
    const result = await desktopPool.query('SELECT version()');
    console.log('[OK] Desktop PostgreSQL connected');
    console.log(`  - Version: ${result.rows[0].version.split(',')[0]}\n`);
  } catch (error) {
    console.log(`[ERROR] Desktop PostgreSQL connection failed: ${error.message}\n`);
    allTestsPassed = false;
  } finally {
    await desktopPool.end();
  }

  // Test 4: Check Supabase connection
  console.log('[TEST] 4. Testing Supabase connection...');
  const supabasePool = new Pool({
    host: process.env.SUPABASE_DB_HOST,
    port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
    database: process.env.SUPABASE_DB_NAME || 'postgres',
    user: process.env.SUPABASE_DB_USER || 'postgres',
    password: process.env.SUPABASE_DB_PASSWORD,
    ssl: { rejectUnauthorized: false },
    max: 1,
    connectionTimeoutMillis: 10000
  });

  try {
    const result = await supabasePool.query('SELECT version()');
    console.log('[OK] Supabase connected');
    console.log(`  - Version: ${result.rows[0].version.split(',')[0]}\n`);
  } catch (error) {
    console.log(`[ERROR] Supabase connection failed: ${error.message}\n`);
    allTestsPassed = false;
  } finally {
    await supabasePool.end();
  }

  // Test 5: Check metadata tables
  console.log('[TEST] 5. Checking metadata tables...');

  // Check _sync_metadata in Supabase
  const supabasePool2 = new Pool({
    host: process.env.SUPABASE_DB_HOST,
    port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
    database: process.env.SUPABASE_DB_NAME || 'postgres',
    user: process.env.SUPABASE_DB_USER || 'postgres',
    password: process.env.SUPABASE_DB_PASSWORD,
    ssl: { rejectUnauthorized: false },
    max: 1
  });

  try {
    const result = await supabasePool2.query(`
      SELECT table_name FROM information_schema.tables
      WHERE table_name = '_sync_metadata'
    `);

    if (result.rows.length > 0) {
      const countResult = await supabasePool2.query('SELECT COUNT(*) FROM _sync_metadata');
      console.log(`[OK] _sync_metadata exists in Supabase (${countResult.rows[0].count} tables tracked)`);
    } else {
      console.log('[WARN] _sync_metadata table not found in Supabase');
      console.log('  - Run: node scripts/create-sync-metadata-table.js');
    }
  } catch (error) {
    console.log(`[ERROR] Failed to check _sync_metadata: ${error.message}`);
    allTestsPassed = false;
  } finally {
    await supabasePool2.end();
  }

  // Check _reverse_sync_metadata in Desktop
  const desktopPool2 = new Pool({
    host: process.env.LOCAL_DB_HOST || 'localhost',
    port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
    database: process.env.LOCAL_DB_NAME || 'enterprise_db',
    user: process.env.LOCAL_DB_USER || 'postgres',
    password: process.env.DESKTOP_DB_PASSWORD,
    max: 1
  });

  try {
    const result = await desktopPool2.query(`
      SELECT table_name FROM information_schema.tables
      WHERE table_name = '_reverse_sync_metadata'
    `);

    if (result.rows.length > 0) {
      const countResult = await desktopPool2.query('SELECT COUNT(*) FROM _reverse_sync_metadata');
      console.log(`[OK] _reverse_sync_metadata exists in Desktop (${countResult.rows[0].count} tables tracked)\n`);
    } else {
      console.log('[WARN] _reverse_sync_metadata table not found in Desktop');
      console.log('  - Run: node scripts/create-reverse-sync-metadata-table.js\n');
    }
  } catch (error) {
    console.log(`[ERROR] Failed to check _reverse_sync_metadata: ${error.message}\n`);
    allTestsPassed = false;
  } finally {
    await desktopPool2.end();
  }

  // Test 6: Check batch scripts exist
  console.log('[TEST] 6. Checking batch scripts...');
  const batchScripts = [
    'scripts/schedule-forward-sync-full.bat',
    'scripts/schedule-forward-sync-incremental.bat',
    'scripts/schedule-reverse-sync.bat'
  ];

  let batchScriptsPassed = true;
  for (const script of batchScripts) {
    const fullPath = path.join(__dirname, '..', script);
    if (fs.existsSync(fullPath)) {
      console.log(`[OK] ${script} exists`);
    } else {
      console.log(`[ERROR] ${script} not found`);
      batchScriptsPassed = false;
      allTestsPassed = false;
    }
  }

  if (batchScriptsPassed) {
    console.log('[OK] All batch scripts present\n');
  } else {
    console.log('[ERROR] Missing batch scripts\n');
  }

  // Test 7: Check logs directory
  console.log('[TEST] 7. Checking logs directory...');
  const logsDir = path.join(__dirname, '..', 'logs');

  if (!fs.existsSync(logsDir)) {
    try {
      fs.mkdirSync(logsDir);
      console.log('[OK] Created logs directory\n');
    } catch (error) {
      console.log(`[ERROR] Failed to create logs directory: ${error.message}\n`);
      allTestsPassed = false;
    }
  } else {
    console.log('[OK] Logs directory exists\n');
  }

  // Test 8: Check disk space
  console.log('[TEST] 8. Checking disk space...');
  try {
    const { stdout } = await execPromise('wmic logicaldisk get size,freespace,caption');
    const lines = stdout.trim().split('\n').slice(1);

    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      if (parts.length >= 3) {
        const drive = parts[0];
        const freeSpace = parseInt(parts[1]);
        const totalSpace = parseInt(parts[2]);
        const freeGB = (freeSpace / (1024 * 1024 * 1024)).toFixed(2);

        if (drive === 'D:') {
          if (freeGB > 10) {
            console.log(`[OK] Drive ${drive} has ${freeGB} GB free\n`);
          } else {
            console.log(`[WARN] Drive ${drive} has only ${freeGB} GB free (staging tables need space)\n`);
          }
        }
      }
    }
  } catch (error) {
    console.log(`[WARN] Could not check disk space: ${error.message}\n`);
  }

  // Test 9: Check Windows Task Scheduler access
  console.log('[TEST] 9. Checking Windows Task Scheduler access...');
  try {
    const { stdout } = await execPromise('schtasks /Query /TN PowerCA* /FO LIST 2>&1');

    if (stdout.includes('PowerCA_')) {
      console.log('[OK] Found existing PowerCA scheduled tasks');
      console.log('[INFO] Tasks are already configured\n');
    } else {
      console.log('[INFO] No PowerCA tasks found');
      console.log('  - Run: powershell -ExecutionPolicy Bypass -File scripts/setup-windows-scheduler.ps1\n');
    }
  } catch (error) {
    // Task not found is expected if not set up yet
    console.log('[INFO] No PowerCA tasks configured yet');
    console.log('  - Run: powershell -ExecutionPolicy Bypass -File scripts/setup-windows-scheduler.ps1\n');
  }

  // Final Summary
  console.log('='.repeat(60));
  if (allTestsPassed) {
    console.log('[SUCCESS] All Tests Passed!');
    console.log('='.repeat(60));
    console.log('\n[OK] Your system is ready for scheduled sync');
    console.log('\nNext steps:');
    console.log('  1. Set up Windows Task Scheduler:');
    console.log('     powershell -ExecutionPolicy Bypass -File scripts/setup-windows-scheduler.ps1');
    console.log('');
    console.log('  2. Or run Node.js scheduler:');
    console.log('     node scripts/sync-scheduler.js');
    console.log('');
    console.log('  3. Monitor logs:');
    console.log('     dir /b /o-d logs\\*.log');
    console.log('');
  } else {
    console.log('[ERROR] Some Tests Failed');
    console.log('='.repeat(60));
    console.log('\n[ERROR] Please fix the issues above before setting up scheduling');
    console.log('\nCommon fixes:');
    console.log('  - Missing .env file: Copy .env.example to .env and configure');
    console.log('  - PostgreSQL not running: Start PostgreSQL service');
    console.log('  - Metadata tables missing: Run setup scripts');
    console.log('');
    process.exit(1);
  }
}

if (require.main === module) {
  testSchedulingSetup()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('[ERROR] Test failed:', err);
      process.exit(1);
    });
}

module.exports = testSchedulingSetup;
