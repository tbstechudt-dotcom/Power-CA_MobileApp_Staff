# PowerCA Mobile - Batch Scripts

Organized batch scripts for sync operations.

---

## Folder Structure

```
batch-scripts/
├── manual/                    # Interactive scripts (double-click to run)
│   ├── sync-menu.bat         # Interactive menu to choose sync type
│   ├── sync-full.bat         # Manual full sync
│   ├── sync-incremental.bat  # Manual incremental sync
│   └── sync-reverse.bat      # Manual reverse sync
│
└── automated/                 # Scheduled scripts (for Task Scheduler)
    ├── forward-sync-full.bat          # Automated full sync (logs to file)
    ├── forward-sync-incremental.bat   # Automated incremental sync
    ├── reverse-sync.bat               # Automated reverse sync
    └── setup-windows-scheduler.ps1    # One-time Task Scheduler setup
```

---

## Manual Scripts (Interactive)

**Location:** `batch-scripts/manual/`

**Purpose:** For manual testing, ad-hoc syncs, and learning

**Features:**
- Interactive console output
- Waits for user (press any key to continue)
- Nice formatted headers
- Error validation

**How to Use:**

### Option 1: Interactive Menu (Recommended)
```cmd
batch-scripts\manual\sync-menu.bat
```

Provides a menu:
```
[1] Full Forward Sync
[2] Incremental Forward Sync
[3] Reverse Sync
[0] Exit
```

### Option 2: Run Individual Scripts
```cmd
# Manual full sync (Desktop -> Supabase)
batch-scripts\manual\sync-full.bat

# Manual incremental sync
batch-scripts\manual\sync-incremental.bat

# Manual reverse sync (Supabase -> Desktop)
batch-scripts\manual\sync-reverse.bat
```

**When to Use:**
- Testing after code changes
- One-off data syncs
- Troubleshooting sync issues
- Learning how syncs work

---

## Automated Scripts (Scheduled)

**Location:** `batch-scripts/automated/`

**Purpose:** For Windows Task Scheduler automation

**Features:**
- No user interaction (runs unattended)
- Timestamped log files (logs/ directory)
- Exit codes for Task Scheduler monitoring
- Runs when user not logged in

**Schedule (Office Hours):**

| Task | Time | Frequency | Duration |
|------|------|-----------|----------|
| Forward Full Sync | 10:00 AM | Daily | ~2-5 minutes |
| Forward Incremental | 12:00 PM | Daily | ~30-60 seconds |
| Forward Incremental | 5:00 PM | Daily | ~30-60 seconds |
| Reverse Sync | 5:30 PM | Daily | ~1-2 minutes |

**Note:** System must be ON and running for scheduled tasks to execute.

---

## Setup Windows Task Scheduler

### One-Time Setup

**Step 1:** Open PowerShell as Administrator

**Step 2:** Run setup script
```powershell
cd "D:\PowerCA Mobile"
powershell -ExecutionPolicy Bypass -File batch-scripts\automated\setup-windows-scheduler.ps1
```

**Step 3:** Verify tasks created
```cmd
schtasks /Query /TN PowerCA* /FO LIST
```

You should see:
- `PowerCA_ForwardSync_Full`
- `PowerCA_ForwardSync_Incremental`
- `PowerCA_ReverseSync_Daily`

**Step 4:** Test a task manually
```cmd
schtasks /Run /TN "PowerCA_ReverseSync_Daily"
```

**Step 5:** Check logs
```cmd
dir /b /o-d logs\*.log
type logs\reverse-sync_*.log
```

---

## Viewing Task Scheduler GUI

```
Win + R
taskschd.msc
Enter
```

Look for tasks starting with "PowerCA_"

---

## Monitoring Logs

All automated syncs write to: `D:\PowerCA Mobile\logs\`

**Log File Format:**
```
forward-sync-full_20251101_100000.log
forward-sync-incremental_20251101_120000.log
reverse-sync_20251101_173000.log
```

**View Recent Logs:**
```cmd
cd "D:\PowerCA Mobile"

# List all logs by date
dir /b /o-d logs\*.log

# View specific log
type logs\forward-sync-full_20251101_100000.log

# Search for errors
findstr /I "ERROR" logs\*.log

# Tail logs in real-time (PowerShell)
Get-Content logs\reverse-sync.log -Wait -Tail 50
```

---

## Managing Scheduled Tasks

### Disable a Task
```cmd
schtasks /Change /TN "PowerCA_ForwardSync_Full" /DISABLE
```

### Enable a Task
```cmd
schtasks /Change /TN "PowerCA_ForwardSync_Full" /ENABLE
```

### Delete All Tasks
```cmd
schtasks /Delete /TN "PowerCA_ForwardSync_Full" /F
schtasks /Delete /TN "PowerCA_ForwardSync_Incremental" /F
schtasks /Delete /TN "PowerCA_ReverseSync_Daily" /F
```

### Change Schedule Time

**Example: Change full sync to 9:00 AM**
```powershell
$task = Get-ScheduledTask -TaskName "PowerCA_ForwardSync_Full"
$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
Set-ScheduledTask -TaskName "PowerCA_ForwardSync_Full" -Trigger $trigger
```

---

## Troubleshooting

### Task Not Running

**Check:**
1. System is ON at scheduled time
2. Task is enabled: `schtasks /Query /TN PowerCA_ForwardSync_Full`
3. PostgreSQL desktop database is running
4. Environment variables configured in `.env`

**View Task History:**
1. Open Task Scheduler (taskschd.msc)
2. Select PowerCA task
3. Click "History" tab
4. Review execution logs

### Sync Failing

**Check logs:**
```cmd
# View latest log
dir /b /o-d logs\*.log | more
type logs\[latest-log-file].log

# Search for errors
findstr /I "ERROR" logs\*.log
```

**Common Issues:**
- Network timeout → Increase `statement_timeout` in sync/config.js
- Connection refused → Check PostgreSQL is running on port 5433
- Disk space → Free up space (staging needs 2x table size)

---

## Quick Reference

### Manual Sync (Testing)
```cmd
batch-scripts\manual\sync-menu.bat
```

### Setup Automation (One-Time)
```powershell
powershell -ExecutionPolicy Bypass -File batch-scripts\automated\setup-windows-scheduler.ps1
```

### View Scheduled Tasks
```cmd
schtasks /Query /TN PowerCA*
```

### Check Logs
```cmd
dir /b /o-d logs\*.log
```

### Test Task Manually
```cmd
schtasks /Run /TN "PowerCA_ReverseSync_Daily"
```

---

## Daily Schedule Timeline

```
9:30 AM  - System powered on (employees arrive)
10:00 AM - Forward Full Sync runs (~2-5 minutes)
12:00 PM - Forward Incremental Sync runs (~30-60 seconds)
5:00 PM  - Forward Incremental Sync runs (~30-60 seconds)
5:30 PM  - Reverse Sync runs (~1-2 minutes)
```

**Total daily sync time:** ~6-9 minutes across 4 syncs

---

## Support

**Documentation:**
- [SYNC-SCHEDULING-GUIDE.md](../docs/SYNC-SCHEDULING-GUIDE.md) - Complete guide
- [CLAUDE.md](../CLAUDE.md) - Full project documentation
- [sync/production/README.md](../sync/production/README.md) - Production sync guide

**Test Scripts:**
```bash
# Pre-flight check
node scripts/test-scheduling-setup.js

# Verify record counts
node scripts/verify-all-tables.js
```

---

**Document Version:** 1.0
**Date:** 2025-11-01
**Custom Schedule:** Office Hours (10 AM - 5:30 PM)
