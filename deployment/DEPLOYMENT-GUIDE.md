# PowerCA Mobile - Sync Engine Deployment Guide

**Minimal deployment for local server (Desktop PostgreSQL machine)**

---

## Overview

The local server only needs the **sync engines and batch scripts** - not the full project.

**Full Project Size:** ~500+ MB (includes Flutter app, docs, dev tools)
**Minimal Deployment:** ~5-10 MB (sync engines only)

---

## What's Needed on Local Server

### Required Files

```
PowerCA-Sync/                          # Minimal deployment folder
├── sync/
│   └── production/                    # Production sync engines
│       ├── runner-staging.js          # Forward sync orchestrator
│       ├── engine-staging.js          # Forward sync engine
│       ├── reverse-sync-engine.js     # Reverse sync engine
│       └── config.js                  # Database configuration
│
├── batch-scripts/
│   ├── manual/                        # Interactive scripts
│   │   ├── sync-menu.bat
│   │   ├── sync-full.bat
│   │   ├── sync-incremental.bat
│   │   └── sync-reverse.bat
│   │
│   └── automated/                     # Scheduled scripts
│       ├── forward-sync-full.bat
│       ├── forward-sync-incremental.bat
│       ├── reverse-sync.bat
│       └── setup-windows-scheduler.ps1
│
├── scripts/                           # Support scripts
│   ├── create-sync-metadata-table.js
│   ├── create-reverse-sync-metadata-table.js
│   ├── verify-all-tables.js
│   └── test-scheduling-setup.js
│
├── node_modules/                      # Dependencies (auto-installed)
│   ├── pg/                            # PostgreSQL client
│   └── dotenv/                        # Environment variables
│
├── .env                               # Credentials (create on server)
├── package.json                       # Node.js dependencies
├── package-lock.json                  # Dependency lock file
├── README.md                          # Deployment instructions
└── logs/                              # Sync logs (auto-created)
```

### Required Dependencies

```json
{
  "dependencies": {
    "pg": "^8.11.3",
    "dotenv": "^16.3.1"
  }
}
```

---

## What's NOT Needed

The following folders/files are **NOT required** on the local server:

```
❌ lib/                    # Flutter app code
❌ android/                # Android build files
❌ ios/                    # iOS build files
❌ test/                   # Flutter tests
❌ docs/                   # Project documentation
❌ sync/development/       # Development/unsafe scripts
❌ sync/SYNC-ENGINE-ETL-GUIDE.md  # Documentation (large file)
❌ .git/                   # Git repository
❌ .dart_tool/             # Dart build tools
❌ build/                  # Flutter build output
❌ CLAUDE.md               # AI documentation
❌ Most other .md files    # Documentation
```

**Result:** Only 5-10 MB instead of 500+ MB

---

## Deployment Methods

### Option 1: Automated Deployment Bundle (Recommended)

Use the deployment script to create a minimal bundle automatically.

### Option 2: Manual Deployment

Copy only the required files listed above.

### Option 3: Git Clone + Cleanup

Clone full repo, then delete unnecessary folders.

---

## Deployment Steps (Option 1 - Automated)

### Step 1: Create Deployment Bundle

On your development machine, run:

```bash
node deployment/create-deployment-bundle.js
```

This creates: `PowerCA-Sync-Deploy.zip` (~5-10 MB)

### Step 2: Transfer to Local Server

```powershell
# Copy via network share
Copy-Item "PowerCA-Sync-Deploy.zip" "\\LOCAL-SERVER\C$\Deploy\"

# Or use USB drive, email, etc.
```

### Step 3: Extract on Local Server

```powershell
# Extract to C:\PowerCA-Sync\
Expand-Archive -Path "C:\Deploy\PowerCA-Sync-Deploy.zip" -DestinationPath "C:\PowerCA-Sync"
```

### Step 4: Install Node.js (if not installed)

Download and install: https://nodejs.org/ (LTS version)

Verify:
```cmd
node --version
npm --version
```

### Step 5: Install Dependencies

```cmd
cd C:\PowerCA-Sync
npm install
```

### Step 6: Configure Environment

Create `.env` file:

```cmd
cd C:\PowerCA-Sync
notepad .env
```

Add credentials:
```env
# Desktop PostgreSQL
DESKTOP_DB_PASSWORD=your_desktop_password

# Supabase Cloud
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PASSWORD=your_supabase_password
```

Save and close.

### Step 7: Test Connection

```cmd
node scripts/test-scheduling-setup.js
```

Should show:
```
[OK] Desktop PostgreSQL connected
[OK] Supabase connected
```

### Step 8: Setup Scheduled Tasks

```powershell
cd C:\PowerCA-Sync
powershell -ExecutionPolicy Bypass -File batch-scripts\automated\setup-windows-scheduler.ps1
```

### Step 9: Verify

```cmd
# Check scheduled tasks
schtasks /Query /TN PowerCA*

# Test manual sync
batch-scripts\manual\sync-menu.bat
```

---

## Deployment Bundle Structure

The deployment script creates this structure:

```
PowerCA-Sync/
├── sync/
│   └── production/        # 4 JS files (~50 KB)
├── batch-scripts/         # 8 BAT/PS1 files (~20 KB)
├── scripts/               # 4 JS files (~15 KB)
├── package.json           # (~1 KB)
├── package-lock.json      # (~50 KB)
├── .env.example           # Template
├── README.md              # Deployment instructions
└── SETUP.md               # Quick start guide
```

**Total size (before npm install):** ~150 KB
**After npm install:** ~5-10 MB

---

## Updating Deployed Sync Engines

### When to Update

Update the deployment when:
- Bug fixes are applied to sync engines
- New features added to sync scripts
- Configuration changes needed

### How to Update

**Option A: Full Redeployment**
1. Create new deployment bundle
2. Stop scheduled tasks
3. Extract new bundle (overwrites old)
4. Restart scheduled tasks

**Option B: File-by-File Update**
1. Copy updated file(s) to server
2. Replace old file(s)
3. No restart needed (next sync uses new version)

**Example - Update reverse sync engine:**
```powershell
# On dev machine
Copy-Item "sync\production\reverse-sync-engine.js" "\\LOCAL-SERVER\C$\PowerCA-Sync\sync\production\"
```

---

## Maintenance

### Daily Checks

```cmd
# Check logs for errors
findstr /I "ERROR" C:\PowerCA-Sync\logs\*.log

# Verify record counts
node C:\PowerCA-Sync\scripts\verify-all-tables.js
```

### Weekly Checks

```cmd
# Check disk space
dir C:\PowerCA-Sync\logs

# Clean old logs (older than 30 days)
forfiles /p "C:\PowerCA-Sync\logs" /m *.log /d -30 /c "cmd /c del @path"
```

### Monthly Checks

```cmd
# Update Node.js dependencies
cd C:\PowerCA-Sync
npm update

# Backup .env file
copy .env .env.backup
```

---

## Backup Strategy

### What to Backup

**Critical:**
- ✅ `.env` file (credentials)
- ✅ `logs/` folder (last 30 days)
- ✅ Scheduled tasks configuration

**Optional:**
- Entire PowerCA-Sync folder (~10 MB)

### Backup Command

```powershell
# Create backup
$date = Get-Date -Format "yyyyMMdd"
Compress-Archive -Path "C:\PowerCA-Sync" -DestinationPath "C:\Backups\PowerCA-Sync-$date.zip"
```

---

## Troubleshooting

### Issue: "Module not found"

**Solution:**
```cmd
cd C:\PowerCA-Sync
npm install
```

### Issue: "Cannot connect to database"

**Solution:**
```cmd
# Check .env file exists and has correct credentials
type C:\PowerCA-Sync\.env

# Test connection
node scripts/test-scheduling-setup.js
```

### Issue: "Scheduled task not running"

**Solution:**
```cmd
# Check task status
schtasks /Query /TN PowerCA_ForwardSync_Full /V

# Check task history in Task Scheduler GUI
taskschd.msc
```

---

## Security Considerations

### Protect .env File

```cmd
# Set file permissions (Administrator only)
icacls "C:\PowerCA-Sync\.env" /inheritance:r /grant:r "%USERNAME%:F"
```

### Firewall Rules

**Outbound connections needed:**
- PostgreSQL Desktop: localhost:5433
- Supabase Cloud: db.jacqfogzgzvbjeizljqf.supabase.co:5432

**Inbound connections:** None required

---

## System Requirements

### Minimum

- **OS:** Windows 10/11 or Windows Server 2016+
- **RAM:** 2 GB available
- **Disk:** 1 GB free space
- **Network:** Stable internet connection
- **Node.js:** v14.x or higher

### Recommended

- **OS:** Windows 11 or Windows Server 2022
- **RAM:** 4 GB available
- **Disk:** 5 GB free space (for logs)
- **Network:** 10+ Mbps internet
- **Node.js:** v18.x LTS or v20.x LTS

---

## Comparison: Full Project vs Deployment

| Aspect | Full Project | Minimal Deployment |
|--------|--------------|-------------------|
| Size | ~500+ MB | ~5-10 MB |
| Files | ~5,000+ files | ~30 files |
| Folders | ~100+ folders | ~6 folders |
| Setup Time | 30+ minutes | 5 minutes |
| Maintenance | Complex | Simple |
| Updates | Git pull | File copy |
| **Recommended For** | Development | Production |

---

## Next Steps

1. **Create deployment bundle:**
   ```bash
   node deployment/create-deployment-bundle.js
   ```

2. **Transfer to server:**
   - USB drive, network share, or email

3. **Follow deployment steps** (Steps 3-9 above)

4. **Test and verify:**
   ```cmd
   batch-scripts\manual\sync-menu.bat
   ```

5. **Monitor logs:**
   ```cmd
   dir /b /o-d logs\*.log
   ```

---

**Document Version:** 1.0
**Date:** 2025-11-01
**Deployment Type:** Minimal (Production-Ready)
