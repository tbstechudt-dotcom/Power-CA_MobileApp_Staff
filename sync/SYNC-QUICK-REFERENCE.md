# PowerCA Mobile Sync - Quick Reference

**Fast reference guide for common sync operations**

---

## Quick Start

### Running Syncs

```bash
# Forward Sync (Desktop → Supabase)
node sync/production/runner-staging.js --mode=full         # All records
node sync/production/runner-staging.js --mode=incremental  # Changed only

# Reverse Sync (Supabase → Desktop)
node sync/production/reverse-sync-engine.js
```

### Typical Sync Times

| Operation | Records | Duration |
|-----------|---------|----------|
| Full sync (all tables) | ~90,000 | 3-5 minutes |
| Incremental sync | ~100-500 | 30-40 seconds |
| Single table (climaster) | 726 | <1 second |
| Single table (jobshead) | 24,562 | 9 seconds |
| Single table (jobtasks) | 64,542 | 23 seconds |

---

## ETL Process Overview

### Extract Phase
```javascript
// Full sync: Get ALL records
SELECT * FROM climaster

// Incremental sync: Get CHANGED records only
SELECT * FROM climaster
WHERE updated_at > '2025-10-30' OR created_at > '2025-10-30'
```

### Transform Phase
```javascript
// 1. Build lookups (fetch related data)
// Example: jobtasks needs client_id from jobshead
lookupCache['client_id'] = { job_id: 12345 → client_id: 500 }

// 2. Transform record
{
  job_id: 12345,
  task_name: "Design",
  // Added by transform:
  client_id: 500,      // Looked up from jobshead
  source: 'D',         // Mark as desktop data
  created_at: NOW(),
  updated_at: NOW()
}

// 3. Filter invalid records
// Remove records with bad FK references
```

### Load Phase
```javascript
// 1. Create staging table
CREATE TEMP TABLE climaster_staging (LIKE climaster)

// 2. Batch load to staging (1000 records per INSERT)
INSERT INTO climaster_staging VALUES (...), (...), ... (1000 rows)

// 3. Load to production
BEGIN TRANSACTION;

  // Desktop PK tables: UPSERT
  INSERT INTO climaster SELECT * FROM climaster_staging
  ON CONFLICT (client_id) DO UPDATE SET ...
  WHERE source = 'D' OR source IS NULL

  // Mobile PK tables: DELETE+INSERT
  DELETE FROM jobshead WHERE source = 'D' OR source IS NULL
  INSERT INTO jobshead SELECT * FROM jobshead_staging

COMMIT;

// 4. Drop staging
DROP TABLE climaster_staging;
```

---

## Table Categories

### Desktop PK Tables (UPSERT Pattern)

**Characteristics:**
- Desktop manages the primary key (client_id, org_id, etc.)
- PK values are stable and unique
- Use UPSERT to preserve existing PKs
- Can use true incremental sync

**Tables:**
- `climaster` (client_id)
- `orgmaster` (org_id)
- `locmaster` (loc_id)
- `conmaster` (con_id)
- `mbstaff` (staff_id)
- `reminder` (rem_id)
- `cliunimaster`, `taskmaster`, `jobmaster`, `learequest`

**Sync Logic:**
```sql
INSERT INTO climaster SELECT * FROM climaster_staging
ON CONFLICT (client_id) DO UPDATE SET
  client_name = EXCLUDED.client_name,
  email = EXCLUDED.email,
  ...
WHERE climaster.source = 'D' OR climaster.source IS NULL
```

### Mobile PK Tables (DELETE+INSERT Pattern)

**Characteristics:**
- Mobile generates the primary key (id BIGSERIAL)
- Desktop doesn't have this PK column
- Use DELETE+INSERT to get fresh mobile PKs
- **MUST use FULL sync** (incremental would cause data loss)

**Tables:**
- `jobshead` (id)
- `jobtasks` (id)
- `taskchecklist` (tc_id)
- `workdiary` (id)

**Sync Logic:**
```sql
-- Delete old desktop records (preserve mobile records)
DELETE FROM jobshead WHERE source = 'D' OR source IS NULL;

-- Insert with fresh mobile-generated PKs
INSERT INTO jobshead SELECT * FROM jobshead_staging;
```

**Critical:** Engine automatically forces FULL sync for these tables, even when user requests incremental.

---

## Configuration Quick Reference

### Table Mapping

```javascript
// Desktop table name → Mobile table name
tableMapping: {
  'mbreminder': 'reminder',     // Renamed
  'mbremdetail': 'remdetail',   // Renamed
  'climaster': 'climaster',     // Same name
  'jobshead': 'jobshead',       // Same name
  // ...
}
```

### Column Transformations

```javascript
columnMappings: {
  jobshead: {
    skipColumns: ['job_uid', 'sporg_id'],  // Remove desktop-only fields
    addColumns: {
      source: 'D',                          // Add mobile fields
      created_at: () => new Date(),
      updated_at: () => new Date()
    }
  },

  jobtasks: {
    skipColumns: ['jt_uid'],
    addColumns: { source: 'D', ... },
    lookups: {
      client_id: {                          // Lookup from jobshead
        fromTable: 'jobshead',
        sourceKey: 'job_id',
        targetKey: 'client_id'
      }
    }
  }
}
```

---

## Common Scenarios

### Scenario 1: Add New Table to Sync

**1. Update config.js:**
```javascript
tableMapping: {
  ...
  'mytable': 'mytable'  // Add table mapping
}

// If needed:
columnMappings: {
  mytable: {
    skipColumns: ['desktop_only_field'],
    addColumns: { source: 'D', ... }
  }
}
```

**2. Ensure table has timestamp columns:**
```sql
ALTER TABLE mytable
ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add trigger for updated_at
CREATE TRIGGER update_mytable_updated_at
  BEFORE UPDATE ON mytable
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**3. Run full sync:**
```bash
node sync/production/runner-staging.js --mode=full
```

### Scenario 2: Mobile User Creates Records

**Mobile App (Flutter):**
```dart
final response = await supabase
  .from('reminder')
  .insert({
    'rem_id': 1001,          // Desktop-compatible PK
    'staff_id': 5,
    'rem_subject': 'Follow up',
    'source': 'M',           // Mark as mobile-created
    'created_at': DateTime.now(),
    'updated_at': DateTime.now()
  });
```

**Reverse Sync (Scheduled):**
```bash
# Runs hourly via cron
node sync/production/reverse-sync-engine.js

# Pulls mobile records (source='M') back to desktop
# INSERT-only, never updates desktop records
```

### Scenario 3: Desktop Updates Records

**Desktop App updates climaster:**
```sql
UPDATE climaster
SET client_name = 'New Name',
    updated_at = NOW()
WHERE client_id = 100;
```

**Forward Sync (Incremental):**
```bash
node sync/production/runner-staging.js --mode=incremental

# Detects updated_at change
# Syncs only changed record (client_id=100)
# Updates Supabase via UPSERT
```

### Scenario 4: Troubleshoot Sync Errors

**Check sync metadata:**
```sql
SELECT * FROM _sync_metadata
WHERE error_message IS NOT NULL
ORDER BY updated_at DESC;
```

**Check record counts:**
```sql
-- Desktop
SELECT COUNT(*) FROM climaster;  -- 729

-- Supabase
SELECT COUNT(*) FROM climaster;  -- Should match (726 after filtering)
```

**Check sync logs:**
```bash
# If running in background with nohup
tail -f sync.log

# Or grep for errors
grep "ERROR\|Error\|✗" sync.log
```

---

## Safety Features

### 1. Staging Tables
- All data loaded to temp table first
- If loading fails, production untouched
- Atomic commit at end

### 2. Transaction Rollback
```javascript
try {
  await client.query('BEGIN');
  // ... all sync operations ...
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  // Production data restored!
}
```

### 3. Mobile Data Preservation
```sql
-- UPSERT only updates desktop records
WHERE source = 'D' OR source IS NULL

-- DELETE only removes desktop records
DELETE FROM jobshead WHERE source = 'D' OR source IS NULL
```

### 4. Column Validation
```javascript
// Check timestamp columns exist before incremental sync
if (!hasTimestampColumns) {
  // Fallback to full sync
}
```

### 5. FK Validation
```javascript
// Filter invalid FK references
if (record.client_id && !validClientIds.has(record.client_id)) {
  // Skip record, log warning
}
```

---

## Performance Optimization

### Batch INSERT (1000 records per query)
```javascript
// Before: 1 INSERT per record
for (const record of records) {
  await query(`INSERT INTO ...`, [record]);  // 24,562 queries!
}

// After: 1000 records per INSERT
INSERT INTO table VALUES
  (row1),
  (row2),
  ...
  (row1000);  // Only 25 queries!
```

**Result:** 100-188x faster sync times

### Incremental Sync
```javascript
// Only sync changed records
WHERE updated_at > last_sync OR created_at > last_sync

// Example:
// - Full sync: 24,562 records = 10 seconds
// - Incremental: 50 records = <1 second
```

### Connection Pooling
```javascript
max: 10  // Reuse connections, don't create new each time
```

---

## Monitoring & Debugging

### Check Sync Status
```sql
-- Last sync times
SELECT
  table_name,
  last_sync_timestamp,
  records_synced,
  last_sync_duration_ms / 1000.0 as duration_sec
FROM _sync_metadata
ORDER BY last_sync_timestamp DESC;
```

### Check Data Distribution
```sql
-- Count by source
SELECT source, COUNT(*)
FROM jobshead
GROUP BY source;

-- Result:
-- source | count
-- -------+-------
-- D      | 24562  (Desktop)
-- M      | 15     (Mobile)
```

### Verify Sync Completed
```bash
# Check exit code
echo $?  # 0 = success, 1 = failure

# Or check output
node sync/production/runner-staging.js --mode=full | grep "✅ Sync completed"
```

---

## Error Recovery

### Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "column does not exist" | Missing timestamp columns | Auto-detected, fallback to full sync |
| "Cannot read properties of undefined" | Config property mismatch | Fixed in Bug #3 |
| Data loss in incremental | DELETE+INSERT with incomplete data | Fixed in Bug #2 (force full) |
| FK constraint violation | Orphaned records | Filter invalid or remove FK |
| Duplicate key violation | Desktop has duplicate PKs | Remove PK constraint |

### Recovery Steps

**If sync fails mid-run:**
1. Check error message in console
2. Verify production data unchanged (staging rollback)
3. Fix issue (add column, remove FK, etc.)
4. Re-run sync

**If data loss detected:**
1. Check backup/staging table if available
2. Restore from desktop with full sync
3. Investigate root cause (check Bug #2 fix)

---

## Production Checklist

### Before Running Sync

- [ ] Verify desktop database connection
- [ ] Verify Supabase connection
- [ ] Check disk space (staging needs 2x table size)
- [ ] Backup Supabase database (if first time)
- [ ] Review CLAUDE.md for known issues
- [ ] Check timestamp columns exist (for incremental)

### During Sync

- [ ] Monitor progress (tail -f sync.log)
- [ ] Check for errors in console
- [ ] Verify expected record counts
- [ ] Watch for FK violations
- [ ] Check memory/CPU usage

### After Sync

- [ ] Compare record counts (desktop vs Supabase)
- [ ] Check _sync_metadata table
- [ ] Verify mobile data preserved (source='M')
- [ ] Test mobile app queries
- [ ] Document any issues found

---

## Useful Commands

### Database Queries

```sql
-- Check table size
SELECT pg_size_pretty(pg_total_relation_size('jobshead'));

-- Check active connections
SELECT * FROM pg_stat_activity WHERE state = 'active';

-- Find orphaned records
SELECT j.* FROM jobtasks j
LEFT JOIN jobshead jh ON j.job_id = jh.job_id
WHERE jh.job_id IS NULL;

-- Check sync progress
SELECT * FROM _sync_metadata ORDER BY updated_at DESC LIMIT 5;
```

### Shell Commands

```bash
# Run sync in background
nohup node sync/production/runner-staging.js --mode=full > sync.log 2>&1 &

# Monitor sync progress
tail -f sync.log

# Check process status
ps aux | grep "node sync"

# Kill background sync
pkill -f "node sync"

# Count log lines
wc -l sync.log

# Find errors in log
grep -i error sync.log | head -20
```

---

## Key Metrics

### Expected Performance (Nov 2025)

| Table | Records | Full Sync | Incremental |
|-------|---------|-----------|-------------|
| climaster | 726 | 0.78s | 0.5s (if changes) |
| jobshead | 24,562 | 8.81s | 8.81s (forced full) |
| jobtasks | 64,542 | 22.95s | 22.95s (forced full) |
| reminder | 121 | 2.00s | <1s |
| **TOTAL** | ~90,000 | **3-5 min** | **30-40 sec** |

### Batch Processing Stats

- Batch size: 1000 records per INSERT
- Performance gain: 100-188x faster than row-by-row
- Memory usage: ~10MB per 1000 records

---

## Related Documentation

**Must Read:**
- [SYNC-ENGINE-ETL-GUIDE.md](SYNC-ENGINE-ETL-GUIDE.md) - Complete ETL documentation with code examples

**Reference:**
- [CLAUDE.md](../CLAUDE.md) - Main project guide
- [staging-table-sync.md](staging-table-sync.md) - Staging table pattern explained
- [BIDIRECTIONAL-SYNC-STRATEGY.md](BIDIRECTIONAL-SYNC-STRATEGY.md) - Sync architecture

**Bug Fixes (2025-10-31):**
- [CRITICAL-FIX-INCREMENTAL-DATA-LOSS.md](CRITICAL-FIX-INCREMENTAL-DATA-LOSS.md) - Issue #2
- [FIX-METADATA-SEEDING-BUG.md](FIX-METADATA-SEEDING-BUG.md) - Issue #3
- [FIX-TIMESTAMP-COLUMN-VALIDATION.md](FIX-TIMESTAMP-COLUMN-VALIDATION.md) - Issue #4

---

**Last Updated:** 2025-10-31
**Version:** 1.0
