# PowerCA Mobile - Sync Scheduling Quick Start

**Fast track guide to set up automated bidirectional sync scheduling.**

---

## TL;DR - Quick Setup (5 minutes)

### Option A: Windows Task Scheduler (Recommended)

```powershell
# 1. Open PowerShell as Administrator
# 2. Run setup script
cd "D:\PowerCA Mobile"
powershell -ExecutionPolicy Bypass -File scripts/setup-windows-scheduler.ps1

# 3. Verify tasks created
schtasks /Query /TN PowerCA* /FO LIST

# 4. Test a task
schtasks /Run /TN "PowerCA_ReverseSync_Hourly"

# 5. Check logs
dir /b /o-d logs\*.log
```

**Done!** Syncs will now run automatically:
- Full sync: Daily at 2:00 AM
- Incremental sync: 8 AM, 12 PM, 4 PM, 8 PM
- Reverse sync: Every hour

---

### Option B: Node.js Scheduler (Alternative)

```bash
# 1. Install dependencies
npm install node-cron

# 2. Test scheduler
node scripts/sync-scheduler.js

# 3. Install as Windows service (optional)
npm install -g node-windows
node scripts/install-sync-service.js

# 4. Start service
net start "PowerCA Mobile Sync Scheduler"
```

**Done!** Same schedule as Option A.

---

## Verify Setup

### Run Pre-Flight Check

```bash
node scripts/test-scheduling-setup.js
```

This checks:
- Node.js version
- Environment variables
- Database connections
- Metadata tables
- Batch scripts
- Logs directory
- Disk space

### Manual Test Syncs

```bash
# Test reverse sync (fast - usually < 1 minute)
node sync/production/reverse-sync-engine.js

# Test incremental sync (medium - usually 2-5 minutes)
node sync/production/runner-staging.js --mode=incremental

# Test full sync (slow - can take 30-60 minutes)
node sync/production/runner-staging.js --mode=full
```

---

## Monitor Syncs

### View Logs

```cmd
# List recent logs
dir /b /o-d logs\*.log | more

# View specific log
type logs\reverse-sync_20251101_120000.log

# Search for errors
findstr /I "ERROR" logs\*.log

# Tail logs in real-time (PowerShell)
Get-Content logs\reverse-sync.log -Wait -Tail 50
```

### Check Task Status

```cmd
# View all PowerCA tasks
schtasks /Query /TN PowerCA* /FO LIST

# View task history (GUI)
taskschd.msc
```

### Verify Sync Working

```bash
# Compare record counts between Desktop and Supabase
node scripts/verify-all-tables.js

# Check metadata timestamps
node scripts/test-reverse-sync-metadata.js
```

---

## Recommended Schedule

**What we've configured:**

| Sync Type | Frequency | Time | Duration | Purpose |
|-----------|-----------|------|----------|---------|
| Forward Full | Daily | 2:00 AM | 30-60 min | Complete data sync Desktop -> Supabase |
| Forward Incremental | 4x daily | 8 AM, 12 PM, 4 PM, 8 PM | 2-5 min | Changed records only |
| Reverse | Hourly | Every hour | < 1 min | Mobile data -> Desktop |

**Why this schedule:**
- Full sync at night (low usage, doesn't block users)
- Incremental during day (keeps mobile app fresh)
- Reverse hourly (mobile data flows back quickly)

---

## Customizing Schedule

### Change Times (Windows Task Scheduler)

```powershell
# Example: Change full sync to 3:00 AM
$task = Get-ScheduledTask -TaskName "PowerCA_ForwardSync_Full"
$trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
Set-ScheduledTask -TaskName "PowerCA_ForwardSync_Full" -Trigger $trigger
```

### Change Times (Node.js Scheduler)

Edit [scripts/sync-scheduler.js](scripts/sync-scheduler.js):

```javascript
// Full sync at 3:00 AM instead of 2:00 AM
cron.schedule('0 3 * * *', () => { ... });

// Incremental every 2 hours instead of 4
cron.schedule('0 */2 * * *', () => { ... });

// Reverse every 30 minutes instead of hourly
cron.schedule('*/30 * * * *', () => { ... });
```

---

## Troubleshooting

### Sync Not Running

**Check:**
1. PostgreSQL running? `psql -h localhost -p 5433 -U postgres -l`
2. Task enabled? `schtasks /Query /TN PowerCA_ForwardSync_Full`
3. Environment variables? `type .env`
4. Logs? `dir logs\*.log`

### Sync Failing

**Check logs for:**
- Network timeouts -> Increase `statement_timeout` in [sync/config.js](sync/config.js)
- Connection limits -> Increase `max` pool size in config
- Disk space -> Free up space (staging needs 2x table size)

**Emergency stop:**
```cmd
# Stop all syncs
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *sync*"

# Disable tasks
schtasks /Change /TN "PowerCA_ForwardSync_Full" /DISABLE
```

---

## Files Created

**Batch Scripts:**
- `scripts/schedule-forward-sync-full.bat` - Full sync wrapper
- `scripts/schedule-forward-sync-incremental.bat` - Incremental sync wrapper
- `scripts/schedule-reverse-sync.bat` - Reverse sync wrapper

**PowerShell Scripts:**
- `scripts/setup-windows-scheduler.ps1` - Task Scheduler setup

**Node.js Scripts:**
- `scripts/sync-scheduler.js` - Node.js scheduler (cron-based)
- `scripts/install-sync-service.js` - Windows service installer
- `scripts/uninstall-sync-service.js` - Windows service uninstaller
- `scripts/test-scheduling-setup.js` - Pre-flight check

**Documentation:**
- `docs/SYNC-SCHEDULING-GUIDE.md` - Complete scheduling guide
- `SYNC-SCHEDULING-QUICKSTART.md` - This file

---

## Complete Documentation

**For detailed information, see:**

- **[SYNC-SCHEDULING-GUIDE.md](docs/SYNC-SCHEDULING-GUIDE.md)** - Complete scheduling guide with all options
- **[CLAUDE.md](CLAUDE.md)** - Full project documentation
- **[sync/production/README.md](sync/production/README.md)** - Production sync guide

---

## Support Commands

```bash
# View sync status
tasklist | findstr node

# Check scheduled tasks
schtasks /Query /TN PowerCA*

# View recent logs
dir /b /o-d logs\*.log

# Test database connections
node scripts/test-scheduling-setup.js

# Compare record counts
node scripts/verify-all-tables.js

# Manual sync (testing)
node sync/production/reverse-sync-engine.js
```

---

**That's it!** Your automated sync is now configured and running.

**Questions?** Check [docs/SYNC-SCHEDULING-GUIDE.md](docs/SYNC-SCHEDULING-GUIDE.md) for detailed troubleshooting.

---

**Document Version:** 1.0
**Date:** 2025-11-01
**Quick Start Guide**
