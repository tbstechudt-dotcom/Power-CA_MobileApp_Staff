# One-Click Sync - Quick Start Guide

**Date:** 2025-10-31
**Purpose:** Simple batch file execution for PowerCA Mobile sync operations

---

## Available Batch Files

All batch files are located in the project root: `D:\PowerCA Mobile\`

### 1. **sync-menu.bat** ⭐ (Recommended)

**Interactive menu with all options**

- Double-click to open menu
- Choose sync type by entering number (1-3)
- Automatically loops back to menu after each sync
- Perfect for daily use

**Options:**
- [1] Full Forward Sync
- [2] Incremental Forward Sync
- [3] Reverse Sync
- [0] Exit

---

### 2. **sync-full.bat**

**Full forward sync (Desktop → Supabase)**

- Syncs ALL records from desktop to Supabase
- Takes ~2-3 minutes for all tables
- Uses safe STAGING TABLE pattern
- Mobile data (source='M') is preserved

**When to use:**
- First-time setup
- After major desktop data changes
- Weekly/monthly full refresh
- When incremental sync has issues

---

### 3. **sync-incremental.bat**

**Incremental forward sync (Desktop → Supabase)**

- Syncs only CHANGED records since last sync
- Takes ~30-60 seconds
- Uses timestamp tracking (created_at/updated_at)
- Mobile-only PK tables auto-force FULL mode

**When to use:**
- Daily sync operations
- After minor desktop changes
- Quick updates between full syncs

**Note:** Mobile-only PK tables (jobshead, jobtasks, taskchecklist, workdiary) automatically run in FULL mode even when incremental is selected to prevent data loss.

---

### 4. **sync-reverse.bat**

**Reverse sync (Supabase → Desktop)**

- Syncs mobile-created records back to desktop
- INSERT-ONLY (no updates or deletes)
- Takes ~1-2 minutes
- Uses metadata tracking for incremental sync

**When to use:**
- After mobile users create data
- For backup of mobile data to desktop
- For desktop reporting on mobile activity
- Weekly/monthly mobile data pull

**First-time setup required:**
```bash
# Run ONCE before first reverse sync
node scripts/create-reverse-sync-metadata-table.js
```

---

## Quick Start

### For First-Time Use:

1. **Run full forward sync**
   ```
   Double-click: sync-full.bat
   Wait ~2-3 minutes
   ```

2. **Verify completion**
   - Check for "✓ SYNC COMPLETED SUCCESSFULLY!" message
   - Review sync log for any errors

3. **Schedule regular incremental syncs**
   - Daily: `sync-incremental.bat`
   - Weekly: `sync-reverse.bat`

---

### For Daily Operations:

**Option A: Use Menu (Recommended)**
```
Double-click: sync-menu.bat
Choose: [2] Incremental Forward Sync
```

**Option B: Direct Execution**
```
Double-click: sync-incremental.bat
```

---

## How It Works

### Safety Features:

✅ **Staging Tables** - All forward syncs use staging table pattern
- Changes are loaded into temporary tables first
- Production data is never cleared until staging is ready
- Automatic rollback on failure

✅ **Mobile Data Preservation** - Records with source='M' are never overwritten
- UPSERT pattern: `WHERE source='D' OR source IS NULL`
- Mobile users' data is completely safe

✅ **Error Handling** - Batch files check for errors
- Shows clear success/failure message
- Returns proper exit codes
- Pauses at end so you can review output

✅ **Validation** - Pre-flight checks before running
- Verifies Node.js is installed
- Checks sync engine files exist
- Clear error messages if requirements missing

---

## Requirements

### Software:
- Node.js (v16 or higher)
- PostgreSQL desktop database running on port 5433
- Internet connection to Supabase Cloud

### Environment:
- `.env` file must exist with Supabase credentials
- Database connections must be configured in `sync/production/config.js`

---

## Sync Performance

| Sync Type | Tables | Records | Time | Best For |
|-----------|--------|---------|------|----------|
| Full Forward | 15 | ~95,000 | 2-3 min | Initial setup, weekly refresh |
| Incremental Forward | 15 | ~100-1,000 | 30-60 sec | Daily updates |
| Reverse Sync | 15 | ~50-500 | 5-10 min | Mobile data backup |

---

## Troubleshooting

### Batch file won't run

**Problem:** "Node.js not found in PATH"

**Solution:**
1. Install Node.js from https://nodejs.org/
2. Or add Node.js to PATH environment variable

---

### Sync fails with error

**Problem:** "Sync engine not found"

**Solution:**
1. Ensure you're running batch file from project root
2. Verify files exist:
   - `sync\production\runner-staging.js` (forward sync)
   - `sync\production\reverse-sync-engine.js` (reverse sync)

---

### Connection timeout

**Problem:** "Connection timeout" or "ECONNREFUSED"

**Solution:**
1. **Desktop database:** Check PostgreSQL service is running on port 5433
2. **Supabase:** Check internet connection
3. **Firewall:** Ensure port 5432 is not blocked

---

### Incremental sync takes too long

**Problem:** Incremental sync runs for 2+ minutes

**Explanation:** Mobile-only PK tables auto-force FULL mode for data safety

**Solution:** This is expected behavior. Tables jobshead, jobtasks, taskchecklist, and workdiary always run in FULL mode to prevent the DELETE+INSERT data loss bug.

---

## Scheduling Syncs

### Windows Task Scheduler

Create scheduled tasks to run batch files automatically:

**Daily Incremental Sync:**
```
Trigger: Daily at 8:00 AM
Action: Start program
Program: D:\PowerCA Mobile\sync-incremental.bat
```

**Weekly Full Sync:**
```
Trigger: Every Sunday at 2:00 AM
Action: Start program
Program: D:\PowerCA Mobile\sync-full.bat
```

**Weekly Reverse Sync:**
```
Trigger: Every Sunday at 3:00 AM
Action: Start program
Program: D:\PowerCA Mobile\sync-reverse.bat
```

---

## Sync Logs

### Viewing Logs:

All sync operations output to console. To capture logs:

**Method 1: Redirect to file**
```batch
node sync\production\runner-staging.js --mode=full > sync-log.txt 2>&1
```

**Method 2: Use tee command (requires Git Bash)**
```bash
node sync/production/runner-staging.js --mode=full | tee sync-log.txt
```

### Log Location:

Batch files don't automatically save logs. To enable logging, modify batch file:

```batch
REM Add this line before node command:
echo Logging to sync-log-%date:~-4,4%%date:~-10,2%%date:~-7,2%.txt
node sync\production\runner-staging.js --mode=full > sync-log-%date:~-4,4%%date:~-10,2%%date:~-7,2%.txt 2>&1
```

---

## Best Practices

### For Production Use:

1. **Test first** - Run full sync once and verify all data synced correctly
2. **Schedule wisely** - Run incremental syncs during low-usage hours
3. **Monitor regularly** - Check sync logs for errors
4. **Keep backups** - Backup both desktop and Supabase databases before major syncs
5. **Use incremental** - Default to incremental sync for speed and efficiency

### Sync Frequency:

| Environment | Full Sync | Incremental Sync | Reverse Sync |
|-------------|-----------|------------------|--------------|
| Development | Daily | Hourly | Daily |
| Testing | Weekly | Daily | Weekly |
| Production | Monthly | Daily | Weekly |

---

## Command-Line Alternatives

If you prefer command line over batch files:

### Full Forward Sync:
```bash
cd "D:\PowerCA Mobile"
node sync/production/runner-staging.js --mode=full
```

### Incremental Forward Sync:
```bash
cd "D:\PowerCA Mobile"
node sync/production/runner-staging.js --mode=incremental
```

### Reverse Sync:
```bash
cd "D:\PowerCA Mobile"
node sync/production/reverse-sync-engine.js
```

---

## Related Documentation

- [SYNC-ENGINE-ETL-GUIDE.md](SYNC-ENGINE-ETL-GUIDE.md) - Complete ETL process documentation
- [SYNC-QUICK-REFERENCE.md](SYNC-QUICK-REFERENCE.md) - Quick command reference
- [CLAUDE.md](../CLAUDE.md) - Project overview and best practices
- [FIX-SUMMARY-2025-10-31.md](FIX-SUMMARY-2025-10-31.md) - Recent bug fixes

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review [CLAUDE.md](../CLAUDE.md) for common pitfalls
3. Check sync logs for specific error messages
4. Verify database connections and credentials

---

**Document Version:** 1.0
**Date:** 2025-10-31
**Author:** Claude Code (AI)

---

## Quick Reference Card

**Copy this section and pin near your desk!**

```
┌─────────────────────────────────────────────────────┐
│        PowerCA Mobile - Sync Quick Reference        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Daily Sync:         sync-incremental.bat          │
│  Weekly Full:        sync-full.bat                 │
│  Mobile Backup:      sync-reverse.bat              │
│  Interactive Menu:   sync-menu.bat                 │
│                                                     │
│  Location: D:\PowerCA Mobile\                      │
│                                                     │
│  ✓ Double-click to run                            │
│  ✓ Wait for success message                       │
│  ✓ Check for errors before closing               │
│                                                     │
└─────────────────────────────────────────────────────┘
```
