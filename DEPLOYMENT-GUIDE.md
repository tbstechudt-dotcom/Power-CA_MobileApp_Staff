# PowerCA Mobile - Client Deployment Guide

## Overview

This guide explains how to deploy the PowerCA Mobile sync service at a client's site. The sync service runs as a **Windows Service** on the client's network and automatically synchronizes their Desktop PostgreSQL database with Supabase Cloud.

---

## Architecture

```
Client's Network:                         Internet:                    Cloud:
+---------------------+                                    +----------------------+
|  Desktop PC         |                                    |  Supabase Cloud      |
|  - PostgreSQL DB    |                                    |  - PostgreSQL        |
|  - Port 5433        |                                    |  - Auth & Storage    |
+---------------------+                                    +----------+-----------+
         ^                                                             |
         |                                                             |
         | Local Network                                               |
         |                                                             |
+--------+------------+                                                |
|  Sync Service PC    |------------------------------------------------+
|  - Windows Service  |               HTTPS (Outbound Only)
|  - Node.js Runtime  |
|  - Auto Sync        |
+---------------------+
```

**Key Points:**
- [OK] **No inbound connections** - Client's firewall stays closed
- [OK] **Secure** - Sync service initiates all connections (HTTPS to Supabase)
- [OK] **Automatic** - Runs 24/7 as Windows Service
- [OK] **Multi-tenant** - One Supabase instance serves all mobile users

---

## Prerequisites

### Client Requirements:

1. **Windows PC for Sync Service:**
   - Windows 10/11 or Windows Server 2016+
   - 2GB RAM minimum, 4GB recommended
   - 10GB free disk space
   - Network access to Desktop PostgreSQL (can be same PC)
   - Internet access (outbound HTTPS to Supabase)

2. **Desktop PostgreSQL:**
   - PostgreSQL 9.6+ (currently using 16.9)
   - Accessible on port 5433 (or custom port)
   - `enterprise_db` database

3. **Network:**
   - Sync PC can connect to Desktop PostgreSQL
   - Sync PC has internet access (HTTPS port 443)

### Software Requirements (Included in Package):

- Node.js 18+ (will guide installation)
- NPM packages (included in deployment package)

---

## Step-by-Step Deployment

### Step 1: Prepare Deployment Package

Create deployment folder on your development machine:

```bash
cd "d:\PowerCA Mobile"

# Create deployment package directory
mkdir PowerCA-Sync-Installer

# Copy required files
xcopy /E /I sync PowerCA-Sync-Installer\sync
xcopy /E /I node_modules PowerCA-Sync-Installer\node_modules
copy package.json PowerCA-Sync-Installer\
copy package-lock.json PowerCA-Sync-Installer\
copy .env PowerCA-Sync-Installer\.env.template
```

### Step 2: Configure for Client

Edit `PowerCA-Sync-Installer\.env.template` and save as `.env`:

```env
# ============================================
# PowerCA Sync Service Configuration
# ============================================

# CLIENT'S DESKTOP DATABASE (Fill this in)
# -----------------------------------------
DESKTOP_DB_HOST=localhost
DESKTOP_DB_PORT=5433
DESKTOP_DB_NAME=enterprise_db
DESKTOP_DB_USER=postgres
DESKTOP_DB_PASSWORD=___FILL_THIS_IN___

# SUPABASE CLOUD (Pre-configured by PowerCA)
# -------------------------------------------
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=Powerca@2025

# DO NOT MODIFY BELOW
SUPABASE_URL=https://jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

Edit `PowerCA-Sync-Installer\sync\scheduler\clients-config.js`:

```javascript
module.exports = {
  clients: [
    {
      id: 1,
      name: 'ClientName Here',  // <- Change this
      org_id: 1,                // <- Change this to client's org_id
      enabled: true,
      schedule: {
        incremental: '0 2 * * *',  // Daily at 2:00 AM
        full: '0 3 * * 0'          // Sunday at 3:00 AM
      }
    }
    // Remove other clients or set enabled: false
  ],

  settings: {
    autoSyncEnabled: true,
    retryOnFailure: true,
    maxRetries: 3,
    emailNotifications: {
      enabled: false  // Enable later if client wants alerts
    }
  }
};
```

### Step 3: Create Installation Instructions

Create `PowerCA-Sync-Installer\INSTALL.txt`:

```txt
+===============================================================+
|      PowerCA Mobile - Sync Service Installation              |
+===============================================================+

IMPORTANT: Read all steps before proceeding.

---------------------------------------------------------------
STEP 1: Install Node.js (If not already installed)
---------------------------------------------------------------

1. Download Node.js 18 LTS from: https://nodejs.org/
   Direct link: https://nodejs.org/dist/v18.20.0/node-v18.20.0-x64.msi

2. Run installer with default settings

3. Verify installation:
   - Open Command Prompt
   - Run: node --version
   - Should show: v18.x.x

---------------------------------------------------------------
STEP 2: Copy Files to Installation Directory
---------------------------------------------------------------

1. Copy this entire folder to: C:\PowerCA-Sync\

2. Verify folder structure:
   C:\PowerCA-Sync\
   +- sync\
   +- node_modules\
   +- .env
   +- package.json

---------------------------------------------------------------
STEP 3: Configure Database Connection
---------------------------------------------------------------

1. Open: C:\PowerCA-Sync\.env

2. Fill in your PostgreSQL password:
   DESKTOP_DB_PASSWORD=your_postgres_password

3. Verify Desktop DB connection:
   - DESKTOP_DB_HOST=localhost (change if DB is on another PC)
   - DESKTOP_DB_PORT=5433 (default)

4. Save and close

---------------------------------------------------------------
STEP 4: Test Sync (Before Installing Service)
---------------------------------------------------------------

1. Open Command Prompt

2. Navigate to installation:
   cd C:\PowerCA-Sync

3. Run test sync:
   node sync\full-sync.js --mode=incremental

4. Should see:
   [OK] Connected to Desktop PostgreSQL
   [OK] Connected to Supabase Cloud
   [OK] Syncing tables...

5. If errors, check:
   - Desktop PostgreSQL is running
   - Password in .env is correct
   - Internet connection is working

---------------------------------------------------------------
STEP 5: Install Windows Service
---------------------------------------------------------------

1. Open Command Prompt AS ADMINISTRATOR:
   - Press Windows key
   - Type "cmd"
   - Right-click "Command Prompt"
   - Select "Run as administrator"

2. Navigate to scheduler:
   cd C:\PowerCA-Sync\sync\scheduler

3. Run installer batch file:
   install-service.bat

4. Select option 1 (Install service)

5. Configure auto-start:
   sc config "PowerCA Sync Scheduler" start=auto

6. Start the service:
   (In install-service.bat, select option 3: Start service)

---------------------------------------------------------------
STEP 6: Verify Service is Running
---------------------------------------------------------------

1. Open Services (services.msc):
   - Press Windows + R
   - Type: services.msc
   - Press Enter

2. Find "PowerCA Sync Scheduler"

3. Verify:
   - Status: Running
   - Startup Type: Automatic

4. Check logs:
   - Open: C:\PowerCA-Sync\sync\scheduler\logs\combined.log
   - Should see: "Scheduler is now running"

---------------------------------------------------------------
STEP 7: Sync Schedule (Automatic)
---------------------------------------------------------------

The service will automatically sync:
- DAILY: Incremental sync at 2:00 AM
- WEEKLY: Full sync on Sunday at 3:00 AM

No manual intervention required!

---------------------------------------------------------------
TROUBLESHOOTING
---------------------------------------------------------------

Problem: Service won't start
Solution:
  1. Check logs: C:\PowerCA-Sync\sync\scheduler\logs\error.log
  2. Verify Node.js installed: node --version
  3. Test sync manually (Step 4)
  4. Reinstall service (uninstall, then install)

Problem: Sync fails
Solution:
  1. Check Desktop PostgreSQL is running
  2. Verify .env password is correct
  3. Test internet connection to Supabase
  4. Check logs for detailed error

Problem: Need to change sync schedule
Solution:
  1. Edit: C:\PowerCA-Sync\sync\scheduler\clients-config.js
  2. Restart service via install-service.bat (option 5)

---------------------------------------------------------------
SUPPORT
---------------------------------------------------------------

Contact: support@powerca.com
Website: https://powerca.com/support

---------------------------------------------------------------
```

### Step 4: Package and Send to Client

```bash
# Zip the deployment package
cd d:\
Compress-Archive -Path "PowerCA Mobile\PowerCA-Sync-Installer" -DestinationPath "PowerCA-Sync-Installer.zip"

# Send to client via:
# - Email (if < 25MB)
# - Google Drive / Dropbox link
# - USB drive
```

---

## Post-Installation Verification

### 1. Check Service Status:

```bash
sc query "PowerCA Sync Scheduler"
# Should show: STATE: RUNNING
```

### 2. Check Logs:

```bash
type C:\PowerCA-Sync\sync\scheduler\logs\combined.log
# Should show: "Scheduler is now running"
```

### 3. Verify Data Sync:

```bash
# Trigger manual sync
cd C:\PowerCA-Sync
node sync\full-sync.js --mode=incremental

# Check Supabase dashboard
# - Table record counts should match Desktop DB
```

---

## Monitoring & Maintenance

### View Logs:

```bash
# All logs
type C:\PowerCA-Sync\sync\scheduler\logs\combined.log

# Errors only
type C:\PowerCA-Sync\sync\scheduler\logs\error.log

# Live tail (PowerShell)
Get-Content C:\PowerCA-Sync\sync\scheduler\logs\combined.log -Wait -Tail 50
```

### Service Management:

```bash
# Check status
sc query "PowerCA Sync Scheduler"

# Start/Stop/Restart
net start "PowerCA Sync Scheduler"
net stop "PowerCA Sync Scheduler"

# Or use install-service.bat menu
```

### Email Notifications (Optional):

Enable in `clients-config.js`:

```javascript
emailNotifications: {
  enabled: true,
  onFailure: true,      // Email when sync fails
  recipients: ['admin@client.com']
},

email: {
  service: 'gmail',
  auth: {
    user: 'client@gmail.com',
    pass: 'gmail_app_password'  // Use Gmail App Password
  }
}
```

---

## Security Checklist

- [X] No inbound firewall rules needed
- [X] Outbound HTTPS only (encrypted)
- [ ] .env file has restrictive permissions
- [ ] Supabase password is strong and unique
- [ ] Service runs with minimal privileges
- [ ] Logs reviewed regularly
- [ ] Backup Supabase database regularly

---

## Troubleshooting

### Service Won't Start:

1. Check Node.js: `node --version`
2. Test sync manually: `node sync\full-sync.js --mode=incremental`
3. Check Event Viewer: `eventvwr.msc` -> Application logs
4. Reinstall service via `install-service.bat`

### Sync Failures:

1. Test Desktop DB: `psql -h localhost -p 5433 -U postgres -d enterprise_db`
2. Test Supabase: Check internet connection
3. Review logs: `sync\scheduler\logs\error.log`

### Performance Issues:

1. Increase timeout in `clients-config.js`:
   ```javascript
   syncTimeout: 1200000  // 20 minutes
   ```
2. Restart service
3. Consider off-peak sync times

---

## Additional Resources

- [Sync Engine Documentation](docs/SYNC-ENGINE-ETL-GUIDE.md)
- [CLAUDE.md - Critical Issues](CLAUDE.md)
- [Scheduler README](sync/scheduler/README.md)

---

## Deployment Checklist

### Pre-Deployment:
- [ ] Node.js 18+ available
- [ ] Deployment package created
- [ ] Client's org_id configured
- [ ] .env has Supabase credentials
- [ ] INSTALL.txt included

### Installation:
- [ ] Files copied to C:\PowerCA-Sync\
- [ ] .env configured with Desktop DB password
- [ ] Test sync successful
- [ ] Service installed
- [ ] Service set to auto-start
- [ ] Service running

### Post-Installation:
- [ ] Service status verified
- [ ] Logs show successful sync
- [ ] Data in Supabase verified
- [ ] Schedule confirmed
- [ ] Client has support contact

---

**Version:** 1.0
**Last Updated:** 2025-11-28
**Support:** support@powerca.com
