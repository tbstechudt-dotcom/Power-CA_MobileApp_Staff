/**
 * PowerCA Mobile - Create Minimal Deployment Bundle
 *
 * Creates a minimal deployment package containing only the sync engines
 * and batch scripts needed for the local server (Desktop PostgreSQL machine).
 *
 * Output: PowerCA-Sync-Deploy.zip (~5-10 MB)
 *
 * Usage:
 *   node deployment/create-deployment-bundle.js
 */

const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

// Deployment configuration
const DEPLOY_NAME = 'PowerCA-Sync';
const DEPLOY_DIR = path.join(__dirname, '..', 'deploy-temp');
const OUTPUT_ZIP = path.join(__dirname, '..', 'PowerCA-Sync-Deploy.zip');

// Files and folders to include
const DEPLOYMENT_FILES = {
  // Sync engines (production only)
  'sync/production/runner-staging.js': 'sync/production/runner-staging.js',
  'sync/production/engine-staging.js': 'sync/production/engine-staging.js',
  'sync/production/reverse-sync-engine.js': 'sync/production/reverse-sync-engine.js',
  'sync/production/config.js': 'sync/production/config.js',

  // Batch scripts (all)
  'batch-scripts/manual/sync-menu.bat': 'batch-scripts/manual/sync-menu.bat',
  'batch-scripts/manual/sync-full.bat': 'batch-scripts/manual/sync-full.bat',
  'batch-scripts/manual/sync-incremental.bat': 'batch-scripts/manual/sync-incremental.bat',
  'batch-scripts/manual/sync-reverse.bat': 'batch-scripts/manual/sync-reverse.bat',
  'batch-scripts/automated/forward-sync-full.bat': 'batch-scripts/automated/forward-sync-full.bat',
  'batch-scripts/automated/forward-sync-incremental.bat': 'batch-scripts/automated/forward-sync-incremental.bat',
  'batch-scripts/automated/reverse-sync.bat': 'batch-scripts/automated/reverse-sync.bat',
  'batch-scripts/automated/setup-windows-scheduler.ps1': 'batch-scripts/automated/setup-windows-scheduler.ps1',

  // Support scripts (minimal)
  'scripts/create-sync-metadata-table.js': 'scripts/create-sync-metadata-table.js',
  'scripts/create-reverse-sync-metadata-table.js': 'scripts/create-reverse-sync-metadata-table.js',
  'scripts/verify-all-tables.js': 'scripts/verify-all-tables.js',
  'scripts/test-scheduling-setup.js': 'scripts/test-scheduling-setup.js',
};

// Deployment README content
const DEPLOYMENT_README = `# PowerCA Mobile - Sync Engine Deployment

**Minimal deployment package for local server**

---

## Quick Start

### Prerequisites

- Windows 10/11 or Windows Server 2016+
- Node.js v14+ installed ([Download](https://nodejs.org/))
- PostgreSQL Desktop running on port 5433

### Installation Steps

**Step 1:** Extract this ZIP file to \`C:\\PowerCA-Sync\\\`

**Step 2:** Install dependencies
\`\`\`cmd
cd C:\\PowerCA-Sync
npm install
\`\`\`

**Step 3:** Create \`.env\` file
\`\`\`cmd
copy .env.example .env
notepad .env
\`\`\`

Add your credentials:
\`\`\`env
DESKTOP_DB_PASSWORD=your_desktop_password
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PASSWORD=your_supabase_password
\`\`\`

**Step 4:** Test connection
\`\`\`cmd
node scripts\\test-scheduling-setup.js
\`\`\`

**Step 5:** Setup scheduled tasks
\`\`\`powershell
powershell -ExecutionPolicy Bypass -File batch-scripts\\automated\\setup-windows-scheduler.ps1
\`\`\`

**Step 6:** Test manual sync
\`\`\`cmd
batch-scripts\\manual\\sync-menu.bat
\`\`\`

---

## Scheduled Sync Times

- **10:00 AM** - Forward Full Sync (Desktop → Supabase)
- **12:00 PM** - Forward Incremental (Desktop → Supabase)
- **5:00 PM** - Forward Incremental (Desktop → Supabase)
- **5:30 PM** - Reverse Sync (Supabase → Desktop)

---

## Monitoring

**View logs:**
\`\`\`cmd
dir /b /o-d logs\\*.log
type logs\\forward-sync-full_*.log
\`\`\`

**Check scheduled tasks:**
\`\`\`cmd
schtasks /Query /TN PowerCA*
\`\`\`

**Verify data:**
\`\`\`cmd
node scripts\\verify-all-tables.js
\`\`\`

---

## Support

For detailed documentation, see SETUP.md

**Deployment Date:** ${new Date().toISOString().split('T')[0]}
**Package Version:** 1.0
`;

// Deployment setup guide
const DEPLOYMENT_SETUP = `# PowerCA Mobile - Deployment Setup Guide

## Installation Checklist

- [ ] Extract ZIP to C:\\PowerCA-Sync
- [ ] Install Node.js (if not already installed)
- [ ] Run \`npm install\`
- [ ] Create .env file with credentials
- [ ] Test connection with test-scheduling-setup.js
- [ ] Setup Windows Task Scheduler
- [ ] Test manual sync with sync-menu.bat
- [ ] Verify scheduled tasks created
- [ ] Check logs directory

## Manual Sync Testing

Before setting up automation, test each sync type manually:

\`\`\`cmd
# Test menu (easiest)
batch-scripts\\manual\\sync-menu.bat

# Or test individual syncs
batch-scripts\\manual\\sync-reverse.bat      # Fastest (~1-2 min)
batch-scripts\\manual\\sync-incremental.bat  # Fast (~30-60 sec)
batch-scripts\\manual\\sync-full.bat         # Slow (~2-5 min)
\`\`\`

## Automated Sync Setup

\`\`\`powershell
# Run as Administrator
powershell -ExecutionPolicy Bypass -File batch-scripts\\automated\\setup-windows-scheduler.ps1

# Verify tasks created
schtasks /Query /TN PowerCA*

# Test a task manually
schtasks /Run /TN "PowerCA_ReverseSync_Daily"
\`\`\`

## Troubleshooting

**"Module not found" error:**
\`\`\`cmd
cd C:\\PowerCA-Sync
npm install
\`\`\`

**"Cannot connect to database" error:**
- Check PostgreSQL is running on port 5433
- Verify .env file has correct credentials
- Test with: \`node scripts\\test-scheduling-setup.js\`

**Scheduled task not running:**
- Check system is ON at scheduled time
- Verify task is enabled in Task Scheduler
- Check logs folder for error messages

## Daily Operations

**Morning (10:00 AM):**
- Full sync runs automatically

**Afternoon (12:00 PM, 5:00 PM):**
- Incremental syncs run automatically

**Evening (5:30 PM):**
- Reverse sync runs automatically

**Check logs periodically:**
\`\`\`cmd
dir /b /o-d C:\\PowerCA-Sync\\logs\\*.log
findstr /I "ERROR" C:\\PowerCA-Sync\\logs\\*.log
\`\`\`

## Maintenance

**Weekly:**
- Review logs for errors
- Verify record counts match

**Monthly:**
- Clean old logs (> 30 days)
- Update npm dependencies: \`npm update\`
- Backup .env file

## Security

**Protect .env file:**
\`\`\`cmd
icacls "C:\\PowerCA-Sync\\.env" /inheritance:r /grant:r "%USERNAME%:F"
\`\`\`

**Firewall:**
- Allow outbound to localhost:5433 (Desktop PostgreSQL)
- Allow outbound to db.jacqfogzgzvbjeizljqf.supabase.co:5432 (Supabase)

---

**Deployment Package Version:** 1.0
**Created:** ${new Date().toISOString().split('T')[0]}
`;

// Package.json for deployment (minimal dependencies)
const DEPLOYMENT_PACKAGE_JSON = {
  name: "powerca-sync-deployment",
  version: "1.0.0",
  description: "PowerCA Mobile - Sync Engine Deployment Package",
  main: "sync/production/runner-staging.js",
  scripts: {
    "test": "node scripts/test-scheduling-setup.js",
    "verify": "node scripts/verify-all-tables.js",
    "setup": "powershell -ExecutionPolicy Bypass -File batch-scripts/automated/setup-windows-scheduler.ps1"
  },
  dependencies: {
    "pg": "^8.11.3",
    "dotenv": "^16.3.1"
  },
  engines: {
    "node": ">=14.0.0"
  },
  keywords": ["powerca", "sync", "postgresql", "supabase"],
  author": "PowerCA Mobile Team",
  license": "PROPRIETARY"
};

// .env.example template
const ENV_EXAMPLE = `# PowerCA Mobile - Environment Configuration
# Copy this file to .env and fill in your credentials

# Desktop PostgreSQL Database
DESKTOP_DB_PASSWORD=your_desktop_password_here
LOCAL_DB_HOST=localhost
LOCAL_DB_PORT=5433
LOCAL_DB_NAME=enterprise_db
LOCAL_DB_USER=postgres

# Supabase Cloud Database
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=your_supabase_password_here

# Optional Settings
BATCH_SIZE=1000
STATEMENT_TIMEOUT=600000
`;

// Helper function to copy file
function copyFile(src, dest) {
  const srcPath = path.join(__dirname, '..', src);
  const destPath = path.join(DEPLOY_DIR, dest);

  // Create directory if doesn't exist
  const destDir = path.dirname(destPath);
  if (!fs.existsSync(destDir)) {
    fs.mkdirSync(destDir, { recursive: true });
  }

  // Copy file
  fs.copyFileSync(srcPath, destPath);
  console.log(`  ✓ ${src}`);
}

// Helper function to fix batch file paths for deployment
function fixBatchFilePaths(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');

  // Replace hardcoded "D:\PowerCA Mobile" with relative path
  // Batch files need to go up 2 levels from batch-scripts/manual|automated/ to root
  if (filePath.includes('batch-scripts')) {
    content = content.replace(/cd \/d "D:\\PowerCA Mobile"/g, 'cd /d "%~dp0..\\.."');
  }

  // For PowerShell script, update the working directory
  if (filePath.endsWith('.ps1')) {
    content = content.replace(
      /\$WorkingDir = "D:\\PowerCA Mobile"/g,
      '$WorkingDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)'
    );

    // Also update the batch file paths in the PowerShell script
    content = content.replace(
      /\$WorkingDir\\batch-scripts\\automated\\/g,
      '"$WorkingDir\\batch-scripts\\automated\\'
    );
  }

  fs.writeFileSync(filePath, content, 'utf8');
}

// Main deployment function
async function createDeploymentBundle() {
  console.log('='.repeat(60));
  console.log('PowerCA Mobile - Creating Deployment Bundle');
  console.log('='.repeat(60));
  console.log('');

  try {
    // Step 1: Clean and create temp directory
    console.log('[1/6] Preparing deployment directory...');
    if (fs.existsSync(DEPLOY_DIR)) {
      fs.rmSync(DEPLOY_DIR, { recursive: true, force: true });
    }
    fs.mkdirSync(DEPLOY_DIR, { recursive: true });
    console.log('  ✓ Created temp directory\n');

    // Step 2: Copy sync engine files
    console.log('[2/7] Copying sync engine files...');
    for (const [src, dest] of Object.entries(DEPLOYMENT_FILES)) {
      copyFile(src, dest);
    }
    console.log('  ✓ Copied ' + Object.keys(DEPLOYMENT_FILES).length + ' files\n');

    // Step 3: Fix hardcoded paths in batch files
    console.log('[3/7] Fixing batch file paths for deployment...');
    const batchFiles = Object.values(DEPLOYMENT_FILES).filter(f => f.endsWith('.bat') || f.endsWith('.ps1'));
    for (const batchFile of batchFiles) {
      const fullPath = path.join(DEPLOY_DIR, batchFile);
      fixBatchFilePaths(fullPath);
    }
    console.log(`  ✓ Fixed ${batchFiles.length} batch files to use relative paths\n`);

    // Step 4: Create deployment package.json
    console.log('[4/7] Creating package.json...');
    fs.writeFileSync(
      path.join(DEPLOY_DIR, 'package.json'),
      JSON.stringify(DEPLOYMENT_PACKAGE_JSON, null, 2)
    );
    console.log('  ✓ Created package.json\n');

    // Step 5: Create documentation files
    console.log('[5/7] Creating documentation...');
    fs.writeFileSync(path.join(DEPLOY_DIR, 'README.md'), DEPLOYMENT_README);
    fs.writeFileSync(path.join(DEPLOY_DIR, 'SETUP.md'), DEPLOYMENT_SETUP);
    fs.writeFileSync(path.join(DEPLOY_DIR, '.env.example'), ENV_EXAMPLE);
    console.log('  ✓ Created README.md');
    console.log('  ✓ Created SETUP.md');
    console.log('  ✓ Created .env.example\n');

    // Step 6: Create logs directory
    console.log('[6/7] Creating logs directory...');
    fs.mkdirSync(path.join(DEPLOY_DIR, 'logs'), { recursive: true });
    fs.writeFileSync(
      path.join(DEPLOY_DIR, 'logs', 'README.txt'),
      'Sync logs will be automatically created in this directory.\n'
    );
    console.log('  ✓ Created logs directory\n');

    // Step 7: Create ZIP file
    console.log('[7/7] Creating ZIP archive...');

    // Check if PowerShell is available
    try {
      // Remove existing ZIP if it exists
      if (fs.existsSync(OUTPUT_ZIP)) {
        fs.unlinkSync(OUTPUT_ZIP);
      }

      // Create ZIP using PowerShell
      const psCommand = `Compress-Archive -Path "${DEPLOY_DIR}\\*" -DestinationPath "${OUTPUT_ZIP}" -Force`;
      await execPromise(`powershell -Command "${psCommand}"`);

      console.log('  ✓ Created PowerCA-Sync-Deploy.zip\n');

      // Step 7: Cleanup temp directory
      console.log('[7/7] Cleaning up...');
      fs.rmSync(DEPLOY_DIR, { recursive: true, force: true });
      console.log('  ✓ Removed temp directory\n');

      // Success summary
      const stats = fs.statSync(OUTPUT_ZIP);
      const sizeKB = (stats.size / 1024).toFixed(2);
      const sizeMB = (stats.size / (1024 * 1024)).toFixed(2);

      console.log('='.repeat(60));
      console.log('[SUCCESS] Deployment Bundle Created!');
      console.log('='.repeat(60));
      console.log('');
      console.log('Output File: ' + OUTPUT_ZIP);
      console.log('Package Size: ' + sizeKB + ' KB (' + sizeMB + ' MB)');
      console.log('');
      console.log('Contents:');
      console.log('  - 4 sync engine scripts (production)');
      console.log('  - 8 batch files (manual + automated)');
      console.log('  - 4 support scripts');
      console.log('  - package.json (for npm install)');
      console.log('  - .env.example (template)');
      console.log('  - README.md + SETUP.md (documentation)');
      console.log('');
      console.log('Next Steps:');
      console.log('  1. Transfer PowerCA-Sync-Deploy.zip to local server');
      console.log('  2. Extract to C:\\PowerCA-Sync\\');
      console.log('  3. Run: npm install');
      console.log('  4. Create .env file with credentials');
      console.log('  5. Setup scheduled tasks');
      console.log('');
      console.log('See SETUP.md in the ZIP for detailed instructions.');
      console.log('');

    } catch (zipError) {
      console.error('  ✗ Failed to create ZIP:', zipError.message);
      console.log('\n[INFO] Deployment files are ready in: ' + DEPLOY_DIR);
      console.log('[INFO] You can manually zip this folder.');
    }

  } catch (error) {
    console.error('\n[ERROR] Deployment bundle creation failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  createDeploymentBundle()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('[ERROR]', err);
      process.exit(1);
    });
}

module.exports = createDeploymentBundle;
