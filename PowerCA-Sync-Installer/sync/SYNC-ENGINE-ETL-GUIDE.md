# PowerCA Mobile - Sync Engine ETL Guide

**Complete Guide to Forward and Reverse Sync**

This document explains how the PowerCA Mobile sync engine uses ETL (Extract, Transform, Load) patterns to synchronize data between the desktop PostgreSQL database and Supabase Cloud.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Forward Sync: Desktop -> Supabase](#forward-sync-desktop--supabase)
3. [Reverse Sync: Supabase -> Desktop](#reverse-sync-supabase--desktop)
4. [ETL Process Breakdown](#etl-process-breakdown)
5. [Configuration](#configuration)
6. [Code Examples](#code-examples)
7. [Advanced Patterns](#advanced-patterns)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### System Components

```
+-------------------------------------------------------------------------+
|                         POWERCA MOBILE SYNC                             |
\-------------------------------------------------------------------------+

+------------------+                                  +------------------+
|  Desktop DB      |                                  |  Supabase Cloud  |
|  (PostgreSQL)    |                                  |  (PostgreSQL)    |
|                  |                                  |                  |
|  Port: 5433      |                                  |  Port: 5432      |
|  DB: enterprise_ |                                  |  DB: postgres    |
|      db          |                                  |                  |
|                  |                                  |                  |
|  +------------+  |                                  |  +------------+  |
|  | climaster  |  |                                  |  | climaster  |  |
|  | jobshead   |  |                                  |  | jobshead   |  |
|  | jobtasks   |  |                                  |  | jobtasks   |  |
|  | ...        |  |                                  |  | ...        |  |
|  \------------+  |                                  |  \------------+  |
|                  |                                  |                  |
|  Source = 'D'    |                                  |  Source = 'D'|'M'|
|  (Desktop data)  |                                  |  (Desktop|Mobile)|
\------------------+                                  \------------------+
         |                                                     ^
         |                                                     |
         |         +-------------------------+               |
         |         |   FORWARD SYNC ENGINE   |               |
         \-------->|   (Desktop -> Supabase)  |---------------+
                   |                         |
                   |  - ETL Process          |
                   |  - Staging Tables       |
                   |  - UPSERT/DELETE+INSERT |
                   |  - Batch Processing     |
                   |  - Data Validation      |
                   \-------------------------+
                             |      ^
                             |      |
                             v      |
                   +-------------------------+
                   |   REVERSE SYNC ENGINE   |
                   |   (Supabase -> Desktop)  |
                   |                         |
                   |  - Pulls mobile data    |
                   |  - Filters source='M'   |
                   |  - INSERT-only          |
                   |  - Preserves desktop    |
                   \-------------------------+
                             |
                             v
                   +-------------------------+
                   |    FLUTTER MOBILE APP   |
                   |                         |
                   |  - Creates records      |
                   |  - Sets source='M'      |
                   |  - Supabase REST API    |
                   \-------------------------+
```

### Data Flow Direction

**Forward Sync (Desktop -> Supabase):**
- Desktop is the source of truth for existing data
- Updates Supabase with latest desktop changes
- Preserves mobile-created records (source='M')
- Runs on schedule or manually

**Reverse Sync (Supabase -> Desktop):**
- Mobile creates new records in Supabase
- Reverse sync pulls mobile data back to desktop
- Only inserts new mobile records
- Doesn't modify existing desktop records

---

## Forward Sync: Desktop -> Supabase

### Overview

Forward sync moves data from the desktop PostgreSQL database to Supabase Cloud using a **safe staging table pattern** with ETL processing.

### Key Features

1. **Staging Tables** - Load data to temporary tables first
2. **Atomic Commits** - All-or-nothing transaction safety
3. **Mobile Data Preservation** - Never overwrites source='M' records
4. **Batch Processing** - 1000 records per batch for performance
5. **Two Sync Modes** - Full (all records) or Incremental (changed only)*
6. **Two Sync Patterns** - UPSERT (desktop PK) or DELETE+INSERT (mobile PK)

*Note: Mobile-PK tables (jobshead, jobtasks, taskchecklist, workdiary) are automatically forced to FULL mode even when incremental is requested to prevent data loss from the DELETE+INSERT pattern.

### File Structure

```
sync/production/
+-- runner-staging.js          # Main entry point
+-- engine-staging.js          # Core sync engine
+-- config.js                  # Configuration
\-- reverse-sync-engine.js     # Reverse sync (covered later)
```

### Running Forward Sync

```bash
# Full sync - sync all records
node sync/production/runner-staging.js --mode=full

# Incremental sync - only changed records (since last sync)
# Note: Mobile-PK tables automatically run in FULL mode for safety
node sync/production/runner-staging.js --mode=incremental
```

### Output Example

```
[SAFE]  SAFE SYNC ENGINE - Staging Table Pattern
   Production data protected from failures!

[INFO] Validating timestamp columns for incremental sync...
[OK] All 15 tables have timestamp columns

============================================================
Starting INCREMENTAL SYNC (STAGING TABLE PATTERN)
Time: 2025-10-31T09:03:58.178Z
============================================================

--- MASTER TABLES (Full Sync) ---

Syncing: climaster -> climaster (full)
  - Extracted 729 records (full sync)
  - Transformed 729 records
  - Filtered 3 invalid records (FK violations)
  - Will sync 726 valid records
  - Creating staging table climaster_staging...
  - [OK] Staging table created
  - Loading data into staging table...
    [...] Loaded 726/726 to staging...
  - [OK] Loaded 726 records to staging table
  - Beginning UPSERT operation (desktop PK table)...
  - [OK] Upserted 726 desktop records (preserved desktop PKs, mobile data untouched)
  - [OK] Transaction committed (UPSERT complete)
  - [OK] Staging table dropped
  [OK] Loaded 726 records to target
  Duration: 0.78s

--- TRANSACTIONAL TABLES (Incremental Sync - with AUTO-FULL for some tables) ---

Syncing: jobshead -> jobshead (requested: incremental, effective: FULL)
  - [WARN]  Forcing FULL sync for jobshead (mobile-only PK table uses DELETE+INSERT)
  - Extracted 24568 records (full sync)
  - Transformed 24568 records
  - Creating staging table jobshead_staging...
  - [OK] Staging table created
  - Loading data into staging table...
    [...] Loaded 1000/24562 to staging...
    [...] Loaded 24000/24562 to staging...
    [...] Loaded 24562/24562 to staging...
  - [OK] Loaded 24562 records to staging table
  - Beginning DELETE+INSERT operation (mobile-only PK table)...
  - [OK] Deleted 24562 desktop records (mobile data preserved)
  - [OK] Inserted 24562 desktop records with fresh mobile PKs
  - [OK] Transaction committed (DELETE+INSERT complete)
  [OK] Loaded 24562 records to target
  Duration: 8.81s

[OK] Sync completed successfully!
```

---

## ETL Process Breakdown

### Extract Phase

**Purpose:** Fetch data from desktop PostgreSQL database

**Code Location:** `sync/production/engine-staging.js` lines 458-507

#### Full Sync Extract

```javascript
// Extract ALL records from source table
sourceData = await this.sourcePool.query(`
  SELECT * FROM ${sourceTableName}
`);

console.log(`  - Extracted ${sourceData.rows.length} records (full sync)`);
```

**Example Output:**
```
- Extracted 729 records (full sync)
```

#### Incremental Sync Extract

```javascript
// Get last sync timestamp from metadata table
const lastSyncResult = await this.targetPool.query(`
  SELECT last_sync_timestamp
  FROM _sync_metadata
  WHERE table_name = $1
`, [targetTableName]);

const lastSync = lastSyncResult.rows[0]?.last_sync_timestamp || '1970-01-01';

// Extract only CHANGED records since last sync
sourceData = await this.sourcePool.query(`
  SELECT * FROM ${sourceTableName}
  WHERE updated_at > $1 OR created_at > $1
  ORDER BY COALESCE(updated_at, created_at)
`, [lastSync]);

console.log(`  - Extracted ${sourceData.rows.length} changed records since ${lastSync}`);
```

**Example Output:**
```
- Extracted 50 changed records since 2025-10-30
```

#### Defensive Column Check (Bug Fix #4)

```javascript
// DEFENSIVE CHECK: Verify table has timestamp columns before using them
const timestamps = await this.hasTimestampColumns(sourceTableName);

if (!timestamps.hasEither) {
  // Table missing both timestamp columns - force full sync
  console.log(`  - [WARN]  Table ${sourceTableName} missing created_at/updated_at columns`);
  console.log(`  - [WARN]  Forcing FULL sync (incremental sync requires timestamp columns)`);

  sourceData = await this.sourcePool.query(`SELECT * FROM ${sourceTableName}`);
  console.log(`  - Extracted ${sourceData.rows.length} records (full sync - fallback)`);
}
```

### Transform Phase

**Purpose:** Convert desktop schema to mobile schema, validate data, build lookups

**Code Location:** `sync/production/engine-staging.js` lines 513-560

#### Step 1: Build Lookup Caches

Some tables need data from other tables. Example: `jobtasks` needs `client_id` from `jobshead`.

```javascript
// Build lookup cache for client_id
// For each jobtask, lookup the client_id from jobshead using job_id
await this.buildLookupCache(targetTableName, columnMapping);

// Implementation:
async buildLookupCache(tableName, columnMapping) {
  if (!columnMapping || !columnMapping.lookups) {
    return; // No lookups defined for this table
  }

  console.log(`  - Building lookup caches...`);

  for (const [targetColumn, lookupDef] of Object.entries(columnMapping.lookups)) {
    // Example: jobtasks needs client_id from jobshead
    // lookupDef = { fromTable: 'jobshead', sourceKey: 'job_id', targetKey: 'client_id' }

    const { fromTable, sourceKey, targetKey } = lookupDef;

    // Fetch all job_id -> client_id mappings from jobshead
    const lookupData = await this.targetPool.query(`
      SELECT ${sourceKey}, ${targetKey}
      FROM ${fromTable}
      WHERE ${targetKey} IS NOT NULL
    `);

    // Store in cache for quick lookup
    this.lookupCache[tableName] = this.lookupCache[tableName] || {};
    this.lookupCache[tableName][targetColumn] = new Map();

    for (const row of lookupData.rows) {
      this.lookupCache[tableName][targetColumn].set(row[sourceKey], row[targetKey]);
    }

    console.log(`    [OK] Built lookup cache for ${targetColumn}: ${lookupData.rows.length} mappings from ${fromTable}.${sourceKey} -> ${targetKey}`);
  }
}
```

**Example Output:**
```
- Building lookup caches...
  [OK] Built lookup cache for client_id: 10120 mappings from jobshead.job_id -> client_id
```

#### Step 2: Transform Records

```javascript
// Transform each record from desktop schema to mobile schema
const transformedRecords = sourceData.rows.map(row =>
  this.transformRecord(row, columnMapping, targetTableName)
);

console.log(`  - Transformed ${transformedRecords.length} records`);
```

**Transformation Rules (from config.js):**

```javascript
// Example: jobshead transformation
columnMappings: {
  jobshead: {
    // Columns to skip from desktop (not in mobile schema)
    skipColumns: ['job_uid', 'sporg_id', 'jctincharge', 'jt_id', 'tc_id'],

    // Columns to add for mobile (with default values)
    addColumns: {
      source: 'D',                    // Mark as desktop data
      created_at: () => new Date(),   // Add timestamp if missing
      updated_at: () => new Date(),   // Add timestamp if missing
    },

    // Lookups - fetch related data from other tables
    lookups: {
      // jobtasks doesn't have client_id, lookup from jobshead
      client_id: {
        fromTable: 'jobshead',
        sourceKey: 'job_id',
        targetKey: 'client_id'
      }
    }
  }
}
```

**Transform Implementation:**

```javascript
transformRecord(record, columnMapping, tableName) {
  const transformed = { ...record };

  // Step 1: Skip columns not in mobile schema
  if (columnMapping?.skipColumns) {
    for (const col of columnMapping.skipColumns) {
      delete transformed[col];
    }
  }

  // Step 2: Add mobile-specific columns
  if (columnMapping?.addColumns) {
    for (const [col, value] of Object.entries(columnMapping.addColumns)) {
      if (!(col in transformed)) {
        transformed[col] = typeof value === 'function' ? value() : value;
      }
    }
  }

  // Step 3: Perform lookups (fetch related data)
  if (columnMapping?.lookups && this.lookupCache[tableName]) {
    for (const [targetColumn, lookupDef] of Object.entries(columnMapping.lookups)) {
      const cache = this.lookupCache[tableName][targetColumn];
      if (cache) {
        const sourceValue = record[lookupDef.sourceKey];
        const lookedUpValue = cache.get(sourceValue);
        if (lookedUpValue !== undefined) {
          transformed[targetColumn] = lookedUpValue;
        }
      }
    }
  }

  return transformed;
}
```

**Example Transformation:**

**Desktop Record (jobshead):**
```json
{
  "job_id": 12345,
  "client_id": 500,
  "job_name": "Website Redesign",
  "jstartdate": "2025-01-15",
  "job_uid": "abc-123",        // Desktop-only field
  "sporg_id": 10,              // Desktop-only field
  "jctincharge": "John"        // Desktop-only field
}
```

**Transformed Record (mobile schema):**
```json
{
  "job_id": 12345,
  "client_id": 500,
  "job_name": "Website Redesign",
  "jstartdate": "2025-01-15",
  "source": "D",               // Added by transform
  "created_at": "2025-10-31T...",  // Added by transform
  "updated_at": "2025-10-31T..."   // Added by transform
}
```

**Example Transformation with Lookup (jobtasks):**

**Desktop Record:**
```json
{
  "id": 1,
  "job_id": 12345,
  "task_name": "Design Homepage",
  "staff_id": 5
  // Note: NO client_id in desktop jobtasks!
}
```

**After Lookup:**
```json
{
  "id": 1,
  "job_id": 12345,
  "task_name": "Design Homepage",
  "staff_id": 5,
  "client_id": 500,            // Looked up from jobshead using job_id=12345
  "source": "D",
  "created_at": "2025-10-31T...",
  "updated_at": "2025-10-31T..."
}
```

#### Step 3: Filter Invalid Records

```javascript
// Filter out records with invalid foreign key references
const { validRecords, invalidRecords } = this.filterByForeignKeys(
  targetTableName,
  transformedRecords
);

if (invalidRecords.length > 0) {
  console.log(`  - Filtered ${invalidRecords.length} invalid records (FK violations)`);
  console.log(`  - Will sync ${validRecords.length} valid records`);

  // Show first 3 + count of remaining
  const samplesToShow = Math.min(3, invalidRecords.length);
  for (let i = 0; i < samplesToShow; i++) {
    console.log(`    [X] Skipped: ${invalidRecords[i].reason}`);
  }
  if (invalidRecords.length > 3) {
    console.log(`    [X] (${invalidRecords.length - 3} more filtered records...)`);
  }
}
```

**Example Output:**
```
- Filtered 3 invalid records (FK violations)
- Will sync 726 valid records
  [X] Skipped: Invalid loc_id=2 (no matching locmaster)
  [X] Skipped: Invalid loc_id=2 (no matching locmaster)
  [X] Skipped: Invalid loc_id=2 (no matching locmaster)
```

**FK Validation Logic:**

```javascript
filterByForeignKeys(tableName, records) {
  const validRecords = [];
  const invalidRecords = [];

  for (const record of records) {
    let isValid = true;
    let reason = '';

    // Check org_id references orgmaster
    if (record.org_id && !this.fkCache.validOrgIds.has(record.org_id)) {
      isValid = false;
      reason = `Invalid org_id=${record.org_id} (no matching orgmaster)`;
    }

    // Check loc_id references locmaster
    if (record.loc_id && !this.fkCache.validLocIds.has(record.loc_id)) {
      isValid = false;
      reason = `Invalid loc_id=${record.loc_id} (no matching locmaster)`;
    }

    // Check client_id references climaster
    if (record.client_id && !this.fkCache.validClientIds.has(record.client_id)) {
      isValid = false;
      reason = `Invalid client_id=${record.client_id} (no matching climaster)`;
    }

    // ... more FK checks ...

    if (isValid) {
      validRecords.push(record);
    } else {
      invalidRecords.push({ record, reason });
    }
  }

  return { validRecords, invalidRecords };
}
```

### Load Phase

**Purpose:** Load transformed data to Supabase using staging table pattern

**Code Location:** `sync/production/engine-staging.js` lines 562-701

#### Step 1: Create Staging Table

```javascript
// Create temporary staging table (same structure as target)
await client.query(`DROP TABLE IF EXISTS ${stagingTableName}`);
await client.query(`
  CREATE TEMP TABLE ${stagingTableName}
  (LIKE ${targetTableName} INCLUDING ALL)
`);

console.log(`  - [OK] Staging table created`);
```

**Why Staging Tables?**
- Load data safely without affecting production
- If loading fails, production data unchanged
- Atomic commit at the end

#### Step 2: Batch Load to Staging

**Batch INSERT Optimization (Bug Fix from previous session):**

```javascript
const BATCH_SIZE = 1000; // Process 1000 records per INSERT

// Batch records into chunks
for (let batchStart = 0; batchStart < validRecords.length; batchStart += BATCH_SIZE) {
  const batchRecords = validRecords.slice(batchStart, batchStart + BATCH_SIZE);

  // Get columns from first record
  const columns = Object.keys(batchRecords[0]);

  // Build VALUES clause with placeholders for all records in batch
  const valueSets = [];
  const allValues = [];
  let paramIndex = 1;

  for (const record of batchRecords) {
    const recordValues = columns.map(col => record[col]);
    const placeholders = recordValues.map(() => `$${paramIndex++}`);
    valueSets.push(`(${placeholders.join(', ')})`);
    allValues.push(...recordValues);
  }

  // Single INSERT with 1000 records
  const batchInsertQuery = `
    INSERT INTO ${stagingTableName} (${columns.join(', ')})
    VALUES ${valueSets.join(', ')}
  `;

  await client.query(batchInsertQuery, allValues);
  stagingLoaded += batchRecords.length;

  console.log(`    [...] Loaded ${stagingLoaded}/${validRecords.length} to staging...`);
}

console.log(`  - [OK] Loaded ${stagingLoaded} records to staging table`);
```

**Performance:**
- **Before:** 1 INSERT per record = 24,562 queries (30+ minutes)
- **After:** 1000 records per INSERT = 25 queries (10 seconds) - **188x faster!**

**Example Output:**
```
- Loading data into staging table...
  [...] Loaded 1000/24562 to staging...
  [...] Loaded 2000/24562 to staging...
  ...
  [...] Loaded 24562/24562 to staging...
- [OK] Loaded 24562 records to staging table
```

#### Step 3: Load to Production (Two Patterns)

**Pattern A: UPSERT (Desktop PK Tables)**

Used for tables where desktop has the primary key (e.g., `climaster`, `orgmaster`).

```javascript
// Tables with desktop-managed PKs (client_id, org_id, etc.)
const hasMobileOnlyPK = this.hasMobileOnlyPK(targetTableName);

if (!hasMobileOnlyPK) {
  // UPSERT pattern - preserve existing PKs
  console.log(`  - Beginning UPSERT operation (desktop PK table)...`);

  const pkColumn = this.getPrimaryKey(targetTableName);  // e.g., 'client_id'
  const hasSource = await this.hasSourceColumn(targetTableName);

  // Get all columns except PK
  const columnsResult = await client.query(`
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = $1 AND column_name != $2
    ORDER BY ordinal_position
  `, [targetTableName, pkColumn]);

  const updateColumns = columnsResult.rows.map(r => r.column_name);
  const setClause = updateColumns
    .map(col => `${col} = EXCLUDED.${col}`)
    .join(', ');

  // UPSERT query
  let upsertQuery;
  if (hasSource) {
    // Only update desktop records (source='D'), preserve mobile records
    upsertQuery = `
      INSERT INTO ${targetTableName}
      SELECT * FROM ${stagingTableName}
      ON CONFLICT (${pkColumn}) DO UPDATE SET
        ${setClause}
      WHERE ${targetTableName}.source = 'D' OR ${targetTableName}.source IS NULL
    `;
  } else {
    // No source column, update all
    upsertQuery = `
      INSERT INTO ${targetTableName}
      SELECT * FROM ${stagingTableName}
      ON CONFLICT (${pkColumn}) DO UPDATE SET
        ${setClause}
    `;
  }

  const upsertResult = await client.query(upsertQuery);
  console.log(`  - [OK] Upserted ${upsertResult.rowCount} desktop records (preserved desktop PKs, mobile data untouched)`);
}
```

**How UPSERT Works:**

```sql
-- Example: Syncing climaster (desktop PK = client_id)

-- 1. All 726 records loaded to climaster_staging

-- 2. UPSERT to production
INSERT INTO climaster
SELECT * FROM climaster_staging
ON CONFLICT (client_id) DO UPDATE SET
  client_name = EXCLUDED.client_name,
  email = EXCLUDED.email,
  phone = EXCLUDED.phone,
  -- ... all columns ...
  updated_at = EXCLUDED.updated_at
WHERE climaster.source = 'D' OR climaster.source IS NULL;

-- What happens:
-- If client_id exists AND source='D' -> UPDATE with new values
-- If client_id exists AND source='M' -> SKIP (mobile data preserved)
-- If client_id doesn't exist -> INSERT new record

-- Result:
-- - Desktop records updated with latest values
-- - Desktop PKs preserved (client_id stays same)
-- - Mobile records untouched
```

**Pattern B: DELETE+INSERT (Mobile-Only PK Tables)**

Used for tables where mobile generates the primary key (e.g., `jobshead`, `jobtasks`).

```javascript
if (hasMobileOnlyPK) {
  // DELETE+INSERT pattern - mobile generates fresh PKs
  console.log(`  - Beginning DELETE+INSERT operation (mobile-only PK table)...`);

  // Step 1: Delete ONLY desktop records from production
  // Mobile records (source='M') remain untouched!
  const deleteResult = await client.query(`
    DELETE FROM ${targetTableName}
    WHERE source = 'D' OR source IS NULL
  `);
  console.log(`  - [OK] Deleted ${deleteResult.rowCount} desktop records (mobile data preserved)`);

  // Step 2: Insert ALL records from staging (get fresh mobile PKs)
  // Desktop records get new mobile-generated primary keys
  const insertResult = await client.query(`
    INSERT INTO ${targetTableName}
    SELECT * FROM ${stagingTableName}
  `);
  console.log(`  - [OK] Inserted ${insertResult.rowCount} desktop records with fresh mobile PKs`);
}
```

**Why DELETE+INSERT?**

Desktop `jobshead` doesn't have `id` column (mobile PK). Mobile app uses auto-increment `id` as primary key.

**Desktop Schema:**
```sql
CREATE TABLE jobshead (
  job_id INTEGER,      -- Desktop PK (not unique!)
  client_id INTEGER,
  job_name TEXT,
  ...
  -- NO 'id' column!
);
```

**Mobile Schema:**
```sql
CREATE TABLE jobshead (
  id BIGSERIAL PRIMARY KEY,    -- Mobile PK (auto-increment)
  job_id INTEGER,              -- Desktop field (has duplicates)
  client_id INTEGER,
  job_name TEXT,
  source TEXT,                 -- 'D' = Desktop, 'M' = Mobile
  ...
);
```

**How DELETE+INSERT Works:**

```sql
-- Example: Syncing jobshead (mobile PK = id)

-- 1. All 24,562 records loaded to jobshead_staging (no 'id' yet)

-- 2. DELETE all desktop records
DELETE FROM jobshead WHERE source = 'D' OR source IS NULL;
-- Removes 24,562 old desktop records
-- Preserves any mobile records (source='M')

-- 3. INSERT from staging (get fresh mobile PKs)
INSERT INTO jobshead SELECT * FROM jobshead_staging;
-- PostgreSQL auto-generates new 'id' values
-- Desktop records get new mobile PKs (id = 50001, 50002, ...)

-- Result:
-- - Old desktop records removed
-- - New desktop records inserted with fresh mobile PKs
-- - Mobile records preserved (not deleted in step 2)
```

**Critical Fix - Force FULL Sync (Bug Fix #2):**

```javascript
// Mobile-only PK tables must use FULL sync, never incremental
const hasMobileOnlyPK = this.hasMobileOnlyPK(targetTableName);
const effectiveMode = (mode === 'incremental' && hasMobileOnlyPK) ? 'full' : mode;

if (effectiveMode === 'full' && mode === 'incremental' && hasMobileOnlyPK) {
  console.log(`  - [WARN]  Forcing FULL sync for ${targetTableName} (mobile-only PK table uses DELETE+INSERT)`);
  console.log(`  - [WARN]  Incremental mode would cause data loss - must have complete dataset before DELETE`);
}
```

**Why?**
- Incremental mode: SELECT only 100 changed records
- DELETE removes ALL 24,562 desktop records
- INSERT adds only 100 records
- **Result:** 24,462 records lost! [ERROR]

**Solution:** Force FULL mode for DELETE+INSERT tables to ensure complete dataset before DELETE.

#### Step 4: Commit Transaction

```javascript
// Commit transaction - atomic operation
await client.query('COMMIT');

if (hasMobileOnlyPK) {
  console.log(`  - [OK] Transaction committed (DELETE+INSERT complete)`);
} else {
  console.log(`  - [OK] Transaction committed (UPSERT complete)`);
}

// Drop staging table
await client.query(`DROP TABLE IF EXISTS ${stagingTableName}`);
console.log(`  - [OK] Staging table dropped`);
```

**Atomicity Guarantee:**
- If ANY step fails -> ROLLBACK
- Production data restored to previous state
- No partial updates or data loss

#### Step 5: Update Metadata

```javascript
// Update sync metadata for incremental sync tracking
await this.targetPool.query(`
  UPDATE _sync_metadata
  SET
    last_sync_timestamp = NOW(),
    records_synced = $1,
    last_sync_duration_ms = $2,
    error_message = NULL,
    updated_at = NOW()
  WHERE table_name = $3
`, [validRecords.length, duration, targetTableName]);

console.log(`  - [OK] Updated sync metadata for ${targetTableName}`);
```

**Metadata Table:**
```sql
CREATE TABLE _sync_metadata (
  table_name TEXT PRIMARY KEY,
  last_sync_timestamp TIMESTAMP WITH TIME ZONE,
  records_synced INTEGER,
  last_sync_duration_ms INTEGER,
  error_message TEXT,
  updated_at TIMESTAMP WITH TIME ZONE
);
```

**Used for:**
- Incremental sync: Only fetch records changed since `last_sync_timestamp`
- Monitoring: Track sync performance and errors
- Debugging: See when each table was last synced

---

## Complete ETL Flow Example

### Example: Syncing climaster (726 records)

**1. EXTRACT - Fetch from Desktop**

```javascript
// Query desktop database
const sourceData = await this.sourcePool.query(`
  SELECT * FROM climaster
`);
// Result: 729 records
```

**2. TRANSFORM - Convert & Validate**

```javascript
// 2a. Transform records (add source='D', timestamps)
const transformedRecords = sourceData.rows.map(row => ({
  ...row,
  source: 'D',
  created_at: new Date(),
  updated_at: new Date()
}));
// Result: 729 records with mobile fields

// 2b. Filter invalid FK references
const { validRecords, invalidRecords } = this.filterByForeignKeys(
  'climaster',
  transformedRecords
);
// Result: 726 valid, 3 invalid (loc_id=2 missing)
```

**3. LOAD - Stage, Validate, Commit**

```javascript
// 3a. Create staging table
await client.query(`
  CREATE TEMP TABLE climaster_staging
  (LIKE climaster INCLUDING ALL)
`);

// 3b. Batch load to staging (1 batch = 726 records)
await client.query(`
  INSERT INTO climaster_staging (client_id, client_name, ...)
  VALUES
    (1, 'ABC Corp', ...),
    (2, 'XYZ Ltd', ...),
    ... (726 records)
`);

// 3c. UPSERT to production
await client.query(`
  INSERT INTO climaster SELECT * FROM climaster_staging
  ON CONFLICT (client_id) DO UPDATE SET
    client_name = EXCLUDED.client_name,
    email = EXCLUDED.email,
    ...
  WHERE climaster.source = 'D' OR climaster.source IS NULL
`);
// Updates 720 existing records, inserts 6 new records

// 3d. Commit transaction
await client.query('COMMIT');

// 3e. Drop staging table
await client.query(`DROP TABLE climaster_staging`);
```

**Result:**
- 726 records synced successfully
- 3 invalid records skipped (logged for review)
- Desktop PKs preserved (client_id unchanged)
- Mobile records untouched (source='M' preserved)
- Duration: 0.78 seconds

---

## Reverse Sync: Supabase -> Desktop

### Overview

Reverse sync pulls mobile-created records from Supabase back to the desktop database.

### Key Features

1. **INSERT-only** - Never updates existing desktop records
2. **Filters by source='M'** - Only syncs mobile-created data
3. **Timestamp-based** - Only fetches new/changed mobile records
4. **Preserves Desktop** - Desktop records remain untouched

### File Structure

```
sync/production/
\-- reverse-sync-engine.js     # Reverse sync implementation
```

### Running Reverse Sync

```bash
node sync/production/reverse-sync-engine.js
```

### Reverse Sync ETL Process

#### 1. EXTRACT - Fetch Mobile Records from Supabase

```javascript
// Get last sync timestamp
const lastSyncResult = await desktopPool.query(`
  SELECT last_sync_at
  FROM sync_log
  WHERE table_name = $1
  ORDER BY synced_at DESC
  LIMIT 1
`, [tableName]);

const lastSync = lastSyncResult.rows[0]?.last_sync_at || '1970-01-01';

// Fetch ONLY mobile records (source='M') changed since last sync
const mobileRecords = await supabasePool.query(`
  SELECT *
  FROM ${tableName}
  WHERE source = 'M'
    AND (updated_at > $1 OR created_at > $1)
  ORDER BY COALESCE(updated_at, created_at)
`, [lastSync]);

console.log(`  - Extracted ${mobileRecords.rows.length} mobile records since ${lastSync}`);
```

**Example Output:**
```
- Extracted 15 mobile records since 2025-10-30
```

#### 2. TRANSFORM - Convert Mobile Schema to Desktop Schema

```javascript
// Transform mobile records to desktop schema
const transformedRecords = mobileRecords.rows.map(record => {
  const transformed = { ...record };

  // Remove mobile-only fields
  delete transformed.id;          // Mobile PK (auto-increment)
  delete transformed.source;      // Mobile tracking field
  delete transformed.created_at;  // Mobile timestamp
  delete transformed.updated_at;  // Mobile timestamp

  // Convert mobile field names to desktop field names
  // Example: reminder table
  if (tableName === 'reminder') {
    transformed.rem_id = record.rem_id;  // Desktop PK
    // ... other field mappings
  }

  return transformed;
});

console.log(`  - Transformed ${transformedRecords.length} records to desktop schema`);
```

#### 3. LOAD - Insert to Desktop Database

```javascript
// INSERT mobile records to desktop (skip duplicates)
for (const record of transformedRecords) {
  const columns = Object.keys(record);
  const values = Object.values(record);
  const placeholders = columns.map((_, i) => `$${i + 1}`);

  try {
    // INSERT-only (no updates)
    await desktopPool.query(`
      INSERT INTO ${tableName} (${columns.join(', ')})
      VALUES (${placeholders.join(', ')})
      ON CONFLICT DO NOTHING
    `, values);

    recordsInserted++;
  } catch (error) {
    console.error(`    [X] Error inserting record:`, error.message);
    recordsSkipped++;
  }
}

console.log(`  - [OK] Inserted ${recordsInserted} mobile records to desktop`);
console.log(`  - [WARN]  Skipped ${recordsSkipped} duplicate/error records`);
```

**Example Output:**
```
- [OK] Inserted 12 mobile records to desktop
- [WARN]  Skipped 3 duplicate/error records
```

#### 4. Update Sync Log

```javascript
// Record sync activity in desktop database
await desktopPool.query(`
  INSERT INTO sync_log (
    table_name,
    direction,
    records_synced,
    last_sync_at,
    synced_at
  ) VALUES ($1, $2, $3, NOW(), NOW())
`, [tableName, 'reverse', recordsInserted]);

console.log(`  - [OK] Updated sync log for ${tableName}`);
```

### Reverse Sync Example Flow

**Scenario:** Mobile user creates 3 new reminders in the app

**Step 1: Mobile App Creates Records**

```javascript
// Mobile app (Flutter) creates reminder via Supabase API
const { data, error } = await supabase
  .from('reminder')
  .insert([
    {
      rem_id: 1001,  // Desktop-compatible PK
      staff_id: 5,
      client_id: 100,
      rem_subject: 'Follow up call',
      rem_date: '2025-11-05',
      source: 'M',   // Mark as mobile-created
      created_at: new Date(),
      updated_at: new Date()
    }
  ]);
```

**Supabase Record:**
```json
{
  "id": 50001,           // Mobile PK (auto-generated)
  "rem_id": 1001,        // Desktop PK
  "staff_id": 5,
  "client_id": 100,
  "rem_subject": "Follow up call",
  "rem_date": "2025-11-05",
  "source": "M",         // Mobile-created flag
  "created_at": "2025-10-31T10:00:00Z",
  "updated_at": "2025-10-31T10:00:00Z"
}
```

**Step 2: Reverse Sync Runs (Scheduled)**

```bash
# Cron job runs every hour
0 * * * * node sync/production/reverse-sync-engine.js
```

**Step 3: Extract Mobile Records**

```sql
SELECT *
FROM reminder
WHERE source = 'M'
  AND created_at > '2025-10-31 09:00:00'
```

**Step 4: Transform to Desktop Schema**

```json
{
  "rem_id": 1001,
  "staff_id": 5,
  "client_id": 100,
  "rem_subject": "Follow up call",
  "rem_date": "2025-11-05"
  // Removed: id, source, created_at, updated_at
}
```

**Step 5: Insert to Desktop**

```sql
INSERT INTO mbreminder (rem_id, staff_id, client_id, rem_subject, rem_date)
VALUES (1001, 5, 100, 'Follow up call', '2025-11-05')
ON CONFLICT DO NOTHING
```

**Result:**
- Desktop now has the mobile-created reminder
- rem_id=1001 can be referenced by desktop app
- If rem_id already exists, skip (no duplicate)
- Desktop's existing reminders untouched

---

## Configuration

### Table Mapping

**File:** `sync/production/config.js`

```javascript
tableMapping: {
  // Desktop table -> Mobile table
  'mbreminder': 'reminder',      // Rename: mbreminder -> reminder
  'mbremdetail': 'remdetail',    // Rename: mbremdetail -> remdetail

  // All others: same name
  'orgmaster': 'orgmaster',
  'locmaster': 'locmaster',
  'conmaster': 'conmaster',
  'climaster': 'climaster',
  'cliunimaster': 'cliunimaster',
  'taskmaster': 'taskmaster',
  'jobmaster': 'jobmaster',
  'mbstaff': 'mbstaff',
  'jobshead': 'jobshead',
  'jobtasks': 'jobtasks',
  'taskchecklist': 'taskchecklist',
  'workdiary': 'workdiary',
  'learequest': 'learequest',
}
```

### Column Mappings

```javascript
columnMappings: {
  jobshead: {
    // Skip desktop-only columns
    skipColumns: ['job_uid', 'sporg_id', 'jctincharge', 'jt_id', 'tc_id'],

    // Add mobile columns
    addColumns: {
      source: 'D',                    // Mark as desktop data
      created_at: () => new Date(),
      updated_at: () => new Date(),
    }
  },

  jobtasks: {
    skipColumns: ['jt_uid'],

    addColumns: {
      source: 'D',
      created_at: () => new Date(),
      updated_at: () => new Date(),
    },

    // Lookup client_id from jobshead
    lookups: {
      client_id: {
        fromTable: 'jobshead',
        sourceKey: 'job_id',
        targetKey: 'client_id'
      }
    }
  },

  // ... other tables
}
```

### Sync Categories

```javascript
// Master tables - reference data (full sync always)
masterTables: [
  'orgmaster',
  'locmaster',
  'conmaster',
  'climaster',
  'cliunimaster',
  'taskmaster',
  'jobmaster',
  'mbstaff',
],

// Transactional tables - operational data
// Note: jobshead, jobtasks, taskchecklist, workdiary are AUTO-FORCED to FULL mode
// (they use mobile-generated PKs and DELETE+INSERT pattern)
transactionalTables: [
  'jobshead',      // AUTO-FULL (mobile PK)
  'jobtasks',      // AUTO-FULL (mobile PK)
  'taskchecklist', // AUTO-FULL (mobile PK)
  'workdiary',     // AUTO-FULL (mobile PK)
  'mbreminder',    // True incremental (desktop PK)
  'mbremdetail',   // True incremental (desktop PK)
  'learequest',    // True incremental
]
```

### Database Connections

```javascript
// Source: Desktop PostgreSQL
source: {
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD,
  max: 10,  // Connection pool size
},

// Target: Supabase Cloud
target: {
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
  max: 10,
}
```

---

## Advanced Patterns

### Pattern 1: Conditional Sync (Skip Empty Tables)

```javascript
if (sourceData.rows.length === 0) {
  console.log('  - No records to sync, skipping...\n');
  return;
}
```

### Pattern 2: Progressive Logging

```javascript
// Show progress every 1000 records
if (stagingLoaded % 1000 === 0 || stagingLoaded === validRecords.length) {
  console.log(`    [...] Loaded ${stagingLoaded}/${validRecords.length} to staging...`);
}
```

### Pattern 3: Error Recovery with Rollback

```javascript
try {
  await client.query('BEGIN');
  // ... all sync operations ...
  await client.query('COMMIT');
} catch (error) {
  // ROLLBACK - production data is restored!
  await client.query('ROLLBACK');
  console.error(`  - [X] Sync operation failed, rolling back:`, error.message);
  console.log(`  - [OK] Production data restored (unchanged)`);
  throw error;
}
```

### Pattern 4: Fallback to Row-by-Row on Batch Failure

```javascript
try {
  // Try batch INSERT (1000 records)
  await client.query(batchInsertQuery, allValues);
} catch (error) {
  console.error(`    [X] Error loading batch to staging:`, error.message);

  // Fallback: Try row-by-row for this batch
  console.log(`    [WARN]  Retrying batch row-by-row...`);
  for (const record of batchRecords) {
    try {
      await client.query(rowInsertQuery, Object.values(record));
      stagingLoaded++;
    } catch (rowError) {
      console.error(`    [X] Error loading record:`, rowError.message);
    }
  }
}
```

### Pattern 5: Mobile-Only PK Detection

```javascript
// Auto-detect which tables use mobile-only PKs
hasMobileOnlyPK(tableName) {
  const deleteInsertTables = ['jobshead', 'jobtasks', 'taskchecklist', 'workdiary'];
  return deleteInsertTables.includes(tableName);
}

// Force FULL sync for these tables
const effectiveMode = (mode === 'incremental' && hasMobileOnlyPK)
  ? 'full'
  : mode;
```

### Pattern 6: Timestamp Column Validation

```javascript
// Check if table has required timestamp columns
const timestamps = await this.hasTimestampColumns(sourceTableName);

if (!timestamps.hasEither) {
  // Force full sync if missing timestamps
  console.log(`  - [WARN]  Forcing FULL sync (missing timestamp columns)`);
  sourceData = await this.sourcePool.query(`SELECT * FROM ${sourceTableName}`);
}
```

---

## Troubleshooting

### Common Issues

#### Issue 1: "column does not exist" Error

**Error:**
```
ERROR: column "updated_at" does not exist
```

**Cause:** Table missing timestamp columns for incremental sync

**Solution:**
- Engine now auto-detects and falls back to full sync
- Or add timestamp columns to desktop table:
  ```sql
  ALTER TABLE mytable
  ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  ```

#### Issue 2: "Cannot read properties of undefined"

**Error:**
```
Cannot read properties of undefined (reading 'target')
```

**Cause:** Using wrong config property name (`tableMappings` vs `tableMapping`)

**Solution:** Fixed in Bug #3 - use `config.tableMapping` (singular)

#### Issue 3: Data Loss in Incremental Sync

**Symptom:** Records disappearing after incremental sync

**Cause:** Mobile-only PK tables using DELETE+INSERT with incomplete dataset

**Solution:** Fixed in Bug #2 - mobile-only PK tables forced to FULL sync

#### Issue 4: FK Constraint Violations

**Error:**
```
ERROR: insert or update on table "jobtasks" violates foreign key constraint
```

**Cause:** Desktop has orphaned records (e.g., job_id references deleted job)

**Solution:**
- Option A: Remove FK constraint in Supabase (done for some tables)
- Option B: Filter invalid records during transform (implemented)

#### Issue 5: Duplicate Key Violations

**Error:**
```
ERROR: duplicate key value violates unique constraint "jobshead_pkey"
```

**Cause:** Desktop has duplicate primary key values

**Solution:** Removed PK constraint on affected tables (e.g., jobshead)

### Debugging Commands

**Check sync metadata:**
```sql
SELECT * FROM _sync_metadata ORDER BY updated_at DESC;
```

**Check last sync times:**
```sql
SELECT
  table_name,
  last_sync_timestamp,
  records_synced,
  last_sync_duration_ms / 1000.0 as duration_seconds
FROM _sync_metadata
ORDER BY last_sync_timestamp DESC;
```

**Count records by source:**
```sql
SELECT
  source,
  COUNT(*) as count
FROM jobshead
GROUP BY source;

-- Result:
-- source | count
-- -------+-------
-- D      | 24562  (Desktop records)
-- M      | 15     (Mobile records)
```

**Find orphaned records:**
```sql
SELECT j.*
FROM jobtasks j
LEFT JOIN jobshead jh ON j.job_id = jh.job_id
WHERE jh.job_id IS NULL;
```

### Performance Tips

1. **Use Incremental Sync When Possible**
   - Full sync: 3-5 minutes
   - Incremental sync: 30-40 seconds

2. **Run During Off-Peak Hours**
   - Schedule full syncs at night
   - Run incremental syncs during business hours

3. **Monitor Batch Sizes**
   - Current: 1000 records per batch
   - Adjust based on network conditions

4. **Check Connection Pooling**
   - max: 10 connections per pool
   - Increase if seeing connection errors

5. **Monitor Table Sizes**
   - Large tables (>50k records) may need optimization
   - Consider partitioning or archiving old data

---

## Summary

### Forward Sync Flow

```
Desktop DB
    |
    +-> EXTRACT (SELECT query)
    |      \-> Full: All records
    |      \-> Incremental: Changed records (WHERE updated_at > last_sync)
    |
    +-> TRANSFORM
    |      +-> Build lookup caches (fetch related data)
    |      +-> Transform records (add/remove/lookup columns)
    |      \-> Filter invalid records (FK validation)
    |
    \-> LOAD
           +-> Create staging table (temp)
           +-> Batch insert to staging (1000 per batch)
           +-> BEGIN TRANSACTION
           |      +-> Desktop PK: UPSERT (preserve PKs, preserve mobile data)
           |      \-> Mobile PK: DELETE+INSERT (fresh PKs, preserve mobile data)
           +-> COMMIT (atomic)
           +-> Drop staging table
           \-> Update metadata
                  \-> Supabase DB [OK]
```

### Reverse Sync Flow

```
Supabase DB (source='M')
    |
    +-> EXTRACT (SELECT WHERE source='M')
    |      \-> Only mobile-created records
    |      \-> Only records changed since last sync
    |
    +-> TRANSFORM
    |      +-> Remove mobile-only fields (id, source, timestamps)
    |      \-> Convert field names (mobile -> desktop)
    |
    \-> LOAD
           +-> INSERT to desktop (ON CONFLICT DO NOTHING)
           +-> Update sync log
           \-> Desktop DB [OK]
```

### Key Takeaways

1. **ETL Pattern** - Clean separation of Extract, Transform, Load phases
2. **Staging Tables** - Safe, atomic commits with rollback capability
3. **Batch Processing** - 100x performance improvement (1000 records/batch)
4. **Two Sync Patterns** - UPSERT for desktop PKs, DELETE+INSERT for mobile PKs
5. **Mobile Data Preservation** - source='M' records never overwritten
6. **Defensive Programming** - Column checks, FK validation, graceful fallbacks
7. **Bi-directional** - Forward and reverse sync for complete data flow

---

**Document Version:** 1.0
**Date:** 2025-10-31
**Author:** Claude Code (AI)
**Related Files:**
- [sync/production/runner-staging.js](../sync/production/runner-staging.js)
- [sync/production/engine-staging.js](../sync/production/engine-staging.js)
- [sync/production/reverse-sync-engine.js](../sync/production/reverse-sync-engine.js)
- [sync/production/config.js](../sync/production/config.js)
