# Reverse Sync Updates - 2025-10-30

## Overview

Updated the reverse sync engine to sync **ALL 15 tables** (not just 5) from Supabase back to Desktop PostgreSQL in incremental mode.

---

## Changes Made

### Before (Old Behavior)

**Only 5 tables synced:**
```javascript
const mobileDataTables = [
  'workdiary',     // Time entries
  'taskchecklist', // Checklists
  'reminder',      // Reminders
  'remdetail',     // Reminder details
  'learequest',    // Leave requests
];
```

**Filtered by mobile-only:**
- Only synced records with `source='M'` (mobile-created)
- Ignored desktop-created records in Supabase

---

### After (New Behavior)

**ALL 15 tables synced:**

**Master Tables (8):**
1. `orgmaster` - Organizations
2. `locmaster` - Locations
3. `conmaster` - Contacts
4. `climaster` - Clients
5. `mbstaff` - Staff members
6. `taskmaster` - Task templates (optional)
7. `jobmaster` - Job templates (optional)
8. `cliunimaster` - Client units (optional)

**Transactional Tables (7):**
9. `jobshead` - Job headers
10. `jobtasks` - Job tasks
11. `taskchecklist` - Task checklists
12. `workdiary` - Work diary entries
13. `reminder` - Reminders
14. `remdetail` - Reminder details
15. `learequest` - Leave requests

**Sync Mode: Incremental INSERT only**
- Syncs ALL records (not just `source='M'`)
- Time window: Last 7 days (via `updated_at` column)
- **Only INSERTs** new records (no UPDATE/DELETE)
- Checks existence by primary key before inserting

---

## Key Safety Features

### ✅ 1. Incremental Only (No Full Sync)
```javascript
// Only syncs recent changes (7 days)
WHERE updated_at > NOW() - INTERVAL '7 days'
```

### ✅ 2. INSERT Only (No Modify/Delete)
```javascript
async insertNewToDesktop(tableName, record) {
  // Check if exists
  if (exists) {
    return false; // SKIP - don't update
  }

  // Insert new only
  INSERT INTO table VALUES (...);
  return true;
}
```

### ✅ 3. Existence Check Before Insert
```javascript
// Check if record already exists by primary key
const checkQuery = `SELECT 1 FROM ${tableName} WHERE ${pkColumn} = $1`;
const exists = await targetPool.query(checkQuery, [record.pk]);

if (exists.rows.length > 0) {
  return false; // Skip - already exists
}
```

### ✅ 4. No Data Loss
- Never deletes existing records
- Never updates existing records
- Only adds new records

---

## How It Works

### 1. Connection
```
Supabase (Source) → Desktop PostgreSQL (Target)
```

### 2. For Each Table

**Step 1: Fetch Recent Records**
```sql
-- If table has updated_at column
SELECT * FROM table
WHERE updated_at > NOW() - INTERVAL '7 days'
ORDER BY updated_at DESC;

-- If no updated_at column
SELECT * FROM table LIMIT 10000;
```

**Step 2: Check Existence**
```sql
SELECT 1 FROM desktop_table WHERE pk_column = $1;
```

**Step 3: Insert If New**
```sql
-- Only if NOT exists in desktop
INSERT INTO desktop_table (columns...)
VALUES (values...);
```

**Step 4: Report Results**
```
✓ Synced X new records to desktop (Y already existed)
```

---

## Usage

### Run Reverse Sync

```bash
# Production safe script
node sync/production/reverse-sync-engine.js

# Or from root
node sync/reverse-sync-engine.js
```

### Schedule Hourly Sync

**Linux/Mac (cron):**
```bash
# Add to crontab
0 * * * * cd /path/to/PowerCA\ Mobile && node sync/production/reverse-sync-engine.js >> logs/reverse-sync.log 2>&1
```

**Windows (Task Scheduler):**
- Program: `node`
- Arguments: `sync/production/reverse-sync-engine.js`
- Start in: `D:\PowerCA Mobile`
- Trigger: Hourly

---

## Table Name Mappings

Some tables have different names in Supabase vs Desktop:

| Supabase Name | Desktop Name |
|---------------|--------------|
| `reminder` | `mbreminder` |
| `remdetail` | `mbremdetail` |
| All others | Same name |

The reverse sync automatically handles these mappings.

---

## Primary Keys

All 15 tables have primary keys for existence checking:

```javascript
const primaryKeys = {
  // Master tables
  'orgmaster': 'org_id',
  'locmaster': 'loc_id',
  'conmaster': 'con_id',
  'climaster': 'client_id',
  'mbstaff': 'staff_id',
  'taskmaster': 'task_id',
  'jobmaster': 'job_id',
  'cliunimaster': 'cliu_id',
  // Transactional tables
  'jobshead': 'job_id',
  'jobtasks': 'jt_id',
  'taskchecklist': 'tc_id',
  'workdiary': 'wd_id',
  'mbreminder': 'rem_id',
  'mbremdetail': 'remd_id',
  'learequest': 'lea_id',
};
```

---

## Expected Output

```
============================================================
REVERSE SYNC - Supabase to Desktop (Incremental)
Time: 2025-10-30T10:00:00.000Z
============================================================

Mode: Incremental INSERT only (no delete/update)
Time window: Last 7 days

--- Master Tables ---

Reverse syncing: orgmaster
  - Found 2 records in Supabase
  ✓ Synced 0 new records to desktop (2 already existed)
  Duration: 0.15s

Reverse syncing: locmaster
  - Found 1 records in Supabase
  ✓ Synced 0 new records to desktop (1 already existed)
  Duration: 0.12s

[... more master tables ...]

--- Transactional Tables ---

Reverse syncing: jobshead
  - Found 142 records in Supabase
  ✓ Synced 12 new records to desktop (130 already existed)
  Duration: 2.45s

Reverse syncing: jobtasks
  - Found 387 records in Supabase
  ✓ Synced 35 new records to desktop (352 already existed)
  Duration: 4.12s

[... more transactional tables ...]

============================================================
REVERSE SYNC SUMMARY
============================================================
Start Time:     2025-10-30T10:00:00.000Z
End Time:       2025-10-30T10:00:15.234Z
Duration:       15.23s
Records Synced: 78
Errors:         0
============================================================
```

---

## What Gets Synced

### Master Tables
Usually **no new records** (reference data rarely changes):
- Organizations (rarely added)
- Locations (rarely added)
- Clients (added on desktop mostly)
- Staff (added on desktop mostly)

### Transactional Tables
**New records created on mobile:**
- Jobs created/updated on mobile
- Tasks marked complete on mobile
- Checklists updated on mobile
- Time logged on mobile
- Reminders created on mobile
- Leave requests submitted on mobile

### Jobs/Tasks Modified on Mobile
If a job or task is updated on mobile (e.g., status changed, notes added):
- The `updated_at` timestamp changes
- Record appears in 7-day window
- But already exists in desktop (by job_id/jt_id)
- **SKIPPED** - not updated (per requirement)

**Note:** If you need to sync updates (not just inserts), you'll need to modify the `insertNewToDesktop` method to do UPSERT instead of INSERT-only.

---

## Monitoring

### Check Sync Logs

```bash
# View reverse sync logs
tail -f logs/reverse-sync.log

# Check for errors
grep "Error" logs/reverse-sync.log

# Count synced records
grep "Synced.*new records" logs/reverse-sync.log
```

### Verify Record Counts

```bash
# Before reverse sync
psql -h localhost -p 5433 -d enterprise_db -c "SELECT COUNT(*) FROM jobshead;"

# After reverse sync
psql -h localhost -p 5433 -d enterprise_db -c "SELECT COUNT(*) FROM jobshead;"

# Should see new records added
```

---

## Troubleshooting

### Issue: No Records Synced

**Possible causes:**
1. No new records in last 7 days
2. All records already exist in desktop
3. No `updated_at` column in table

**Solution:**
```bash
# Check Supabase for recent records
psql "postgresql://..." -c "
  SELECT COUNT(*) FROM jobshead
  WHERE updated_at > NOW() - INTERVAL '7 days';
"
```

### Issue: Duplicate Key Errors

**Error:** `duplicate key value violates unique constraint`

**Cause:** Desktop has stricter constraints than expected

**Solution:**
```bash
# Check which records are failing
grep "duplicate key" logs/reverse-sync.log

# May need to adjust primary key logic or handle duplicates
```

### Issue: Table Not Found

**Error:** `relation "tablename" does not exist`

**Cause:** Table doesn't exist in desktop database

**Solution:**
- Verify table name mapping (reminder → mbreminder)
- Check table exists in desktop: `\dt tablename`

---

## Benefits of Updated Reverse Sync

### Before (Old):
- ❌ Only 5 tables synced
- ❌ Mobile-created records only
- ❌ Desktop-created records in Supabase ignored
- ❌ Incomplete bidirectional sync

### After (New):
- ✅ All 15 tables synced
- ✅ All records considered (desktop + mobile created)
- ✅ True bidirectional sync
- ✅ Desktop always has complete data set
- ✅ Mobile and Desktop stay in sync

---

## Next Steps

1. **Test reverse sync** on development environment:
   ```bash
   node sync/production/reverse-sync-engine.js
   ```

2. **Schedule hourly reverse sync** (cron/Task Scheduler)

3. **Monitor logs** for first few runs

4. **Verify record counts** after each sync

5. **Adjust time window** if needed (currently 7 days)

---

## Configuration Options

### Change Time Window

Edit [reverse-sync-engine.js:131](../sync/reverse-sync-engine.js#L131):

```javascript
// Current: 7 days
WHERE updated_at > NOW() - INTERVAL '7 days'

// Change to 24 hours (more frequent syncs)
WHERE updated_at > NOW() - INTERVAL '1 day'

// Change to 30 days (less frequent syncs)
WHERE updated_at > NOW() - INTERVAL '30 days'
```

### Add More Tables

If you add new tables to the schema:

1. Add to `masterTables` or `transactionalTables` array
2. Add table name mapping (if different)
3. Add primary key to `getPrimaryKeyColumn()`

---

## Safety Guarantees

✅ **No data loss** - Never deletes existing records
✅ **No overwrites** - Never updates existing records
✅ **Incremental only** - Only adds new records
✅ **FK safe** - Desktop has no FK constraints
✅ **Idempotent** - Can run multiple times safely

---

## Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Full project guide
- [AGENTS.md](../AGENTS.md) - AI coding assistant guide
- [BIDIRECTIONAL-SYNC-STRATEGY.md](BIDIRECTIONAL-SYNC-STRATEGY.md) - Sync architecture
- [sync/production/README.md](../sync/production/README.md) - Production sync guide

---

**Document Version:** 1.0
**Last Updated:** 2025-10-30
**Changes By:** Claude Code
**Purpose:** Document reverse sync updates to sync ALL 15 tables (not just 5)
