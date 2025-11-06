# PowerCA Mobile - Deployment Package

**Minimal sync engine deployment for local servers**

---

## Recommendation

✅ **USE DEPLOYMENT BUNDLE** (~5-10 MB)
❌ **DON'T deploy full project** (~500+ MB)

The deployment bundle contains only what's needed for sync operations on the local server (Desktop PostgreSQL machine).

---

## Quick Start

### Step 1: Create Deployment Bundle

On your **development machine**:

```bash
cd "D:\PowerCA Mobile"
node deployment\create-deployment-bundle.js
```

Output: `PowerCA-Sync-Deploy.zip` (~5-10 MB)

###  Step 2: Transfer to Server

Copy `PowerCA-Sync-Deploy.zip` to the local server via:
- USB drive
- Network share
- Email (if < 10 MB)
- Remote desktop

### Step 3: Deploy on Server

Extract to `C:\PowerCA-Sync\` (or any location)

### Step 4: Follow Setup Instructions

See `README.md` and `SETUP.md` inside the ZIP file.

---

## What's Included

**Sync Engines** (4 files, ~50 KB):
- sync/production/runner-staging.js
- sync/production/engine-staging.js
- sync/production/reverse-sync-engine.js
- sync/production/config.js

**Batch Scripts** (8 files, ~20 KB):
- Manual: sync-menu.bat, sync-full.bat, sync-incremental.bat, sync-reverse.bat
- Automated: forward-sync-full.bat, forward-sync-incremental.bat, reverse-sync.bat, setup-windows-scheduler.ps1

**Support Scripts** (4 files, ~15 KB):
- create-sync-metadata-table.js
- create-reverse-sync-metadata-table.js
- verify-all-tables.js
- test-scheduling-setup.js

**Configuration**:
- package.json (dependencies: pg, dotenv)
- .env.example (credentials template)
- README.md + SETUP.md (documentation)

**Total:** ~30 files, ~5-10 MB (after npm install)

---

## What's NOT Included (Space Saved!)

The following are excluded from deployment:

❌ Flutter app code (lib/, android/, ios/) - ~100 MB
❌ Documentation (docs/) - ~5 MB
❌ Development scripts (sync/development/) - ~500 KB
❌ Git repository (.git/) - ~50 MB
❌ Build artifacts (build/) - ~200 MB
❌ Development node_modules - ~150 MB

**Space saved:** ~545 MB!

---

## Key Features

**Relative Paths:**
- All batch files use relative paths
- Works from any installation location
- No hardcoded "D:\PowerCA Mobile" paths

**Minimal Dependencies:**
- Only `pg` and `dotenv` packages
- Fast `npm install` (~10 seconds)

**Production-Ready:**
- Uses production sync scripts only
- All 11 critical fixes included
- Safe for production deployment

---

## Deployment Workflow

```
Development Machine          Local Server
─────────────────────       ─────────────────────

1. Run deployment script
   node deployment/create-deployment-bundle.js

2. Creates ZIP (~5-10 MB)
   PowerCA-Sync-Deploy.zip

3. Transfer ──────────────>  PowerCA-Sync-Deploy.zip

                             4. Extract to C:\PowerCA-Sync\

                             5. npm install

                             6. Create .env file

                             7. Setup scheduled tasks

                             8. Test syncs

                             9. ✅ Production ready!
```

---

## Files

- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Complete deployment guide
- **[DEPLOYMENT-QUICK-START.txt](DEPLOYMENT-QUICK-START.txt)** - Quick reference (ASCII)
- **[create-deployment-bundle.js](create-deployment-bundle.js)** - Automated packaging script

---

## Support

For detailed instructions, see:
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Full deployment documentation
- [DEPLOYMENT-QUICK-START.txt](DEPLOYMENT-QUICK-START.txt) - Quick reference

---

**Document Version:** 1.0
**Date:** 2025-11-01
**Package Size:** ~5-10 MB (vs ~500+ MB full project)
