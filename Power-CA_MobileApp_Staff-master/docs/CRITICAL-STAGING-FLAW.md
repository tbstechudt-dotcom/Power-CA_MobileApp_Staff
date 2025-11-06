# ✅ CRITICAL FLAW: Staging Sync Deletes Mobile Data - **FIXED**

**Severity:** CRITICAL
**Discovered:** 2025-10-30
**Fixed:** 2025-10-30
**Status:** ✅ **FIXED** (UPSERT pattern implemented)
**Impact:** Mobile-created data was being deleted on every forward sync

---

## 🎉 FIX IMPLEMENTED (2025-10-30)

### What Was Changed

**File:** `sync/engine-staging.js` and `sync/production/engine-staging.js`

✅ **Fixed Line 241-266:** Added incremental mode support
```javascript
// NEW: Incremental mode only fetches changed records
if (mode === 'incremental') {
  const lastSync = await getLastSyncTimestamp(targetTableName);
  sourceQuery = `
    SELECT * FROM ${sourceTableName}
    WHERE (updated_at > $1 OR created_at > $1 OR updated_at IS NULL)
  `;
  sourceData = await this.sourcePool.query(sourceQuery, [lastSync]);
} else {
  // Full sync - get all records
  sourceData = await this.sourcePool.query(`SELECT * FROM ${sourceTableName}`);
}
```

✅ **Fixed Line 355-417:** Replaced TRUNCATE with UPSERT
```javascript
// NEW: UPSERT preserves mobile data
await client.query(`
  INSERT INTO ${targetTableName}
  SELECT * FROM ${stagingTableName}
  ON CONFLICT (${pkColumn}) DO UPDATE SET
    ${updateSetClause}
  WHERE ${targetTableName}.source = 'D' OR ${targetTableName}.source IS NULL
`);
```

### How It Works Now

```
Timeline with UPSERT (SAFE):
─────────────────────────────────────────────────────────────
1. Mobile creates Job #99999 in Supabase
   - job_id = 99999
   - source = 'M' (mobile)
   - created_at = 2025-10-30 10:00:00

2. Forward sync runs (Desktop → Supabase)
   - Extract desktop jobs (24,568 jobs)
   - Load to staging table
   - UPSERT: INSERT new + UPDATE WHERE source='D'
   - Job #99999 has source='M' → PRESERVED! ✅

3. Result: Job #99999 still exists! ✅
─────────────────────────────────────────────────────────────
```

### Safety Guarantees

✅ **Mobile data preserved** - Records with `source='M'` are never deleted or overwritten
✅ **Desktop data synced** - Records with `source='D'` are updated as expected
✅ **New records inserted** - Records not in Supabase are added
✅ **Incremental mode works** - Only syncs changed records based on timestamp
✅ **Metadata tracking** - `_sync_metadata` table tracks last sync timestamp

### Additional Scripts Created

**scripts/create-sync-metadata-table.js**
- Creates `_sync_metadata` table for incremental sync tracking
- Initializes timestamps for all 15 tables

**Usage:**
```bash
# Initialize metadata table (run once)
node scripts/create-sync-metadata-table.js

# Run safe sync
node sync/production/runner-staging.js --mode=incremental
```

---

## Original Problem (Historical Context)

---

## The Problem

### Current Behavior (BROKEN)

**File:** `sync/engine-staging.js`

**Line 218:**
```javascript
// PROBLEM: Pulls ALL records regardless of mode
const sourceData = await this.sourcePool.query(`SELECT * FROM ${sourceTableName}`);
```

**Line 318:**
```javascript
// PROBLEM: Deletes EVERYTHING in Supabase (including mobile data)
await client.query(`TRUNCATE TABLE ${targetTableName} CASCADE`);
```

### What Happens

```
Timeline of Data Loss:
─────────────────────────────────────────────────────────────
1. Mobile creates Job #99999 in Supabase
   - job_id = 99999
   - source = 'M' (mobile)
   - created_at = 2025-10-30 10:00:00

2. Forward sync runs (Desktop → Supabase)
   - Extract ALL jobs from desktop (doesn't include #99999)
   - Load to staging table
   - TRUNCATE jobshead CASCADE  ← DELETES Job #99999!
   - INSERT desktop jobs (24,568 jobs, no #99999)

3. Result: Job #99999 is GONE forever! ❌
─────────────────────────────────────────────────────────────
```

### Why This Happens

The current sync engine has TWO critical flaws:

**Flaw #1: Ignores Mode Parameter**
```javascript
async syncTableSafe(sourceTableName, mode) {
  // mode is 'full' or 'incremental'
  // But line 218 ALWAYS does: SELECT * FROM table
  // Incremental mode is IGNORED!
}
```

**Flaw #2: TRUNCATE Deletes All Data**
```javascript
// Even with staging tables:
1. Load all desktop data to staging
2. TRUNCATE production (deletes mobile data)
3. INSERT FROM staging (only desktop data)
// Mobile data is LOST!
```

---

## Impact Assessment

### Affected Tables

ALL transactional tables where mobile creates data:

| Table | Mobile Creates? | Data Loss Risk |
|-------|----------------|----------------|
| jobshead | ✅ Yes | 🚨 CRITICAL |
| jobtasks | ✅ Yes | 🚨 CRITICAL |
| taskchecklist | ✅ Yes | 🚨 CRITICAL |
| workdiary | ✅ Yes | 🚨 CRITICAL |
| reminder | ✅ Yes | 🚨 CRITICAL |
| remdetail | ✅ Yes | 🚨 CRITICAL |
| learequest | ✅ Yes | 🚨 CRITICAL |
| climaster | ⚠️ Maybe | ⚠️ HIGH |
| mbstaff | ⚠️ Maybe | ⚠️ HIGH |

### Scenarios Where Data is Lost

**Scenario 1: Mobile Creates New Job**
```
1. User creates job on mobile app
2. Job saved to Supabase (job_id=99999, source='M')
3. Forward sync runs
4. Job #99999 deleted (not in desktop)
5. User opens mobile app → job is gone! 😱
```

**Scenario 2: Mobile Updates Existing Job**
```
1. Desktop has Job #100 (status='Open')
2. Mobile user marks Job #100 complete (status='Completed')
3. Forward sync runs
4. Job #100 reverted to 'Open' (desktop state)
5. Mobile user's work is lost! 😱
```

**Scenario 3: Reverse Sync Lag**
```
1. Mobile creates Job #200
2. Reverse sync hasn't run yet (scheduled hourly)
3. Forward sync runs before reverse sync
4. Job #200 deleted (not in desktop)
5. Reverse sync has nothing to sync (data already gone)
```

---

## Why Staging Tables Don't Fix This

**What staging tables DO protect:**
- ✅ Connection drops during sync
- ✅ Partial inserts on failure
- ✅ Atomic swap (all-or-nothing)

**What staging tables DON'T protect:**
- ❌ Data loss from TRUNCATE
- ❌ Mobile-created data deletion
- ❌ Overwrites of mobile updates

**The fundamental issue:**
```
Staging protects the PROCESS (connection safety)
But NOT the DATA (mobile records are still deleted)
```

---

## The Fix Required

### Option 1: True Incremental Sync (RECOMMENDED)

**For incremental mode:**
```javascript
// Instead of: SELECT * FROM table
// Do: SELECT * FROM table WHERE updated_at > $1

// Instead of: TRUNCATE + INSERT
// Do: UPSERT (INSERT ON CONFLICT UPDATE)
```

**Implementation:**
```javascript
async syncTableIncremental(sourceTableName, lastSyncTime) {
  // 1. Get only changed records from desktop
  const query = `
    SELECT * FROM ${sourceTableName}
    WHERE updated_at > $1 OR created_at > $1
  `;
  const desktopRecords = await sourcePool.query(query, [lastSyncTime]);

  // 2. Load to staging
  // ... load to staging ...

  // 3. UPSERT from staging to production (preserve mobile data)
  await client.query(`BEGIN`);

  // UPSERT: Update existing, insert new, PRESERVE mobile-only records
  await client.query(`
    INSERT INTO ${targetTable}
    SELECT * FROM ${stagingTable}
    ON CONFLICT (pk_column) DO UPDATE SET
      column1 = EXCLUDED.column1,
      column2 = EXCLUDED.column2,
      ...
      updated_at = EXCLUDED.updated_at
    WHERE ${targetTable}.source = 'D'  -- Only update desktop records
  `);

  await client.query(`COMMIT`);
}
```

**Benefits:**
- ✅ Only syncs changed records
- ✅ Preserves mobile-created data (source='M')
- ✅ Updates desktop-created data (source='D')
- ✅ Fast (only changed records)
- ✅ True bidirectional sync

---

### Option 2: Separate Tables (Alternative)

**Approach:**
- Desktop records: `jobshead_desktop`
- Mobile records: `jobshead_mobile`
- Combined view: `jobshead` (UNION of both)

**Benefits:**
- ✅ Complete data isolation
- ✅ No conflicts

**Drawbacks:**
- ❌ Complex schema changes
- ❌ Mobile app needs to query view
- ❌ Duplicate code

---

### Option 3: Source-Aware TRUNCATE (Partial Fix)

**Before TRUNCATE:**
```javascript
// Backup mobile records
CREATE TEMP TABLE mobile_backup AS
SELECT * FROM jobshead WHERE source = 'M';

// TRUNCATE
TRUNCATE jobshead;

// Restore desktop records
INSERT INTO jobshead SELECT * FROM staging;

// Restore mobile records
INSERT INTO jobshead SELECT * FROM mobile_backup;
```

**Benefits:**
- ✅ Preserves mobile data

**Drawbacks:**
- ❌ Still pulls all desktop records
- ❌ Doesn't update changed desktop records in mobile
- ❌ Inefficient (full sync every time)

---

## Recommended Solution

**Implement Option 1: True Incremental Sync**

### Implementation Steps

1. **Track Last Sync Time**
   ```sql
   -- Add to _sync_metadata table
   ALTER TABLE _sync_metadata
   ADD COLUMN last_sync_timestamp TIMESTAMPTZ;
   ```

2. **Query Only Changed Records**
   ```javascript
   const lastSync = await getLastSyncTime(tableName);

   const query = `
     SELECT * FROM ${tableName}
     WHERE (updated_at > $1 OR created_at > $1)
     AND source = 'D'  -- Only desktop records
   `;

   const changedRecords = await sourcePool.query(query, [lastSync]);
   ```

3. **Use UPSERT Instead of TRUNCATE**
   ```javascript
   // Load to staging
   // ... load logic ...

   // UPSERT with source check
   BEGIN;

   INSERT INTO ${targetTable}
   SELECT * FROM ${stagingTable}
   ON CONFLICT (${pkColumn}) DO UPDATE SET
     column1 = EXCLUDED.column1,
     column2 = EXCLUDED.column2,
     ...
     updated_at = EXCLUDED.updated_at
   WHERE ${targetTable}.source = 'D';

   COMMIT;
   ```

4. **Update Last Sync Time**
   ```javascript
   await updateLastSyncTime(tableName, new Date());
   ```

---

## Migration Plan

### Phase 1: Stop Using Current Sync (IMMEDIATE)

**DO NOT run forward sync until fixed!**

```bash
# ❌ DO NOT RUN THESE
# node sync/production/runner-staging.js --mode=full
# node sync/production/runner-staging.js --mode=incremental
```

**Why:** Every run deletes mobile data!

---

### Phase 2: Implement True Incremental (URGENT)

1. Create `engine-staging-v2.js` with UPSERT logic
2. Test on copy of production database
3. Verify mobile records are preserved
4. Replace `engine-staging.js`

---

### Phase 3: Add Safeguards

1. **Pre-sync backup of mobile records:**
   ```sql
   CREATE TABLE jobshead_mobile_backup AS
   SELECT * FROM jobshead WHERE source = 'M';
   ```

2. **Post-sync verification:**
   ```sql
   -- Check if mobile records still exist
   SELECT COUNT(*) FROM jobshead WHERE source = 'M';
   ```

3. **Automatic restore if data lost:**
   ```javascript
   const beforeCount = await countMobileRecords('jobshead');
   // ... run sync ...
   const afterCount = await countMobileRecords('jobshead');

   if (afterCount < beforeCount) {
     console.error('MOBILE DATA LOST! Restoring from backup...');
     await restoreFromBackup();
   }
   ```

---

## Temporary Workaround

### Until Fix is Implemented

**Option A: Disable Forward Sync**
```bash
# Only run reverse sync (safe)
node sync/production/reverse-sync-engine.js
```

**Option B: Full Sync + Reverse Restore**
```bash
# 1. Backup mobile data
psql "postgresql://..." -c "
  CREATE TABLE IF NOT EXISTS jobshead_mobile_backup AS
  SELECT * FROM jobshead WHERE source = 'M';
"

# 2. Run forward sync (will delete mobile data)
node sync/production/runner-staging.js --mode=full

# 3. Restore mobile data
psql "postgresql://..." -c "
  INSERT INTO jobshead
  SELECT * FROM jobshead_mobile_backup
  ON CONFLICT (job_id) DO NOTHING;
"
```

**Option C: Increase Reverse Sync Frequency**
```bash
# Run reverse sync every 5 minutes (instead of hourly)
*/5 * * * * node sync/production/reverse-sync-engine.js
```

This reduces the window where mobile data can be lost, but doesn't eliminate the risk!

---

## Testing the Fix

### Test Case 1: Mobile Create + Forward Sync

```sql
-- 1. Create mobile job in Supabase
INSERT INTO jobshead (job_id, client_id, job_name, source)
VALUES (99999, 1, 'Mobile Test Job', 'M');

-- 2. Run forward sync
-- node sync/production/runner-staging.js --mode=incremental

-- 3. Verify mobile job still exists
SELECT * FROM jobshead WHERE job_id = 99999;
-- Expected: 1 row (should NOT be deleted!)
```

### Test Case 2: Desktop Update + Mobile Preserve

```sql
-- 1. Desktop has Job #100
-- 2. Mobile creates Job #200
INSERT INTO jobshead (job_id, ..., source) VALUES (200, ..., 'M');

-- 3. Desktop updates Job #100
-- 4. Run forward sync

-- 5. Verify both exist
SELECT * FROM jobshead WHERE job_id IN (100, 200);
-- Expected: 2 rows (both preserved)
```

### Test Case 3: Conflict Resolution

```sql
-- 1. Desktop has Job #300 (status='Open', updated_at=T1)
-- 2. Mobile updates Job #300 (status='Completed', updated_at=T2, T2 > T1)
-- 3. Desktop updates Job #300 again (status='On Hold', updated_at=T3, T3 > T2)
-- 4. Run forward sync

-- 5. Verify desktop version wins (later timestamp)
SELECT status FROM jobshead WHERE job_id = 300;
-- Expected: 'On Hold' (desktop's later update)
```

---

## Monitoring

### Check for Data Loss

```sql
-- Before sync: count mobile records
SELECT COUNT(*) FROM jobshead WHERE source = 'M';

-- After sync: count mobile records again
SELECT COUNT(*) FROM jobshead WHERE source = 'M';

-- Should be SAME or HIGHER (never lower!)
```

### Alert on Data Loss

```javascript
const beforeSync = await pool.query(`
  SELECT table_name, COUNT(*) as count
  FROM (
    SELECT 'jobshead' as table_name FROM jobshead WHERE source = 'M'
    UNION ALL
    SELECT 'jobtasks' FROM jobtasks WHERE source = 'M'
    -- ... more tables ...
  ) t
  GROUP BY table_name
`);

// Run sync...

const afterSync = await pool.query(/* same query */);

// Compare counts
for (const before of beforeSync.rows) {
  const after = afterSync.rows.find(r => r.table_name === before.table_name);

  if (after.count < before.count) {
    console.error(`🚨 DATA LOSS! ${before.table_name}: ${before.count} → ${after.count}`);
    // Send alert, rollback, restore backup, etc.
  }
}
```

---

## Summary

### Current State
- ❌ **BROKEN:** engine-staging.js deletes mobile data
- ❌ **BROKEN:** Incremental mode ignored (always full sync)
- ❌ **BROKEN:** Bidirectional sync doesn't work
- ⚠️ **RISK:** Every forward sync loses mobile data

### Required Fix
- ✅ Implement true incremental sync (query changed records only)
- ✅ Use UPSERT instead of TRUNCATE (preserve mobile data)
- ✅ Add source='D' check (only update desktop records)
- ✅ Track last sync time per table

### Timeline
- **Immediate:** Stop running forward sync
- **Urgent:** Implement UPSERT-based incremental sync
- **Short-term:** Add data loss monitoring
- **Long-term:** Comprehensive conflict resolution strategy

---

**Document Version:** 1.0
**Last Updated:** 2025-10-30
**Severity:** CRITICAL
**Action Required:** IMMEDIATE

**DO NOT run forward sync until this is fixed!**
