# AGENTS.md - AI Coding Assistant Guide

**For GitHub Copilot, Codex, Cursor, and other AI coding assistants**

This file contains critical rules and patterns for the PowerCA Mobile project. **READ THIS FIRST** before generating any code or suggesting changes.

---

## ✅ **CRITICAL FIX IMPLEMENTED!** ✅

**Sync engine is now SAFE for bidirectional sync with mobile data preservation!**

### What Was Fixed
The sync engine previously deleted mobile data with `TRUNCATE TABLE`. This is now **FIXED** with UPSERT logic.

### Changes
- ✅ Replaced `TRUNCATE + INSERT` with `INSERT ON CONFLICT DO UPDATE`
- ✅ Only updates `source='D'` records (desktop)
- ✅ Preserves `source='M'` records (mobile)
- ✅ Added incremental mode support

### NOW SAFE TO RUN
```bash
# ✅ Forward sync (preserves mobile data)
node sync/production/runner-staging.js --mode=full
node sync/production/runner-staging.js --mode=incremental

# ✅ Reverse sync (INSERT-only)
node sync/production/reverse-sync-engine.js

# ✅ Initialize metadata (run once)
node scripts/create-sync-metadata-table.js
```

**See:** [`docs/CRITICAL-STAGING-FLAW.md`](docs/CRITICAL-STAGING-FLAW.md) for complete fix details.

---

## 🚨 CRITICAL RULES - DO NOT VIOLATE

### RULE 1: NEVER Clear Production Tables Directly

**❌ FORBIDDEN PATTERNS:**
```javascript
// DO NOT USE THESE PATTERNS
await client.query('TRUNCATE TABLE jobshead');
await client.query('DELETE FROM jobshead');
// Then insert data...
```

**Why forbidden:** If sync fails mid-way, production data is LOST.

**✅ REQUIRED PATTERN: Use Staging Tables + UPSERT**
```javascript
// ALWAYS use this pattern for production syncs
await client.query('CREATE TEMP TABLE jobshead_staging (LIKE jobshead)');
// Load all data to staging
for (const record of records) {
  await client.query('INSERT INTO jobshead_staging VALUES (...)');
}
// Atomic UPSERT (preserves mobile data)
await client.query('BEGIN');
await client.query(`
  INSERT INTO jobshead SELECT * FROM jobshead_staging
  ON CONFLICT (job_id) DO UPDATE SET
    [columns] = EXCLUDED.[columns]
  WHERE jobshead.source = 'D' OR jobshead.source IS NULL
`);
await client.query('COMMIT');
// Mobile records (source='M') are PRESERVED! ✅
```

**Use these scripts ONLY:**
- `sync/runner-staging.js` ✅
- `sync/engine-staging.js` ✅

**NEVER use these scripts in production:**
- `sync/runner-optimized.js` ❌
- `sync/sync-missing-jobs.js` ❌
- Any script with `TRUNCATE` before loading staging ❌

---

### RULE 2: Skip Auto-Increment Columns in INSERT

**❌ WRONG:**
```javascript
INSERT INTO taskchecklist (tc_id, job_id, task_name)
VALUES (NULL, 123, 'Task 1')  // ❌ tc_id is auto-increment!
```

**✅ CORRECT:**
```javascript
// Skip tc_id - let PostgreSQL generate it
INSERT INTO taskchecklist (job_id, task_name)
VALUES (123, 'Task 1')  // ✅ tc_id auto-generated
```

**Auto-increment columns to skip:**
- `taskchecklist.tc_id`
- Any column with `DEFAULT nextval('...')`

**Code pattern:**
```javascript
const AUTO_INCREMENT_COLUMNS = ['tc_id'];
const columns = Object.keys(record).filter(col =>
  !AUTO_INCREMENT_COLUMNS.includes(col)
);
const query = `INSERT INTO table (${columns.join(',')}) VALUES (...)`;
```

---

### RULE 3: Handle Missing Foreign Keys

**Context:** Desktop PostgreSQL has NO FK constraints. Data contains:
- Orphaned records (jobs with deleted clients)
- Invalid references (client_id=500 doesn't exist)
- NULL values (con_id=0 or NULL)

**❌ DON'T assume FK constraints exist:**
```javascript
// This will fail on 16% of jobs
INSERT INTO jobshead (job_id, client_id) VALUES (1, 500);
// Error: violates foreign key constraint "jobshead_client_id_fkey"
```

**✅ DO one of these:**

**Option A: Remove FK constraint (chosen approach)**
```sql
ALTER TABLE jobshead DROP CONSTRAINT IF EXISTS jobshead_client_id_fkey;
```

**Option B: Pre-filter invalid records**
```javascript
const validClientIds = new Set(await getValidClientIds());
const validRecords = records.filter(r => validClientIds.has(r.client_id));
```

**Removed FK constraints:**
- `jobshead.client_id` → climaster
- `jobshead.con_id` → conmaster
- `jobtasks.task_id` → taskmaster
- `jobtasks.client_id` (made nullable)
- `taskchecklist.job_id` → jobshead
- `reminder.client_id` → climaster
- `remdetail.staff_id` → mbstaff

---

### RULE 4: Always Use Transactions for Multi-Step Operations

**❌ WRONG:**
```javascript
await client.query('DELETE FROM jobtasks');
await client.query('DELETE FROM jobshead');  // If this fails, jobtasks is empty!
```

**✅ CORRECT:**
```javascript
await client.query('BEGIN');
try {
  await client.query('DELETE FROM jobtasks');
  await client.query('DELETE FROM jobshead');
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');  // Restore both tables
  throw error;
}
```

---

### RULE 5: Respect FK Dependency Order

**When deleting/truncating tables with FK relationships:**

**❌ WRONG ORDER:**
```javascript
await client.query('TRUNCATE jobshead');  // ❌ Fails! jobtasks references it
await client.query('TRUNCATE jobtasks');
```

**✅ CORRECT ORDER (child before parent):**
```javascript
await client.query('TRUNCATE jobtasks');   // Child first
await client.query('TRUNCATE jobshead');   // Parent second
```

**Dependency hierarchy:**
```
jobtasks, taskchecklist, workdiary → jobshead → climaster, mbstaff
remdetail → reminder → mbstaff, climaster
climaster, mbstaff → orgmaster, locmaster, conmaster
```

---

## 🔧 Code Patterns

### Pattern 1: Safe Staging Table Sync

```javascript
async function syncTableSafe(tableName, records) {
  const client = await pool.connect();

  try {
    // 1. Create staging table
    await client.query(`
      CREATE TEMP TABLE ${tableName}_staging
      (LIKE ${tableName} INCLUDING DEFAULTS)
      ON COMMIT DROP
    `);

    // 2. Load data to staging
    for (const record of records) {
      const columns = Object.keys(record).join(',');
      const values = Object.values(record);
      const placeholders = values.map((_, i) => `$${i + 1}`).join(',');

      await client.query(
        `INSERT INTO ${tableName}_staging (${columns}) VALUES (${placeholders})`,
        values
      );
    }

    // 3. Atomic swap
    await client.query('BEGIN');
    await client.query(`TRUNCATE ${tableName} CASCADE`);
    await client.query(`INSERT INTO ${tableName} SELECT * FROM ${tableName}_staging`);
    await client.query('COMMIT');

    console.log(`✅ Synced ${records.length} records to ${tableName}`);

  } catch (error) {
    await client.query('ROLLBACK');
    console.error(`❌ Sync failed: ${error.message}`);
    throw error;
  } finally {
    client.release();
  }
}
```

---

### Pattern 2: Skip Auto-Increment Columns

```javascript
function prepareInsert(tableName, record) {
  // List of auto-increment columns by table
  const AUTO_INCREMENT = {
    'taskchecklist': ['tc_id'],
    // Add more as discovered
  };

  const skipColumns = AUTO_INCREMENT[tableName] || [];
  const columns = Object.keys(record).filter(col => !skipColumns.includes(col));
  const values = columns.map(col => record[col]);
  const placeholders = columns.map((_, i) => `$${i + 1}`).join(',');

  return {
    query: `INSERT INTO ${tableName} (${columns.join(',')}) VALUES (${placeholders})`,
    values
  };
}

// Usage
const { query, values } = prepareInsert('taskchecklist', record);
await client.query(query, values);
```

---

### Pattern 3: Pre-Validate Foreign Keys

```javascript
async function loadFKCache(client) {
  const cache = {
    validClientIds: new Set(),
    validStaffIds: new Set(),
    validJobIds: new Set(),
  };

  // Load valid client IDs
  const clients = await client.query('SELECT client_id FROM climaster');
  clients.rows.forEach(row => cache.validClientIds.add(row.client_id));

  // Load valid staff IDs
  const staff = await client.query('SELECT staff_id FROM mbstaff');
  staff.rows.forEach(row => cache.validStaffIds.add(row.staff_id));

  return cache;
}

function validateRecord(record, fkCache) {
  if (record.client_id && !fkCache.validClientIds.has(record.client_id)) {
    return { valid: false, reason: `Invalid client_id: ${record.client_id}` };
  }

  if (record.staff_id && !fkCache.validStaffIds.has(record.staff_id)) {
    return { valid: false, reason: `Invalid staff_id: ${record.staff_id}` };
  }

  return { valid: true };
}

// Usage
const fkCache = await loadFKCache(client);
const validRecords = records.filter(record => {
  const validation = validateRecord(record, fkCache);
  if (!validation.valid) {
    console.warn(`Skipping record: ${validation.reason}`);
  }
  return validation.valid;
});
```

---

### Pattern 4: Proper Transaction Handling

```javascript
async function safeMultiTableSync(tables) {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    await client.query('SET CONSTRAINTS ALL DEFERRED');

    for (const [tableName, data] of Object.entries(tables)) {
      await client.query(`TRUNCATE ${tableName} CASCADE`);

      for (const record of data) {
        const { query, values } = prepareInsert(tableName, record);
        await client.query(query, values);
      }

      console.log(`✓ Synced ${tableName}: ${data.length} records`);
    }

    await client.query('COMMIT');
    console.log('✅ All tables synced successfully');

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Sync failed, rolled back all changes');
    throw error;
  } finally {
    client.release();
  }
}
```

---

### Pattern 5: Nullable Columns Check

```javascript
async function makeColumnNullable(client, tableName, columnName) {
  try {
    // Check if column exists and is NOT NULL
    const result = await client.query(`
      SELECT is_nullable
      FROM information_schema.columns
      WHERE table_name = $1 AND column_name = $2
    `, [tableName, columnName]);

    if (result.rows.length > 0 && result.rows[0].is_nullable === 'NO') {
      console.log(`Making ${tableName}.${columnName} nullable...`);
      await client.query(`
        ALTER TABLE ${tableName}
        ALTER COLUMN ${columnName} DROP NOT NULL
      `);
      console.log(`✓ ${tableName}.${columnName} is now nullable`);
    } else {
      console.log(`✓ ${tableName}.${columnName} already nullable`);
    }
  } catch (error) {
    console.error(`Failed to make column nullable: ${error.message}`);
    throw error;
  }
}

// Usage
await makeColumnNullable(client, 'jobtasks', 'client_id');
```

---

## 📋 Quick Reference

### Safe Scripts to Use

```bash
# Full sync (production-safe)
node sync/runner-staging.js --mode=full

# Incremental sync (production-safe)
node sync/runner-staging.js --mode=incremental

# Reverse sync (mobile → desktop)
node sync/reverse-sync-engine.js

# Targeted table sync (taskchecklist with auto-increment handling)
node sync/sync-taskchecklist.js
```

### Unsafe Scripts (Development Only)

```bash
# ⚠️ These clear data first - use ONLY in dev/test
node sync/runner-optimized.js --mode=full
node sync/sync-missing-jobs.js
```

---

### Database Connections

**Desktop PostgreSQL:**
```javascript
{
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.DESKTOP_DB_PASSWORD
}
```

**Supabase Cloud:**
```javascript
{
  host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
}
```

---

### Key Tables and Relationships

**Master Tables (sync full):**
- `orgmaster` (2 records)
- `locmaster` (1 record)
- `conmaster` (4 records)
- `climaster` (726 records)
- `mbstaff` (16 records)

**Transaction Tables (sync incremental):**
- `jobshead` (24,568 records) → references climaster, mbstaff
- `jobtasks` (64,711 records) → references jobshead, mbstaff
- `taskchecklist` (2,894 records) → references jobshead (FK removed)
- `workdiary` → references jobshead, mbstaff
- `reminder` (132 records) → references mbstaff
- `remdetail` (39 records) → references reminder

**Auto-Increment PKs:**
- `taskchecklist.tc_id` (bigserial)

---

## 🧪 Testing Patterns

### Before Sync

```bash
# Check source record count
psql -h localhost -p 5433 -d enterprise_db -c "SELECT COUNT(*) FROM jobshead;"

# Check target record count
psql "postgresql://postgres:[password]@db.jacqfogzgzvbjeizljqf.supabase.co:5432/postgres" -c "SELECT COUNT(*) FROM jobshead;"
```

### After Sync

```bash
# Verify record counts match
node scripts/verify-all-tables.js

# Check for FK violations
grep "foreign key constraint" sync.log

# Check for orphaned records (if FK removed)
psql "postgresql://..." -c "
  SELECT COUNT(*) FROM jobshead j
  LEFT JOIN climaster c ON j.client_id = c.client_id
  WHERE c.client_id IS NULL;
"
```

---

## 🚫 Common Mistakes to Avoid

### Mistake 1: Not Using Staging Tables
```javascript
// ❌ WRONG - Data loss risk
await client.query('TRUNCATE jobshead');
for (const job of jobs) {
  await client.query('INSERT INTO jobshead VALUES (...)');
}

// ✅ CORRECT - Use staging
// See Pattern 1 above
```

### Mistake 2: Including Auto-Increment in INSERT
```javascript
// ❌ WRONG
const columns = Object.keys(record);  // Includes tc_id
INSERT INTO taskchecklist (tc_id, job_id, ...) VALUES (NULL, ...)

// ✅ CORRECT
const columns = Object.keys(record).filter(col => col !== 'tc_id');
INSERT INTO taskchecklist (job_id, ...) VALUES (...)
```

### Mistake 3: Assuming FK Constraints Exist
```javascript
// ❌ WRONG - Will fail on 16% of jobs
const jobs = await sourceDB.query('SELECT * FROM jobshead');
await targetDB.bulkInsert('jobshead', jobs);

// ✅ CORRECT - Pre-filter or remove FK
const validClientIds = await getValidClientIds();
const validJobs = jobs.filter(j => validClientIds.has(j.client_id));
await targetDB.bulkInsert('jobshead', validJobs);
```

### Mistake 4: Wrong Delete Order
```javascript
// ❌ WRONG - FK violation
await client.query('DELETE FROM jobshead');
await client.query('DELETE FROM jobtasks');

// ✅ CORRECT - Child before parent
await client.query('DELETE FROM jobtasks');
await client.query('DELETE FROM jobshead');
```

### Mistake 5: No Transaction for Multi-Step Ops
```javascript
// ❌ WRONG - Partial state if second delete fails
await client.query('DELETE FROM jobtasks');
await client.query('DELETE FROM jobshead');  // Fails!

// ✅ CORRECT - Atomic with transaction
await client.query('BEGIN');
await client.query('DELETE FROM jobtasks');
await client.query('DELETE FROM jobshead');
await client.query('COMMIT');
```

---

## 📚 Related Documentation

- [`CLAUDE.md`](CLAUDE.md) - Comprehensive project guide (for Claude AI)
- [`docs/staging-table-sync.md`](docs/staging-table-sync.md) - Staging pattern explained
- [`docs/SYNC_GUIDE.md`](docs/SYNC_GUIDE.md) - Troubleshooting guide
- [`docs/BIDIRECTIONAL-SYNC-STRATEGY.md`](docs/BIDIRECTIONAL-SYNC-STRATEGY.md) - Sync architecture
- [`docs/Mobile App Scaffold/flutter_project_structure.md`](docs/Mobile%20App%20Scaffold/flutter_project_structure.md) - Flutter app structure

---

## 🎯 Quick Decision Tree

**Need to sync data to Supabase?**
```
┌─ Production? ──────────────────────────────────────────┐
│                                                         │
│  YES → Use sync/runner-staging.js                     │
│        (Staging tables protect production data)        │
│                                                         │
│  NO → Can use sync/runner-optimized.js                │
│       (Faster but clears data first)                   │
└─────────────────────────────────────────────────────────┘

┌─ Table has auto-increment PK? ────────────────────────┐
│                                                         │
│  YES → Skip the auto-increment column in INSERT       │
│        (e.g., skip tc_id for taskchecklist)           │
│                                                         │
│  NO → Include all columns                             │
└─────────────────────────────────────────────────────────┘

┌─ FK constraint violations? ───────────────────────────┐
│                                                         │
│  YES → Option A: Remove FK constraint                 │
│        Option B: Pre-filter invalid records           │
│                                                         │
│  NO → Sync as-is                                      │
└─────────────────────────────────────────────────────────┘

┌─ Multiple related tables? ────────────────────────────┐
│                                                         │
│  YES → Use transaction + clear in FK dependency order │
│        (Child tables before parent tables)            │
│                                                         │
│  NO → Single table sync is safe                       │
└─────────────────────────────────────────────────────────┘
```

---

## ⚙️ Environment Variables Required

```bash
# Desktop PostgreSQL
DESKTOP_DB_HOST=localhost
DESKTOP_DB_PORT=5433
DESKTOP_DB_NAME=enterprise_db
DESKTOP_DB_USER=postgres
DESKTOP_DB_PASSWORD=your_password

# Supabase Cloud
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=your_password

# Sync Configuration
BATCH_SIZE=1000
STATEMENT_TIMEOUT=600000
```

---

## 🔍 Debugging Tips

### Check Active Syncs
```bash
# List running Node processes
ps aux | grep "node sync"

# Check PostgreSQL connections
psql "postgresql://..." -c "SELECT pid, state, query FROM pg_stat_activity WHERE state = 'active';"
```

### Monitor Sync Progress
```bash
# Follow log file
tail -f sync.log

# Count records in real-time
watch -n 5 "psql 'postgresql://...' -c 'SELECT COUNT(*) FROM jobshead;'"
```

### Check for Errors
```bash
# FK constraint errors
grep "foreign key constraint" sync.log

# NOT NULL constraint errors
grep "violates not-null constraint" sync.log

# Connection errors
grep "timeout\|ECONNREFUSED\|ETIMEDOUT" sync.log
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-30
**Target Audience:** GitHub Copilot, Codex, Cursor, and other AI coding assistants
**Purpose:** Prevent data loss and enforce safe coding patterns

**Remember: When in doubt, use staging tables!** 🚀
