# PowerCA Mobile - Scheduler Batch Scripts

Individual batch scripts for Windows Task Scheduler.

## Available Scripts

| Script | Description | Suggested Schedule |
|--------|-------------|-------------------|
| `00-complete-sync-workflow.bat` | Runs all sync steps in sequence | Manual or weekly |
| `01-pre-sync-desktop-views.bat` | Syncs parent table updates to mobile tables | Daily 9:45 AM |
| `02-forward-sync-full.bat` | Full sync Desktop -> Supabase | Daily 10:00 AM |
| `03-forward-sync-incremental.bat` | Incremental sync (changed records) | Every 2 hours |
| `04-reverse-sync.bat` | Reverse sync Supabase -> Desktop | Daily 5:30 PM |
| `05-post-sync-to-parent.bat` | Insert mobile data to parent tables | Daily 6:00 PM |
| `06-sync-status-report.bat` | Generate daily sync status report | Daily 7:00 PM |

## Quick Start

### Option 1: Automatic Installation (Recommended)

1. Right-click `install-all-scheduled-tasks.bat`
2. Select "Run as administrator"
3. All tasks will be created with default schedules

### Option 2: Manual Installation

1. Open Task Scheduler (`taskschd.msc`)
2. Click "Create Basic Task"
3. Set name (e.g., "PowerCA-ForwardSyncFull")
4. Choose trigger (e.g., Daily at 10:00 AM)
5. Action: Start a program
6. Program: Full path to the batch file
7. Start in: `D:\PowerCA Mobile`

## Recommended Schedule

```
09:45 AM  - Pre-sync Desktop Views (prepare data)
10:00 AM  - Forward Sync Full (Desktop -> Supabase)
12:00 PM  - Forward Sync Incremental
02:00 PM  - Forward Sync Incremental
04:00 PM  - Forward Sync Incremental
05:30 PM  - Reverse Sync (Supabase -> Desktop)
06:00 PM  - Post-sync Insert to Parent Tables
07:00 PM  - Sync Status Report
```

## Log Files

All scripts create timestamped log files in:
```
D:\PowerCA Mobile\logs\
```

Log file naming:
- `pre-sync-desktop-views_YYYYMMDD_HHMMSS.log`
- `forward-sync-full_YYYYMMDD_HHMMSS.log`
- `forward-sync-incremental_YYYYMMDD_HHMMSS.log`
- `reverse-sync_YYYYMMDD_HHMMSS.log`
- `post-sync-to-parent_YYYYMMDD_HHMMSS.log`
- `sync-status-report_YYYYMMDD_HHMMSS.log`

## Uninstall

To remove all scheduled tasks:
1. Right-click `uninstall-all-scheduled-tasks.bat`
2. Select "Run as administrator"

## Troubleshooting

### Task doesn't run
- Check Task Scheduler history for errors
- Verify the path in the task action
- Ensure Node.js is in system PATH

### Sync fails with connection error
- Check network connectivity
- Verify `.env` file has correct credentials
- Check if PostgreSQL/Supabase is accessible

### Log file shows errors
- Review the specific error in the log
- Check `CLAUDE.md` for known issues and fixes
