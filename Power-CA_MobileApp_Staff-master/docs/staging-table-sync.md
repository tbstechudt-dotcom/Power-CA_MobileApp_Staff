# Safe Sync Pattern: Staging Tables

## The Problem

The original sync pattern was **not safe for interruptions**:

```javascript
// UNSAFE PATTERN
1. TRUNCATE production_table;  ← DATA DELETED
2. INSERT batch 1...            ← If connection fails here...
3. INSERT batch 2...            ← ...data is LOST!
4. INSERT batch 3...
```

**What happens if sync fails midway?**
- Connection drops
- Network error
- Process killed
- Server crash

**Result:** Production table is left **empty** or **partially filled**!

This is exactly what happened on 2025-10-30 at 05:22:47 when climaster was truncated but connection failed before data could be reloaded.

## The Solution: Staging Tables

The staging table pattern ensures **atomicity** - the sync either fully succeeds or production data remains untouched:

```javascript
// SAFE PATTERN
1. CREATE TEMP TABLE staging (LIKE production);
2. INSERT all data → staging;       ← Can fail safely
3. BEGIN TRANSACTION;
4.   TRUNCATE production;
5.   INSERT INTO production FROM staging;
6. COMMIT;                          ← Atomic moment!
7. DROP staging;
```

**What happens if sync fails?**
- Steps 1-2 fail: Staging table affected, production untouched ✅
- Steps 4-5 fail: ROLLBACK restores production data ✅
- Connection drops: Transaction rolls back, production untouched ✅

## How It Works

### Step-by-Step Process

#### Step 1: Create Staging Table
```sql
CREATE TEMP TABLE climaster_staging
(LIKE climaster INCLUDING DEFAULTS)
ON COMMIT DROP;
```

- Creates temporary table with same structure as production
- `ON COMMIT DROP` means it auto-cleans up
- No foreign key constraints (loads faster)

#### Step 2: Load Data into Staging
```javascript
for (const record of validRecords) {
  await client.query(`
    INSERT INTO climaster_staging VALUES (...)
  `);
}
```

- All data loaded to staging table
- **If this fails:** Staging dropped, production untouched
- **No risk** to production data

#### Step 3: Atomic Swap
```sql
BEGIN;
  TRUNCATE climaster CASCADE;
  INSERT INTO climaster SELECT * FROM climaster_staging;
COMMIT;
```

- Both operations in **single transaction**
- **If TRUNCATE succeeds but INSERT fails:** ROLLBACK restores data
- **If connection drops:** ROLLBACK restores data
- **Only on COMMIT:** New data becomes visible

#### Step 4: Cleanup
```sql
DROP TABLE climaster_staging;
```

- Staging table removed (happens automatically with `ON COMMIT DROP`)

## Benefits

### 1. Atomic Operations
- **All or nothing:** Either complete sync succeeds or production unchanged
- No partial states
- No empty tables

### 2. Connection Safety
- Connection drops don't corrupt data
- Transactions roll back automatically
- Production data protected

### 3. Validation Before Commit
- Can validate data in staging before swapping
- Can run checks, counts, etc.
- Only commit if validation passes

### 4. Rollback Support
- If swap fails, ROLLBACK restores original data
- Works at PostgreSQL level (automatic)
- No manual recovery needed

## Performance Comparison

### Original Pattern (Unsafe)
```
Extract (10s) → TRUNCATE (1s) → INSERT batches (60s) = 71s
                                ↑
                        DANGER ZONE: 60 seconds of risk
```

### Staging Pattern (Safe)
```
Extract (10s) → Load Staging (50s) → Atomic Swap (5s) = 65s
                                      ↑
                              DANGER ZONE: 5 seconds
```

**Result:** Similar performance, but only 5 seconds of risk instead of 60!

## Usage

### Running Safe Sync

```bash
# Full sync (all tables)
node sync/runner-staging.js --mode=full

# Incremental sync (transactional tables only)
node sync/runner-staging.js --mode=incremental
```

### Integration Example

```javascript
const StagingSyncEngine = require('./sync/engine-staging');

const engine = new StagingSyncEngine();

try {
  await engine.syncAll('full');
  console.log('✅ Sync completed!');
} catch (error) {
  console.error('❌ Sync failed, but production data is safe!');
}
```

## Error Handling

### Scenario 1: Staging Load Fails
```
CREATE staging ✅
LOAD data → staging ❌  (connection drops)

Result: Staging dropped, production untouched ✅
```

### Scenario 2: Atomic Swap Fails
```
CREATE staging ✅
LOAD data → staging ✅
BEGIN transaction ✅
TRUNCATE production ✅
INSERT from staging ❌  (error occurs)
ROLLBACK ✅

Result: Production data restored ✅
```

### Scenario 3: Connection Drops During Swap
```
CREATE staging ✅
LOAD data → staging ✅
BEGIN transaction ✅
TRUNCATE production ✅
<connection drops> ❌
PostgreSQL auto-ROLLBACK ✅

Result: Production data restored ✅
```

## Comparison with Other Patterns

### Pattern 1: Direct Insert (Original - UNSAFE)
```javascript
TRUNCATE table;
for (batch) { INSERT batch; }
```
**Pros:** Simple
**Cons:** Not atomic, data loss risk

### Pattern 2: Single Transaction (Better)
```javascript
BEGIN;
TRUNCATE table;
for (batch) { INSERT batch; }
COMMIT;
```
**Pros:** Atomic
**Cons:** Long lock time, affects concurrent reads

### Pattern 3: Staging Table (BEST - Current)
```javascript
LOAD → staging;
BEGIN;
  TRUNCATE table;
  INSERT FROM staging;
COMMIT;
```
**Pros:** Atomic, short lock, safe
**Cons:** Slightly more complex

### Pattern 4: Table Swap (Alternative)
```javascript
CREATE new_table;
LOAD → new_table;
BEGIN;
  ALTER TABLE table RENAME TO old_table;
  ALTER TABLE new_table RENAME TO table;
COMMIT;
DROP old_table;
```
**Pros:** Zero downtime, instant swap
**Cons:** Requires schema changes, more complex

## When to Use Each Pattern

| Scenario | Recommended Pattern |
|----------|-------------------|
| Small tables (<1000 rows) | Single Transaction |
| Large tables (>1000 rows) | **Staging Table** ✅ |
| Zero downtime required | Table Swap |
| Simple one-time sync | Direct Insert (if risk acceptable) |
| Production sync | **Staging Table** ✅ |

## Migration Guide

### From Unsafe to Safe Sync

**Before (unsafe):**
```javascript
const engine = new OptimizedSyncEngine();
await engine.syncAll('full');
```

**After (safe):**
```javascript
const engine = new StagingSyncEngine();
await engine.syncAll('full');
```

That's it! Same API, safer implementation.

## Monitoring

### Check Staging Tables
```sql
-- See active staging tables
SELECT schemaname, tablename
FROM pg_tables
WHERE tablename LIKE '%_staging';
```

### Transaction Status
```sql
-- See active transactions
SELECT pid, state, query
FROM pg_stat_activity
WHERE state = 'active';
```

### Rollback Detection
Look for these messages in logs:
```
- ✓ Transaction committed (atomic swap complete)  ← Success
- ✗ Atomic swap failed, rolling back              ← Rollback occurred
- ✓ Production data restored (unchanged)          ← Rollback completed
```

## Best Practices

### 1. Always Use Staging for Production
```javascript
// ❌ DON'T (unsafe)
await directTruncateAndInsert();

// ✅ DO (safe)
const engine = new StagingSyncEngine();
await engine.syncAll('full');
```

### 2. Monitor Disk Space
Staging tables require temporary disk space (2x table size):
```bash
# Check available disk space
df -h /var/lib/postgresql
```

### 3. Set Appropriate Timeouts
```javascript
// Connection config
{
  connectionTimeoutMillis: 30000,     // 30 seconds
  statement_timeout: 600000,          // 10 minutes
  idle_in_transaction_session_timeout: 300000  // 5 minutes
}
```

### 4. Log All Operations
```javascript
console.log('  - Creating staging table...');
console.log('  - Loading data to staging...');
console.log('  - Beginning atomic swap...');
console.log('  - ✓ Swap complete');
```

## Troubleshooting

### Issue: Staging table already exists
```
ERROR: relation "climaster_staging" already exists
```

**Solution:** Use `ON COMMIT DROP` or manually drop:
```sql
DROP TABLE IF EXISTS climaster_staging;
```

### Issue: Disk space exhausted
```
ERROR: could not extend file: No space left on device
```

**Solution:** Free up space or use smaller batches:
```javascript
// Sync tables individually instead of all at once
await engine.syncTableSafe('climaster', 'full');
```

### Issue: Transaction timeout
```
ERROR: canceling statement due to statement timeout
```

**Solution:** Increase timeout:
```sql
SET statement_timeout = '30min';
```

## Technical Details

### Temp Table Behavior
```sql
CREATE TEMP TABLE staging (LIKE table);
```

- Visible only to current session
- Automatically dropped on disconnect
- Not logged in WAL (faster)
- No FK constraints (faster inserts)

### Transaction Isolation
```sql
BEGIN;
SET CONSTRAINTS ALL DEFERRED;
-- Operations here
COMMIT;
```

- FK checks deferred until COMMIT
- Faster bulk operations
- Still guaranteed consistent

### ON COMMIT Options
```sql
ON COMMIT DROP;      -- Table dropped after COMMIT
ON COMMIT DELETE ROWS;  -- Rows deleted after COMMIT
ON COMMIT PRESERVE ROWS;  -- Rows kept (default)
```

We use `DROP` for automatic cleanup.

## Future Enhancements

### 1. Parallel Staging
Load multiple tables to staging in parallel, then swap all at once:
```javascript
await Promise.all([
  loadToStaging('climaster'),
  loadToStaging('jobshead'),
  loadToStaging('jobtasks'),
]);

BEGIN;
  // Swap all tables atomically
COMMIT;
```

### 2. Incremental Staging
For incremental syncs, merge staging with existing data:
```sql
INSERT INTO table
SELECT * FROM staging
ON CONFLICT (id) DO UPDATE SET ...;
```

### 3. Pre-Swap Validation
Add validation before committing:
```javascript
const stagingCount = await getCount('staging');
const expectedCount = sourceData.length;

if (stagingCount !== expectedCount) {
  throw new Error('Data validation failed!');
}
```

## Summary

The **Staging Table Pattern** provides:

✅ **Safety:** Production data protected from failures
✅ **Atomicity:** All-or-nothing guarantees
✅ **Performance:** Similar to unsafe pattern
✅ **Reliability:** Automatic rollback on errors
✅ **Peace of Mind:** Sleep well knowing data is safe!

**Use this for all production syncs going forward.**

---

**Created:** 2025-10-30
**Author:** Claude Code
**Version:** 1.0
