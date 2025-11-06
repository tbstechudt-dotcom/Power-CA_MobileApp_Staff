# PowerCA Mobile - Sync Scheduling Guide

Complete guide for scheduling automated bidirectional sync between Desktop PostgreSQL and Supabase Cloud.

---

## Quick Reference

**Recommended Schedule:**
- Forward Sync (Full): Daily at 2:00 AM
- Forward Sync (Incremental): Every 4 hours (8 AM, 12 PM, 4 PM, 8 PM)
- Reverse Sync: Every hour

**Choose Your Method:**
1. **Windows Task Scheduler** (Recommended - most reliable)
2. **Node.js Scheduler** (Alternative - easier to customize)
3. **Manual Execution** (For testing only)

---

## Option 1: Windows Task Scheduler (Recommended)

### Advantages
- Built into Windows (no additional software)
- Runs even when user not logged in
- Highly reliable and battle-tested
- Easy to manage via GUI (taskschd.msc)
- Automatic retry on failure

### Setup Instructions

**Step 1: Run Setup Script**

Open PowerShell as Administrator and run:

```powershell
cd "D:\PowerCA Mobile"
powershell -ExecutionPolicy Bypass -File scripts/setup-windows-scheduler.ps1
```

**Step 2: Verify Tasks Created**

Open Task Scheduler:
```
Win + R -> taskschd.msc -> Enter
```

Look for these tasks:
- `PowerCA_ForwardSync_Full` - Daily at 2:00 AM
- `PowerCA_ForwardSync_Incremental` - 8 AM, 12 PM, 4 PM, 8 PM
- `PowerCA_ReverseSync_Hourly` - Every hour

**Step 3: Test Tasks Manually**

```cmd
# Test reverse sync
schtasks /Run /TN "PowerCA_ReverseSync_Hourly"

# Test incremental sync
schtasks /Run /TN "PowerCA_ForwardSync_Incremental"

# Test full sync
schtasks /Run /TN "PowerCA_ForwardSync_Full"
```

**Step 4: Check Logs**

Logs are saved to: `D:\PowerCA Mobile\logs\`

```cmd
# View latest reverse sync log
dir /b /o-d logs\reverse-sync_*.log | more

# View log contents
type logs\reverse-sync_20251101_120000.log
```

### Managing Tasks

**Enable/Disable Tasks:**
```cmd
# Disable a task
schtasks /Change /TN "PowerCA_ForwardSync_Full" /DISABLE

# Enable a task
schtasks /Change /TN "PowerCA_ForwardSync_Full" /ENABLE
```

**Delete Tasks:**
```cmd
schtasks /Delete /TN "PowerCA_ForwardSync_Full" /F
schtasks /Delete /TN "PowerCA_ForwardSync_Incremental" /F
schtasks /Delete /TN "PowerCA_ReverseSync_Hourly" /F
```

**View Task History:**
```
1. Open Task Scheduler (taskschd.msc)
2. Select task
3. Click "History" tab at bottom
4. Review execution logs
```

---

## Option 2: Node.js Scheduler (Alternative)

### Advantages
- Cross-platform (Windows, Linux, Mac)
- Easier to customize schedules
- Single process manages all syncs
- Built-in health check endpoint
- Easy to debug with console logs

### Disadvantages
- Requires Node.js process to stay running
- Stops if user logs out (unless run as service)
- More complex to set up as Windows service

### Setup Instructions

**Step 1: Install Dependencies**

```bash
cd "D:\PowerCA Mobile"
npm install node-cron
```

**Step 2: Run Scheduler**

```bash
# Run in foreground (testing)
node scripts/sync-scheduler.js

# Run in background (Windows)
start /B node scripts/sync-scheduler.js > logs/scheduler.log 2>&1
```

**Step 3: Verify Scheduler Running**

Open browser: http://localhost:3001/health

Should return:
```json
{
  "status": "running",
  "uptime": 3600,
  "timestamp": "2025-11-01T12:00:00.000Z"
}
```

### Run as Windows Service (Recommended)

**Step 1: Install node-windows**

```bash
npm install -g node-windows
```

**Step 2: Install Service**

```bash
node scripts/install-sync-service.js
```

**Step 3: Start Service**

```cmd
# Via command line
net start "PowerCA Mobile Sync Scheduler"

# Or via Services GUI
Win + R -> services.msc -> Find "PowerCA Mobile Sync Scheduler" -> Start
```

**Step 4: Verify Service Running**

```cmd
sc query "PowerCA Mobile Sync Scheduler"
```

Should show `STATE: RUNNING`

### Uninstall Service

```bash
node scripts/uninstall-sync-service.js
```

---

## Option 3: Manual Execution (Testing Only)

For testing or one-off syncs:

**Forward Sync (Full):**
```bash
node sync/production/runner-staging.js --mode=full
```

**Forward Sync (Incremental):**
```bash
node sync/production/runner-staging.js --mode=incremental
```

**Reverse Sync:**
```bash
node sync/production/reverse-sync-engine.js
```

---

## Monitoring & Troubleshooting

### Check Sync Logs

**View Recent Logs:**
```cmd
# List all logs by date
dir /b /o-d logs\*.log

# View latest forward sync log
type logs\forward-sync-full_*.log | more

# Search for errors
findstr /I "ERROR" logs\*.log
```

**Tail Logs (Real-time):**
```powershell
# PowerShell equivalent of tail -f
Get-Content logs\scheduler.log -Wait -Tail 50
```

### Common Issues

**Issue 1: Task Doesn't Run**

Check:
1. PostgreSQL desktop database is running (port 5433)
2. `.env` file exists with correct credentials
3. Task is enabled in Task Scheduler
4. User has permissions to run batch files

**Issue 2: Sync Fails Midway**

Check logs for:
- Network timeouts (increase `statement_timeout` in config)
- Database connection limits (increase `max` pool size)
- Disk space (staging tables need 2x table size)

**Issue 3: Reverse Sync Skips Records**

Verify:
1. `_reverse_sync_metadata` table exists in desktop DB
2. Watermark timestamps are recent
3. No errors in reverse sync logs

### Health Checks

**Verify Metadata Tables:**

Desktop PostgreSQL:
```sql
-- Check reverse sync metadata
SELECT table_name, last_sync_timestamp
FROM _reverse_sync_metadata
ORDER BY last_sync_timestamp DESC;
```

Supabase Cloud:
```sql
-- Check forward sync metadata
SELECT table_name, last_sync_timestamp
FROM _sync_metadata
ORDER BY last_sync_timestamp DESC;
```

**Compare Record Counts:**

```bash
node scripts/verify-all-tables.js
```

---

## Customizing Schedules

### Modify Windows Task Scheduler Times

```powershell
# Change forward sync to run at 3:00 AM instead of 2:00 AM
$task = Get-ScheduledTask -TaskName "PowerCA_ForwardSync_Full"
$trigger = New-ScheduledTaskTrigger -Daily -At 3:00AM
Set-ScheduledTask -TaskName "PowerCA_ForwardSync_Full" -Trigger $trigger
```

### Modify Node.js Scheduler Times

Edit [scripts/sync-scheduler.js](../scripts/sync-scheduler.js):

```javascript
// Change full sync to 3:00 AM
cron.schedule('0 3 * * *', () => {
  runSync('node sync/production/runner-staging.js --mode=full', 'forward-sync-full');
});

// Change incremental to every 2 hours
cron.schedule('0 */2 * * *', () => {
  runSync('node sync/production/runner-staging.js --mode=incremental', 'forward-sync-incremental');
});

// Change reverse sync to every 30 minutes
cron.schedule('*/30 * * * *', () => {
  runSync('node sync/production/reverse-sync-engine.js', 'reverse-sync');
});
```

**Cron Syntax Reference:**
```
*    *    *    *    *
┬    ┬    ┬    ┬    ┬
│    │    │    │    │
│    │    │    │    └─── Day of week (0-7, 0 or 7 = Sunday)
│    │    │    └──────── Month (1-12)
│    │    └───────────── Day of month (1-31)
│    └────────────────── Hour (0-23)
└─────────────────────── Minute (0-59)
```

**Examples:**
- `0 2 * * *` - Every day at 2:00 AM
- `0 */4 * * *` - Every 4 hours
- `*/30 * * * *` - Every 30 minutes
- `0 8,12,16,20 * * *` - At 8 AM, 12 PM, 4 PM, 8 PM
- `0 9 * * 1-5` - Every weekday at 9 AM

---

## Email Notifications (Optional)

### Setup Email Alerts on Failure

Create [scripts/send-error-notification.ps1](../scripts/send-error-notification.ps1):

```powershell
param(
    [string]$LogFile
)

$SmtpServer = "smtp.gmail.com"
$SmtpPort = 587
$EmailFrom = "powerca-sync@yourdomain.com"
$EmailTo = "admin@yourdomain.com"
$Subject = "PowerCA Sync Failed - Action Required"

$Body = @"
PowerCA Mobile Sync Failed

Time: $(Get-Date)
Log File: $LogFile

Last 50 lines of log:
$(Get-Content $LogFile -Tail 50 | Out-String)

Please check the log file for details.
"@

$Credential = Get-Credential

Send-MailMessage -From $EmailFrom -To $EmailTo -Subject $Subject -Body $Body -SmtpServer $SmtpServer -Port $SmtpPort -UseSsl -Credential $Credential
```

Uncomment notification lines in batch scripts:
```batch
REM powershell -File scripts/send-error-notification.ps1 -LogFile "%LOGFILE%"
```

---

## Best Practices

### Do's
- ✅ Run full sync at least once daily (preferably at night)
- ✅ Run reverse sync frequently (hourly) to keep desktop updated
- ✅ Monitor logs regularly for errors
- ✅ Keep logs for at least 30 days
- ✅ Test sync schedules in dev environment first
- ✅ Set up email notifications for failures
- ✅ Verify metadata timestamps are recent

### Don'ts
- ❌ Don't run full sync during business hours (slow)
- ❌ Don't disable reverse sync for extended periods
- ❌ Don't ignore error logs
- ❌ Don't run multiple full syncs simultaneously
- ❌ Don't forget to check disk space before full sync

---

## Pre-Production Checklist

Before enabling scheduled syncs in production:

- [ ] PostgreSQL desktop database running on port 5433
- [ ] `.env` file configured with correct credentials
- [ ] `_sync_metadata` table created in Supabase
- [ ] `_reverse_sync_metadata` table created in Desktop
- [ ] Test full sync completes successfully
- [ ] Test incremental sync completes successfully
- [ ] Test reverse sync completes successfully
- [ ] Logs directory exists: `D:\PowerCA Mobile\logs\`
- [ ] Email notifications configured (optional)
- [ ] Backup of both databases created
- [ ] Disk space verified (staging needs 2x table size)

---

## Support

**View Sync Status:**
```bash
# Check running syncs
tasklist | findstr node

# Check scheduled tasks
schtasks /Query /TN PowerCA* /FO LIST
```

**Emergency Stop:**
```cmd
# Stop all sync processes
taskkill /F /IM node.exe /FI "WINDOWTITLE eq *sync*"

# Stop Windows service
net stop "PowerCA Mobile Sync Scheduler"
```

**Documentation:**
- [CLAUDE.md](../CLAUDE.md) - Complete project guide
- [sync/production/README.md](../sync/production/README.md) - Production sync guide
- [docs/BIDIRECTIONAL-SYNC-STRATEGY.md](BIDIRECTIONAL-SYNC-STRATEGY.md) - Sync architecture

---

**Document Version:** 1.0
**Date:** 2025-11-01
**Author:** Claude Code (AI)
**Purpose:** Complete guide for scheduling automated sync operations
