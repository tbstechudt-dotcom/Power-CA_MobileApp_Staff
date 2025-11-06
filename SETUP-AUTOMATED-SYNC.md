# PowerCA Mobile - Setup Automated Sync

**Quick setup guide for automated sync scheduling (Office Hours)**

---

## Your Custom Schedule

| Sync Type | Time | Purpose |
|-----------|------|---------|
| **Forward Full** | 10:00 AM | Complete data sync (Desktop → Supabase) |
| **Forward Incremental** | 12:00 PM | Changed records only |
| **Forward Incremental** | 5:00 PM | Changed records only |
| **Reverse Sync** | 5:30 PM | Mobile data back to Desktop |

**Total:** 4 automated syncs per day

**Note:** System must be ON and running at these times.

---

## Quick Setup (5 minutes)

### Step 1: Open PowerShell as Administrator

Right-click PowerShell → "Run as Administrator"

### Step 2: Run Setup Script

```powershell
cd "D:\PowerCA Mobile"
powershell -ExecutionPolicy Bypass -File batch-scripts\automated\setup-windows-scheduler.ps1
```

### Step 3: Verify Tasks Created

```cmd
schtasks /Query /TN PowerCA* /FO LIST
```

You should see 3 tasks:
- PowerCA_ForwardSync_Full
- PowerCA_ForwardSync_Incremental
- PowerCA_ReverseSync_Daily

### Step 4: Test Manually (Optional)

```cmd
# Test reverse sync (fastest - about 1-2 minutes)
schtasks /Run /TN "PowerCA_ReverseSync_Daily"

# Check log file
dir /b /o-d logs\*.log
type logs\reverse-sync_*.log
```

---

## That's It!

Your syncs are now automated and will run daily at:
- 10:00 AM - Full sync
- 12:00 PM - Incremental
- 5:00 PM - Incremental
- 5:30 PM - Reverse sync

---

## Folder Structure

```
D:\PowerCA Mobile\
├── batch-scripts/
│   ├── manual/                          # For testing/manual use
│   │   ├── sync-menu.bat               # Interactive menu
│   │   ├── sync-full.bat               # Manual full sync
│   │   ├── sync-incremental.bat        # Manual incremental
│   │   └── sync-reverse.bat            # Manual reverse
│   │
│   ├── automated/                       # For Task Scheduler
│   │   ├── forward-sync-full.bat       # Automated full sync
│   │   ├── forward-sync-incremental.bat # Automated incremental
│   │   ├── reverse-sync.bat            # Automated reverse
│   │   └── setup-windows-scheduler.ps1 # Setup script
│   │
│   └── README.md                        # Complete documentation
│
└── logs/                                # Sync logs (auto-created)
    ├── forward-sync-full_*.log
    ├── forward-sync-incremental_*.log
    └── reverse-sync_*.log
```

---

## Manual Testing (Before Automation)

Use the **interactive menu** for testing:

```cmd
batch-scripts\manual\sync-menu.bat
```

This gives you a menu to choose:
1. Full Forward Sync
2. Incremental Forward Sync
3. Reverse Sync
0. Exit

---

## Monitoring

### View Logs

```cmd
# List recent logs
dir /b /o-d logs\*.log

# View specific log
type logs\forward-sync-full_20251101_100000.log

# Search for errors
findstr /I "ERROR" logs\*.log
```

### Check Task Status

```cmd
# View tasks
schtasks /Query /TN PowerCA*

# Or open Task Scheduler GUI
taskschd.msc
```

### Verify Sync Working

```bash
# Compare record counts (Desktop vs Supabase)
node scripts\verify-all-tables.js
```

---

## Daily Timeline

```
9:30 AM  ┌─ System powered ON (employees arrive)
         │
10:00 AM ├─ Forward Full Sync runs (~2-5 minutes)
         │  Desktop → Supabase (all records)
         │
12:00 PM ├─ Forward Incremental Sync (~30-60 seconds)
         │  Desktop → Supabase (changed records only)
         │
5:00 PM  ├─ Forward Incremental Sync (~30-60 seconds)
         │  Desktop → Supabase (changed records only)
         │
5:30 PM  ├─ Reverse Sync runs (~1-2 minutes)
         │  Supabase → Desktop (mobile data)
         │
6:00 PM  └─ All syncs complete
```

**Total sync time:** ~6-9 minutes per day

---

## Managing Tasks

### Disable/Enable

```cmd
# Disable a task
schtasks /Change /TN "PowerCA_ForwardSync_Full" /DISABLE

# Enable a task
schtasks /Change /TN "PowerCA_ForwardSync_Full" /ENABLE
```

### Delete Tasks

```cmd
schtasks /Delete /TN "PowerCA_ForwardSync_Full" /F
schtasks /Delete /TN "PowerCA_ForwardSync_Incremental" /F
schtasks /Delete /TN "PowerCA_ReverseSync_Daily" /F
```

### Change Times

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
1. System is ON at scheduled time ✅
2. Task is enabled: `schtasks /Query /TN PowerCA_ForwardSync_Full`
3. PostgreSQL running on port 5433
4. `.env` file exists with credentials

### Sync Failing

**Check logs:**
```cmd
dir /b /o-d logs\*.log | more
type logs\[latest-log].log
findstr /I "ERROR" logs\*.log
```

**Common fixes:**
- Network timeout → Increase timeout in [sync/config.js](sync/config.js)
- Connection refused → Start PostgreSQL desktop database
- Disk space → Free up space (staging needs 2x table size)

---

## Complete Documentation

**For more details:**
- [batch-scripts/README.md](batch-scripts/README.md) - Complete batch scripts guide
- [docs/SYNC-SCHEDULING-GUIDE.md](docs/SYNC-SCHEDULING-GUIDE.md) - Full scheduling documentation
- [CLAUDE.md](CLAUDE.md) - Complete project guide

---

## Quick Commands

```cmd
# Setup (one-time)
powershell -ExecutionPolicy Bypass -File batch-scripts\automated\setup-windows-scheduler.ps1

# View tasks
schtasks /Query /TN PowerCA*

# Test task
schtasks /Run /TN "PowerCA_ReverseSync_Daily"

# View logs
dir /b /o-d logs\*.log

# Manual sync menu
batch-scripts\manual\sync-menu.bat

# Verify data
node scripts\verify-all-tables.js
```

---

**You're all set!** The automated sync will run daily at the scheduled times as long as the system is ON.

---

**Document Version:** 1.0
**Date:** 2025-11-01
**Custom Schedule:** Office Hours (10 AM - 5:30 PM)
