# Development Sync Scripts

**⚠️ UNSAFE FOR PRODUCTION - DEVELOPMENT/TESTING ONLY**

These scripts directly truncate/delete production tables before inserting data. **If the sync fails midway, your production data will be LOST!**

---

## ⚠️ WARNING

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   🚨 DO NOT USE THESE SCRIPTS IN PRODUCTION! 🚨        │
│                                                         │
│   These scripts clear data FIRST, then insert.         │
│   If sync fails → DATA LOST!                           │
│                                                         │
│   Use sync/production/ scripts instead!                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Why These Scripts Exist

These scripts were created during development before we implemented the safe staging table pattern. They are kept here for:

1. **Development/Testing** - Quick syncs on dev databases where data loss is acceptable
2. **Learning** - Understanding the unsafe pattern vs safe pattern
3. **Reference** - Historical code for troubleshooting
4. **One-off Operations** - Specific targeted syncs (with caution)

**But NEVER use them on production Supabase!**

---

## Scripts in This Folder

### Unsafe Sync Scripts (DO NOT USE IN PRODUCTION)

#### `runner-optimized.js` ❌
**What it does:** Clears tables, then syncs data
**Problem:** If sync fails, tables are EMPTY
**Usage:** Development only
```bash
# ⚠️ ONLY use on dev/test databases!
node sync/development/runner-optimized.js --mode=full
```

#### `engine-optimized.js` ❌
**What it does:** Core sync engine without staging tables
**Problem:** No rollback support, data loss risk
**Usage:** Referenced by runner-optimized.js

#### `sync-missing-jobs.js` ❌
**What it does:** Clears jobshead and jobtasks, then syncs all records
**Problem:** Production data deleted before sync starts!
```javascript
// DANGER ZONE:
await supabasePool.query(`DELETE FROM jobtasks`);
await supabasePool.query(`DELETE FROM jobshead`);
// If connection drops here → ALL JOBS LOST!
```

---

### Legacy/Experimental Scripts

#### `runner.js`
**Status:** Superseded by runner-staging.js
**Purpose:** Original sync runner (no staging)

#### `engine.js`
**Status:** Superseded by engine-staging.js
**Purpose:** Original sync engine (no staging)

#### `sync-remaining-tables.js`
**Purpose:** One-off script for syncing specific tables
**Usage:** Targeted syncs during development

#### `simple-sync-remaining.js`
**Purpose:** Simplified sync for testing
**Usage:** Quick dev syncs

#### `sync-reminder-tables.js`
**Purpose:** Sync reminder tables only
**Usage:** Testing reminder sync

#### `sync-reminder-only.js`
**Purpose:** Another reminder-specific sync
**Usage:** Development testing

---

### Utility Scripts (SAFE)

#### `sync-taskchecklist.js` ✅
**Purpose:** Syncs taskchecklist with proper auto-increment handling
**Safe?:** Clears taskchecklist first, but handles tc_id correctly

**Usage:**
```bash
# Safe for taskchecklist specifically
node sync/development/sync-taskchecklist.js
```

**What makes it special:**
- Skips `tc_id` column (auto-increment)
- Lets PostgreSQL generate IDs via sequence
- Handles NULL tc_id from desktop DB

**Code pattern:**
```javascript
const skipColumns = ['tc_id'];  // Skip auto-increment
const columns = Object.keys(row).filter(col => !skipColumns.includes(col));
```

---

## When to Use Development Scripts

### ✅ SAFE TO USE:

1. **Local development database**
   ```bash
   # Dev database you can recreate anytime
   node sync/development/runner-optimized.js --mode=full
   ```

2. **Testing environment**
   ```bash
   # Test instance of Supabase
   SUPABASE_DB_HOST=test.supabase.co node sync/development/runner-optimized.js --mode=full
   ```

3. **One-off targeted operations** (with extreme caution)
   ```bash
   # Syncing single non-critical table
   # node sync/development/sync-taskchecklist.js
   ```

---

### ❌ NEVER USE FOR:

1. **Production Supabase Cloud**
   ```bash
   # ❌ NEVER do this!
   # node sync/development/runner-optimized.js --mode=full
   # → Will wipe production data!
   ```

2. **Scheduled syncs**
   ```bash
   # ❌ NEVER schedule these!
   # 0 * * * * node sync/development/runner-optimized.js
   ```

3. **Any operation where data loss is unacceptable**

---

## What Went Wrong (Historical Context)

### Incident: 2025-10-30 05:22:47

**What happened:**
1. Ran `runner-optimized.js` with `--mode=full`
2. Script executed `TRUNCATE climaster`
3. Connection dropped during data insert
4. **Result:** climaster table was EMPTY (726 clients lost!)

**Root cause:**
```javascript
// Unsafe pattern
await client.query('TRUNCATE climaster');  // ← DATA DELETED!
// Connection drops here...
for (const client of clients) {
  await client.query('INSERT INTO climaster ...');  // ← Never executed!
}
// Result: Empty table!
```

**Lesson learned:**
Always use staging tables for production syncs!

---

## Migration to Safe Scripts

If you need to do what these scripts do, use the safe alternatives:

| Unsafe Script | Safe Alternative | Location |
|---------------|-----------------|----------|
| `runner-optimized.js` | `runner-staging.js` | `sync/production/` |
| `engine-optimized.js` | `engine-staging.js` | `sync/production/` |
| `sync-missing-jobs.js` | Manual staged sync | (don't use at all) |

---

## Comparison: Unsafe vs Safe

### Unsafe Pattern (This Folder)

```javascript
// ❌ UNSAFE - Data cleared before insert
async function syncTable(table, records) {
  await client.query(`TRUNCATE ${table}`);  // ← DATA GONE!

  for (const record of records) {
    await client.query(`INSERT INTO ${table} ...`);  // ← If fails, data lost!
  }
}
```

**Risk window:** From TRUNCATE until last INSERT completes (could be 1-2 hours!)

---

### Safe Pattern (sync/production/)

```javascript
// ✅ SAFE - Staging table protects production
async function syncTableSafe(table, records) {
  // 1. Load to staging (production untouched)
  await client.query(`CREATE TEMP TABLE ${table}_staging ...`);
  for (const record of records) {
    await client.query(`INSERT INTO ${table}_staging ...`);
  }

  // 2. Atomic swap (5 seconds of risk)
  await client.query('BEGIN');
  await client.query(`TRUNCATE ${table}`);
  await client.query(`INSERT INTO ${table} SELECT * FROM ${table}_staging`);
  await client.query('COMMIT');  // ← All or nothing!
}
```

**Risk window:** Only during COMMIT (5 seconds, with automatic rollback!)

---

## If You Must Use These Scripts...

### Pre-Flight Checklist

- [ ] Confirm this is NOT production Supabase
- [ ] Backup created (`pg_dump` or Supabase dashboard)
- [ ] Tested connection to target database
- [ ] Verified you can restore from backup
- [ ] Understand data will be LOST if sync fails
- [ ] Have recovery plan ready
- [ ] Monitoring tools in place (watch for errors)

### Running Safely (Development Only)

```bash
# 1. Backup first!
pg_dump -h dev-db.supabase.co -U postgres -d postgres > backup-$(date +%Y%m%d).sql

# 2. Run sync
node sync/development/runner-optimized.js --mode=full

# 3. If it fails, restore:
psql -h dev-db.supabase.co -U postgres -d postgres < backup-*.sql
```

---

## Learning from These Scripts

### Good Patterns to Extract

**1. FK Pre-validation:**
```javascript
// From engine-optimized.js
async function loadFKCache() {
  const validClientIds = new Set();
  const clients = await pool.query('SELECT client_id FROM climaster');
  clients.rows.forEach(row => validClientIds.add(row.client_id));
  return validClientIds;
}
```

**2. Batch Processing:**
```javascript
// From runner-optimized.js
const BATCH_SIZE = 1000;
for (let i = 0; i < records.length; i += BATCH_SIZE) {
  const batch = records.slice(i, i + BATCH_SIZE);
  await processBatch(batch);
}
```

**3. Progress Reporting:**
```javascript
// From sync-missing-jobs.js
if (processed % 1000 === 0) {
  console.log(`⏳ Processed ${processed}/${total} records...`);
}
```

**4. Error Retry Logic:**
```javascript
// From engine-optimized.js
for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
  try {
    await insertRecord(record);
    break;
  } catch (error) {
    if (attempt === MAX_RETRIES) throw error;
    await sleep(RETRY_DELAY * attempt);
  }
}
```

---

## Refactoring Guide

If you want to make an unsafe script safe:

**Before (Unsafe):**
```javascript
async function syncTable(table, data) {
  await client.query(`TRUNCATE ${table}`);
  for (const row of data) {
    await client.query(`INSERT INTO ${table} ...`);
  }
}
```

**After (Safe):**
```javascript
async function syncTableSafe(table, data) {
  // 1. Create staging
  await client.query(`
    CREATE TEMP TABLE ${table}_staging
    (LIKE ${table} INCLUDING DEFAULTS)
    ON COMMIT DROP
  `);

  // 2. Load staging
  for (const row of data) {
    await client.query(`INSERT INTO ${table}_staging ...`);
  }

  // 3. Atomic swap
  await client.query('BEGIN');
  await client.query(`TRUNCATE ${table}`);
  await client.query(`INSERT INTO ${table} SELECT * FROM ${table}_staging`);
  await client.query('COMMIT');
}
```

**Key changes:**
- Add staging table creation
- Load data to staging, not production
- Wrap TRUNCATE + INSERT in transaction
- Production only modified during COMMIT

---

## Testing Methodology

**How to test these scripts safely:**

1. **Use Docker PostgreSQL:**
```bash
# Spin up test database
docker run -d --name test-postgres -e POSTGRES_PASSWORD=test -p 5434:5432 postgres:17

# Test unsafe script
SUPABASE_DB_HOST=localhost SUPABASE_DB_PORT=5434 node sync/development/runner-optimized.js --mode=full

# Kill mid-sync to simulate failure
kill -9 $(pgrep -f runner-optimized)

# Check what happened
psql -h localhost -p 5434 -U postgres -c "SELECT COUNT(*) FROM jobshead;"
# Result: Partial data or empty table! ❌
```

2. **Compare with safe script:**
```bash
# Same test with safe script
SUPABASE_DB_HOST=localhost SUPABASE_DB_PORT=5434 node sync/production/runner-staging.js --mode=full

# Kill mid-sync
kill -9 $(pgrep -f runner-staging)

# Check what happened
psql -h localhost -p 5434 -U postgres -c "SELECT COUNT(*) FROM jobshead;"
# Result: Original data intact (or fully synced)! ✅
```

---

## Questions?

**Q: Why keep these scripts if they're unsafe?**
A: Learning, reference, and development testing. They show what NOT to do in production.

**Q: Can I use these for small tables?**
A: Even for small tables, use safe scripts. The risk isn't worth it.

**Q: What if I need the speed?**
A: Safe scripts are just as fast. Staging adds negligible overhead (~5%).

**Q: I accidentally ran an unsafe script on production!**
A: Immediately restore from backup:
```bash
# Supabase dashboard → Database → Backups → Restore
# OR if you have pg_dump:
psql "postgresql://..." < backup.sql
```

---

## Summary

✅ **DO:**
- Use these for learning and development
- Test on disposable databases only
- Extract good patterns (FK validation, batching)
- Migrate to safe alternatives

❌ **DON'T:**
- Use on production Supabase
- Schedule as cron jobs
- Run without backups
- Assume they're "fine" because they worked before

---

**Remember:** One failed sync can wipe your entire production database. Always use `sync/production/` scripts for any operation where data loss is unacceptable!

**When in doubt, use staging tables!** 🚀

---

**See also:**
- Production scripts: [`../production/README.md`](../production/README.md)
- Safe patterns: [`../../docs/staging-table-sync.md`](../../docs/staging-table-sync.md)
- Full guide: [`../../CLAUDE.md`](../../CLAUDE.md)
