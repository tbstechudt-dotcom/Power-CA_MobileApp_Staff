/**
 * SAFE SYNC ENGINE - Staging Table + DELETE+INSERT Pattern (BIDIRECTIONAL SAFE)
 *
 * This engine uses a staging table + DELETE+INSERT approach for safe bidirectional sync:
 * 1. Extract changed records from desktop (incremental) or all records (full)
 * 2. Load desktop data into temporary staging table (can fail safely)
 * 3. Validate data in staging (no impact on production)
 * 4. Atomic DELETE+INSERT in single transaction:
 *    - DELETE only desktop records (WHERE source='D' OR source IS NULL)
 *    - INSERT staging records (get fresh mobile-generated PKs)
 *    - PRESERVE mobile records (source='M' not deleted)
 * 5. Update sync metadata timestamp
 * 6. Cleanup staging table
 *
 * WHY DELETE+INSERT INSTEAD OF UPSERT:
 * - Desktop DB has NO reliable primary keys (legacy system)
 * - Desktop PKs are skipped during sync (meaningless/unreliable)
 * - Mobile DB (Supabase) generates fresh PKs for desktop records each sync
 * - Cannot use ON CONFLICT since desktop records have no stable identity
 * - DELETE+INSERT ensures no duplicates while preserving mobile data
 *
 * BENEFITS:
 * - If sync fails at any point, production data is UNTOUCHED
 * - Connection drops don't affect production data
 * - Can validate data before committing to production
 * - Rollback restores original data automatically
 * - MOBILE DATA PRESERVED - never deletes mobile-created records
 * - TRUE INCREMENTAL SYNC - only syncs changed records (10-60 sec vs hours!)
 * - Timestamp-based tracking via updated_at/created_at columns
 * - True bidirectional sync (Desktop <-> Supabase)
 *
 * REQUIREMENTS:
 * - Desktop DB must have updated_at and created_at columns on all tables
 * - Run scripts/add-desktop-timestamps.js to add columns and triggers
 * - Supabase must have _sync_metadata table for tracking last sync timestamps
 * - Run scripts/create-sync-metadata-table.js to initialize
 *
 * MODES:
 * - full: Sync ALL desktop records (use for initial sync or weekly catch-all)
 * - incremental: Only sync records changed since last sync (daily/hourly use)
 *
 * USAGE:
 *   const engine = new StagingSyncEngine();
 *   await engine.syncAll('full');        // Initial sync (hours)
 *   await engine.syncAll('incremental'); // Subsequent syncs (seconds!)
 */

require('dotenv').config();
const { Pool } = require('pg');
const config = require('./config');

class StagingSyncEngine {
  constructor() {
    this.config = config; // Store config reference for validation methods
    this.sourcePool = new Pool(config.source);
    this.targetPool = new Pool(config.target);
    this.fkCache = {};
    this.lookupCache = {}; // Cache for lookup values (e.g., job_id -> client_id)
    this.syncStats = {
      startTime: null,
      endTime: null,
      tablesProcessed: 0,
      recordsProcessed: 0,
      recordsFiltered: 0,
    };
  }

  /**
   * Ensure _sync_metadata table exists (auto-provision if needed)
   * This makes the engine defensive - won't crash on first run
   */
  async ensureSyncMetadataTable() {
    try {
      // Check if table exists
      const tableExists = await this.targetPool.query(`
        SELECT table_name
        FROM information_schema.tables
        WHERE table_name = '_sync_metadata'
      `);

      if (tableExists.rows.length > 0) {
        // Table exists, no action needed
        return;
      }

      console.log('[WARN]  _sync_metadata table not found, creating...');

      // Create the table
      await this.targetPool.query(`
        CREATE TABLE _sync_metadata (
          table_name VARCHAR(255) PRIMARY KEY,
          last_sync_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT '1970-01-01',
          last_sync_id BIGINT,
          sync_status VARCHAR(50) DEFAULT 'pending',
          records_synced INTEGER DEFAULT 0,
          error_message TEXT,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
      `);
      console.log('[OK] Created _sync_metadata table');

      // Seed initial records for all tables
      const tables = Object.keys(config.tableMapping);
      for (const table of tables) {
        const targetTableName = config.tableMapping[table];
        await this.targetPool.query(`
          INSERT INTO _sync_metadata (table_name, last_sync_timestamp, records_synced)
          VALUES ($1, '1970-01-01', 0)
          ON CONFLICT (table_name) DO NOTHING
        `, [targetTableName]);
      }
      console.log(`[OK] Seeded ${tables.length} table records in _sync_metadata\n`);

    } catch (error) {
      console.error('[WARN]  Error ensuring _sync_metadata table:', error.message);
      // Don't throw - fall back gracefully, incremental sync just won't work on first run
    }
  }

  /**
   * Pre-load FK references for validation
   */
  async preloadForeignKeys() {
    console.log('\n--- Pre-loading Foreign Key References ---');

    try {
      // Load valid org_ids
      const orgs = await this.targetPool.query('SELECT org_id FROM orgmaster');
      this.fkCache.validOrgIds = new Set(orgs.rows.map(r => r.org_id?.toString()));
      console.log(`  [OK] Loaded ${this.fkCache.validOrgIds.size} valid org_ids`);

      // Load valid loc_ids
      const locs = await this.targetPool.query('SELECT loc_id FROM locmaster');
      this.fkCache.validLocIds = new Set(locs.rows.map(r => r.loc_id?.toString()));
      console.log(`  [OK] Loaded ${this.fkCache.validLocIds.size} valid loc_ids`);

      // Load valid con_ids
      const cons = await this.targetPool.query('SELECT con_id FROM conmaster');
      this.fkCache.validConIds = new Set(cons.rows.map(r => r.con_id?.toString()));
      console.log(`  [OK] Loaded ${this.fkCache.validConIds.size} valid con_ids`);

      // Load valid client_ids
      const clients = await this.targetPool.query('SELECT client_id FROM climaster');
      this.fkCache.validClientIds = new Set(clients.rows.map(r => r.client_id?.toString()));
      console.log(`  [OK] Loaded ${this.fkCache.validClientIds.size} valid client_ids`);

      // Load valid staff_ids
      const staff = await this.targetPool.query('SELECT staff_id FROM mbstaff');
      this.fkCache.validStaffIds = new Set(staff.rows.map(r => r.staff_id?.toString()));
      console.log(`  [OK] Loaded ${this.fkCache.validStaffIds.size} valid staff_ids`);

      // Load valid job_ids
      const jobs = await this.targetPool.query('SELECT job_id FROM jobshead');
      this.fkCache.validJobIds = new Set(jobs.rows.map(r => r.job_id?.toString()));
      console.log(`  [OK] Loaded ${this.fkCache.validJobIds.size} valid job_ids`);

      console.log('  [OK] FK cache ready\n');
    } catch (error) {
      console.error('  [X] Error loading FK cache:', error.message);
      throw error;
    }
  }

  /**
   * Refresh FK cache for a specific table after it has been synced
   * This ensures dependent tables validate against up-to-date FK references
   */
  async refreshForeignKeyCache(tableName) {
    if (tableName === 'jobshead') {
      const jobs = await this.targetPool.query('SELECT job_id FROM jobshead');
      const oldSize = this.fkCache.validJobIds.size;
      this.fkCache.validJobIds = new Set(jobs.rows.map(r => r.job_id?.toString()));
      const newSize = this.fkCache.validJobIds.size;
      console.log(`    [INFO] Refreshed validJobIds cache: ${oldSize} -> ${newSize} IDs (+${newSize - oldSize} new)`);
    }
    else if (tableName === 'climaster') {
      const clients = await this.targetPool.query('SELECT client_id FROM climaster');
      const oldSize = this.fkCache.validClientIds.size;
      this.fkCache.validClientIds = new Set(clients.rows.map(r => r.client_id?.toString()));
      const newSize = this.fkCache.validClientIds.size;
      console.log(`    [INFO] Refreshed validClientIds cache: ${oldSize} -> ${newSize} IDs (+${newSize - oldSize} new)`);
    }
    else if (tableName === 'mbstaff') {
      const staff = await this.targetPool.query('SELECT staff_id FROM mbstaff');
      const oldSize = this.fkCache.validStaffIds.size;
      this.fkCache.validStaffIds = new Set(staff.rows.map(r => r.staff_id?.toString()));
      const newSize = this.fkCache.validStaffIds.size;
      console.log(`    [INFO] Refreshed validStaffIds cache: ${oldSize} -> ${newSize} IDs (+${newSize - oldSize} new)`);
    }
  }

  /**
   * Extract the maximum timestamp from a record
   * Returns the newest timestamp available (updated_at or created_at)
   * Used to prevent race condition in metadata tracking
   */
  getRecordTimestamp(record, timestamps) {
    // Return the newest timestamp available
    if (timestamps.hasBoth) {
      const updated = record.updated_at ? new Date(record.updated_at) : null;
      const created = record.created_at ? new Date(record.created_at) : null;
      if (updated && created) return updated > created ? updated : created;
      return updated || created;
    } else if (timestamps.hasUpdatedAt) {
      return record.updated_at ? new Date(record.updated_at) : null;
    } else if (timestamps.hasCreatedAt) {
      return record.created_at ? new Date(record.created_at) : null;
    }
    return null;
  }

  /**
   * Get primary key column for table
   */
  getPrimaryKey(tableName) {
    const primaryKeys = {
      'orgmaster': 'org_id',
      'locmaster': 'loc_id',
      'conmaster': 'con_id',
      'climaster': 'client_id',
      'mbstaff': 'staff_id',
      'taskmaster': 'task_id',
      'jobmaster': 'job_id',
      'cliunimaster': 'cliu_id',
      'jobshead': 'job_id',
      'jobtasks': 'jt_id',
      'taskchecklist': 'tc_id',
      'workdiary': 'wd_id',
      'reminder': 'rem_id',
      'remdetail': 'remd_id',
      'learequest': 'lea_id',
    };
    return primaryKeys[tableName];
  }

  /**
   * Check if table has mobile-only PK or non-unique desktop PK (can't use UPSERT)
   *
   * Tables that must use DELETE+INSERT pattern:
   * - jobshead - Desktop has DUPLICATE job_id values (not unique!)
   * - jt_id (jobtasks) - Desktop doesn't have this, mobile tracking only
   * - tc_id (taskchecklist) - Desktop doesn't have this, mobile tracking only
   * - wd_id (workdiary) - Desktop doesn't have this, mobile tracking only
   *
   * These tables must use DELETE+INSERT pattern since they either:
   * 1. Don't have stable PKs that mobile can match on, OR
   * 2. Have duplicate PK values in desktop (UPSERT would fail)
   */
  hasMobileOnlyPK(tableName) {
    // Tables that must use DELETE+INSERT pattern (no unique PK in Supabase):
    // - jobshead: No primary key in Supabase (same job_id assigned to multiple staff/orgs)
    // - jobtasks, taskchecklist, workdiary: Mobile-generated PKs only
    // - remdetail: remd_id column doesn't exist in Supabase
    const deleteInsertTables = ['jobshead', 'jobtasks', 'taskchecklist', 'workdiary', 'remdetail'];
    return deleteInsertTables.includes(tableName);
  }

  /**
   * Check if table has a 'source' column (for tracking desktop vs mobile data)
   * Returns true if column exists, false otherwise
   */
  async hasSourceColumn(tableName) {
    try {
      const result = await this.targetPool.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = $1 AND column_name = 'source'
      `, [tableName]);
      return result.rows.length > 0;
    } catch (error) {
      console.error(`  - [WARN]  Error checking for source column:`, error.message);
      return false; // Assume no source column if check fails
    }
  }

  /**
   * Tables that need deduplication during extraction
   * (Source has duplicate PKs that violate UPSERT constraints)
   */
  needsDeduplication(tableName) {
    // jobshead source (v_jobshead view) has duplicate job_id values
    // We need to deduplicate to keep only the most recent record per job_id
    return tableName === 'jobshead';
  }

  /**
   * Check if source table has timestamp columns (created_at/updated_at)
   * Returns object with boolean flags for each column
   *
   * CRITICAL: Incremental sync requires at least one timestamp column.
   * If neither exists, we must fall back to full sync to avoid query errors.
   */
  async hasTimestampColumns(tableName) {
    try {
      const result = await this.sourcePool.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = $1
          AND column_name IN ('created_at', 'updated_at')
      `, [tableName]);

      const hasCreatedAt = result.rows.some(row => row.column_name === 'created_at');
      const hasUpdatedAt = result.rows.some(row => row.column_name === 'updated_at');

      return {
        hasCreatedAt,
        hasUpdatedAt,
        hasEither: hasCreatedAt || hasUpdatedAt,
        hasBoth: hasCreatedAt && hasUpdatedAt
      };
    } catch (error) {
      console.error(`  - [WARN]  Error checking for timestamp columns:`, error.message);
      return {
        hasCreatedAt: false,
        hasUpdatedAt: false,
        hasEither: false,
        hasBoth: false
      };
    }
  }

  /**
   * Validate that all source tables have timestamp columns for incremental sync
   * This is called during initialization to fail fast if tables are missing required columns
   *
   * IMPORTANT: This is a pre-flight check to catch issues early before starting sync
   */
  async validateTimestampColumns() {
    console.log('\n[INFO] Validating timestamp columns for incremental sync...');

    const tableMapping = this.config.tableMapping;
    const tables = Object.keys(tableMapping);

    let allValid = true;
    const warnings = [];

    for (const sourceTableName of tables) {
      const timestamps = await this.hasTimestampColumns(sourceTableName);

      if (!timestamps.hasEither) {
        warnings.push(`[WARN]  ${sourceTableName}: Missing both created_at and updated_at (will force full sync)`);
        allValid = false;
      } else if (!timestamps.hasBoth) {
        if (!timestamps.hasCreatedAt) {
          warnings.push(`[WARN]  ${sourceTableName}: Missing created_at column (will use only updated_at)`);
        } else {
          warnings.push(`[WARN]  ${sourceTableName}: Missing updated_at column (will use only created_at)`);
        }
      }
    }

    if (allValid) {
      console.log(`[OK] All ${tables.length} tables have timestamp columns`);
    } else {
      console.log('\n[WARN]  Some tables missing timestamp columns:');
      warnings.forEach(warning => console.log(`   ${warning}`));
      console.log('\n[TIP] These tables will automatically fall back to full sync mode.');
      console.log('   To enable true incremental sync, add created_at/updated_at columns.');
    }

    console.log('');
  }

  /**
   * Build lookup cache for a table's lookup definitions
   * Example: For jobtasks, build job_id -> client_id mapping
   */
  async buildLookupCache(tableName, columnMapping) {
    if (!columnMapping || !columnMapping.lookups) {
      return; // No lookups defined for this table
    }

    console.log(`  - Building lookup caches...`);

    for (const [targetColumn, lookupDef] of Object.entries(columnMapping.lookups)) {
      const { fromTable, matchOn, selectColumn } = lookupDef;

      try {
        // Query target database to build lookup map
        const result = await this.targetPool.query(`
          SELECT ${matchOn}, ${selectColumn}
          FROM ${fromTable}
        `);

        // Build Map: matchOn value -> selectColumn value
        // Example: job_id -> client_id
        const lookupMap = new Map();
        result.rows.forEach(row => {
          lookupMap.set(row[matchOn]?.toString(), row[selectColumn]);
        });

        // Store in cache with key: tableName.targetColumn
        const cacheKey = `${tableName}.${targetColumn}`;
        this.lookupCache[cacheKey] = lookupMap;

        console.log(`    [OK] Built lookup cache for ${targetColumn}: ${lookupMap.size} mappings from ${fromTable}.${matchOn} -> ${selectColumn}`);
      } catch (error) {
        console.error(`    [X] Error building lookup cache for ${targetColumn}:`, error.message);
      }
    }
  }

  /**
   * FK validation rules per table
   */
  getForeignKeyRules(tableName) {
    const rules = {
      orgmaster: [],
      locmaster: [
        { column: 'org_id', referenceTable: 'orgmaster', referenceColumn: 'org_id' },
      ],
      conmaster: [
        { column: 'org_id', referenceTable: 'orgmaster', referenceColumn: 'org_id' },
        { column: 'loc_id', referenceTable: 'locmaster', referenceColumn: 'loc_id' },
      ],
      climaster: [
        { column: 'org_id', referenceTable: 'orgmaster', referenceColumn: 'org_id' },
        { column: 'loc_id', referenceTable: 'locmaster', referenceColumn: 'loc_id' },
        // con_id: FK constraint removed - allows 0 and NULL values
      ],
      jobshead: [
        { column: 'org_id', referenceTable: 'orgmaster', referenceColumn: 'org_id' },
        { column: 'loc_id', referenceTable: 'locmaster', referenceColumn: 'loc_id' },
        // client_id: FK constraint removed - allows orphaned jobs (non-existent clients)
      ],
      jobtasks: [
        { column: 'job_id', referenceTable: 'jobshead', referenceColumn: 'job_id' },
        { column: 'staff_id', referenceTable: 'mbstaff', referenceColumn: 'staff_id' },
        // task_id: FK constraint removed - allows any value (taskmaster is empty)
      ],
      mbstaff: [
        { column: 'org_id', referenceTable: 'orgmaster', referenceColumn: 'org_id' },
        { column: 'loc_id', referenceTable: 'locmaster', referenceColumn: 'loc_id' },
        // con_id: FK constraint removed - allows 0 and NULL values
      ],
      taskchecklist: [
        // job_id: FK constraint removed - allows any value
      ],
      workdiary: [
        { column: 'job_id', referenceTable: 'jobshead', referenceColumn: 'job_id' },
        { column: 'staff_id', referenceTable: 'mbstaff', referenceColumn: 'staff_id' },
      ],
      reminder: [
        { column: 'staff_id', referenceTable: 'mbstaff', referenceColumn: 'staff_id' },
        // client_id: FK constraint removed - allows any value
      ],
      remdetail: [
        // staff_id: FK constraint removed - allows any value
      ],
    };

    return rules[tableName] || [];
  }

  /**
   * Validate FK references for a record
   */
  validateForeignKeys(tableName, record) {
    const rules = this.getForeignKeyRules(tableName);
    const reasons = [];

    for (const rule of rules) {
      const value = record[rule.column]?.toString();
      if (!value) continue;

      let validSet;
      if (rule.referenceTable === 'orgmaster') {
        validSet = this.fkCache.validOrgIds;
      } else if (rule.referenceTable === 'locmaster') {
        validSet = this.fkCache.validLocIds;
      } else if (rule.referenceTable === 'conmaster') {
        validSet = this.fkCache.validConIds;
      } else if (rule.referenceTable === 'climaster') {
        validSet = this.fkCache.validClientIds;
      } else if (rule.referenceTable === 'mbstaff') {
        validSet = this.fkCache.validStaffIds;
      } else if (rule.referenceTable === 'jobshead') {
        validSet = this.fkCache.validJobIds;
      }

      if (validSet && !validSet.has(value)) {
        reasons.push(`Invalid ${rule.column}=${value} (no matching ${rule.referenceTable})`);
      }
    }

    return {
      valid: reasons.length === 0,
      reasons: reasons,
    };
  }

  /**
   * Filter records by FK validity
   */
  filterByForeignKeys(tableName, records) {
    const validRecords = [];
    const invalidRecords = [];

    for (const record of records) {
      const validation = this.validateForeignKeys(tableName, record);

      if (validation.valid) {
        validRecords.push(record);
      } else {
        invalidRecords.push({
          record: record,
          reasons: validation.reasons,
        });
      }
    }

    return { validRecords, invalidRecords };
  }

  /**
   * SAFE SYNC TABLE - Using Staging + DELETE+INSERT Pattern
   *
   * Steps:
   * 1. Extract data from source:
   *    - Incremental mode: Only records with updated_at/created_at > last_sync_timestamp
   *    - Full mode: All records
   * 2. Transform and validate records (FK checks, skip desktop PKs)
   * 3. Create staging table (temp table with same structure)
   * 4. Load validated data into staging (can fail without affecting production)
   * 5. BEGIN transaction
   * 6a.  DELETE only desktop records (WHERE source='D' OR source IS NULL)
   *      - Mobile records (source='M') are NOT deleted, thus preserved!
   * 6b.  INSERT all staging records (get fresh mobile-generated PKs)
   *      - Desktop records get new primary keys from Supabase sequences
   * 7.   Update _sync_metadata with current timestamp
   * 8. COMMIT (atomic)
   * 9. Drop staging table
   *
   * WHY DELETE+INSERT INSTEAD OF UPSERT:
   * - Desktop DB has no reliable primary keys
   * - Desktop PKs are skipped during sync (unreliable/meaningless)
   * - Mobile DB generates fresh PKs for desktop records each sync
   * - Cannot use ON CONFLICT since desktop records have no stable identity
   * - DELETE+INSERT ensures no duplicates while preserving mobile data
   *
   * If ANY step fails, production data remains untouched!
   * Mobile-created records are NEVER deleted or overwritten!
   */
  async syncTableSafe(sourceTableName, mode = 'full') {
    const targetTableName = config.tableMapping[sourceTableName] || sourceTableName;
    const stagingTableName = `${targetTableName}_staging`;
    const startTime = Date.now();

    console.log(`\nSyncing: ${sourceTableName} -> ${targetTableName} (${mode})`);

    try {
      // Step 1: Extract from source (with timestamp-based incremental support)
      let sourceData;
      const hasMobileOnlyPK = this.hasMobileOnlyPK(targetTableName);

      // CRITICAL FIX: Force FULL sync for mobile-only PK tables
      // These tables use DELETE+INSERT pattern which requires complete dataset
      // Incremental mode would cause data loss:
      //   - SELECT only changed records (e.g., 100 records)
      //   - DELETE all desktop records (e.g., 24,562 records)
      //   - INSERT only changed records (100 records)
      //   - Result: 24,462 records permanently lost!
      const effectiveMode = (mode === 'incremental' && hasMobileOnlyPK) ? 'full' : mode;

      if (effectiveMode === 'full' && mode === 'incremental' && hasMobileOnlyPK) {
        console.log(`  - [WARN]  Forcing FULL sync for ${targetTableName} (mobile-only PK table uses DELETE+INSERT)`);
        console.log(`  - [WARN]  Incremental mode would cause data loss - must have complete dataset before DELETE`);
      }

      // DEFENSIVE CHECK: Check which timestamp columns exist (needed for maxTimestamp tracking)
      const timestamps = await this.hasTimestampColumns(sourceTableName);

      if (effectiveMode === 'incremental') {
        // CRITICAL FIX: Check if timestamp columns exist before querying

        if (!timestamps.hasEither) {
          // Neither created_at nor updated_at exists - MUST use full sync
          console.log(`  - [WARN]  Table ${sourceTableName} missing created_at/updated_at columns`);
          console.log(`  - [WARN]  Forcing FULL sync (incremental sync requires timestamp columns)`);
          sourceData = await this.sourcePool.query(`SELECT * FROM ${sourceTableName}`);
          console.log(`  - Extracted ${sourceData.rows.length} records (full sync - no timestamps)`);
        } else {
          // Get last sync timestamp for this table
          const lastSyncResult = await this.targetPool.query(`
            SELECT last_sync_timestamp
            FROM _sync_metadata
            WHERE table_name = $1
          `, [targetTableName]);

          const lastSync = lastSyncResult.rows[0]?.last_sync_timestamp || '1970-01-01';

          // Build WHERE clause based on which timestamp columns exist
          let whereClause;
          if (timestamps.hasBoth) {
            // Both columns exist - check either one
            whereClause = `WHERE updated_at > $1 OR created_at > $1`;
          } else if (timestamps.hasUpdatedAt) {
            // Only updated_at exists
            console.log(`  - [WARN]  Table ${sourceTableName} missing created_at column, using only updated_at`);
            whereClause = `WHERE updated_at > $1`;
          } else {
            // Only created_at exists
            console.log(`  - [WARN]  Table ${sourceTableName} missing updated_at column, using only created_at`);
            whereClause = `WHERE created_at > $1`;
          }

          // Only get records changed since last sync
          sourceData = await this.sourcePool.query(`
            SELECT * FROM ${sourceTableName}
            ${whereClause}
            ORDER BY COALESCE(updated_at, created_at, NOW())
          `, [lastSync]);

          console.log(`  - Extracted ${sourceData.rows.length} changed records since ${lastSync}`);
        }
      } else {
        // Full sync - get all records
        // CRITICAL FIX: Deduplicate if source table has duplicate PKs
        if (this.needsDeduplication(targetTableName)) {
          const pkColumn = this.getPrimaryKey(targetTableName);
          console.log(`  - [INFO] Deduplicating source records by ${pkColumn} (keeps most recent)`);
          sourceData = await this.sourcePool.query(`
            SELECT DISTINCT ON (${pkColumn}) *
            FROM ${sourceTableName}
            ORDER BY ${pkColumn}, updated_at DESC NULLS LAST, created_at DESC NULLS LAST
          `);
        } else {
          sourceData = await this.sourcePool.query(`SELECT * FROM ${sourceTableName}`);
        }
        console.log(`  - Extracted ${sourceData.rows.length} records (full sync)`);
      }

      if (sourceData.rows.length === 0) {
        console.log('  - No records to sync, skipping...\n');
        return;
      }

      // Step 1.5: Build lookup caches (if table has lookups defined)
      const columnMapping = config.columnMappings[sourceTableName];
      await this.buildLookupCache(targetTableName, columnMapping);

      // Step 2: Transform records
      const transformedRecords = sourceData.rows.map(row =>
        this.transformRecord(row, columnMapping, targetTableName)
      );
      console.log(`  - Transformed ${transformedRecords.length} records`);

      // Step 3: Filter invalid records
      const { validRecords, invalidRecords } = this.filterByForeignKeys(
        targetTableName,
        transformedRecords
      );

      if (invalidRecords.length > 0) {
        console.log(`  - Filtered ${invalidRecords.length} invalid records (FK violations)`);
        console.log(`  - Will sync ${validRecords.length} valid records`);

        // Show sample reasons
        const sampleReasons = invalidRecords.slice(0, 3);
        sampleReasons.forEach(inv => {
          console.log(`    [X] Skipped: ${inv.reasons[0]}`);
        });
        if (invalidRecords.length > 3) {
          console.log(`    [X] (${invalidRecords.length - 3} more filtered records...)`);
        }
      }

      this.syncStats.recordsFiltered += invalidRecords.length;

      if (validRecords.length === 0) {
        console.log('  - No valid records to sync after filtering\n');
        return;
      }

      // Track maximum timestamp from source records to prevent race condition
      // (See Issue #13: Forward Sync Metadata Timestamp Race Condition)
      let maxTimestamp = null;
      for (const record of validRecords) {
        const recordTimestamp = this.getRecordTimestamp(record, timestamps);
        if (recordTimestamp) {
          if (!maxTimestamp || recordTimestamp > maxTimestamp) {
            maxTimestamp = recordTimestamp;
          }
        }
      }

      // Step 4: CREATE STAGING TABLE
      const client = await this.targetPool.connect();

      try {
        // START TRANSACTION FIRST (temp table must be created inside transaction!)
        await client.query('BEGIN');

        console.log(`  - Creating staging table ${stagingTableName}...`);

        // Create temp table with same structure as target
        await client.query(`
          CREATE TEMP TABLE ${stagingTableName}
          (LIKE ${targetTableName} INCLUDING DEFAULTS)
          ON COMMIT DROP
        `);
        console.log(`  - [OK] Staging table created`);

        // Step 5: LOAD DATA INTO STAGING (no FK constraints!)
        console.log(`  - Loading data into staging table...`);
        let stagingLoaded = 0;

        for (const record of validRecords) {
          const columns = Object.keys(record);
          const values = Object.values(record);
          const placeholders = columns.map((_, i) => `$${i + 1}`);

          const insertQuery = `
            INSERT INTO ${stagingTableName} (${columns.join(', ')})
            VALUES (${placeholders.join(', ')})
          `;

          try {
            await client.query(insertQuery, values);
            stagingLoaded++;

            if (stagingLoaded % 1000 === 0) {
              console.log(`    [...] Loaded ${stagingLoaded}/${validRecords.length} to staging...`);
            }
          } catch (error) {
            console.error(`    [X] Error loading to staging:`, error.message.split('\n')[0]);
          }
        }

        console.log(`  - [OK] Loaded ${stagingLoaded} records to staging table`);

        if (stagingLoaded === 0) {
          console.log('  - No records loaded to staging, aborting sync\n');
          await client.query('ROLLBACK');
          return;
        }

        // Step 6: HYBRID SYNC - UPSERT or DELETE+INSERT based on table type
        // Tables with desktop PKs: Use UPSERT to preserve desktop IDs
        // Tables with mobile-only PKs: Use DELETE+INSERT (mobile generates fresh PKs)

        const hasMobileOnlyPK = this.hasMobileOnlyPK(targetTableName);

        if (hasMobileOnlyPK) {
          // Mobile-only PK tables (jobtasks, taskchecklist, workdiary)
          // Desktop doesn't have these PKs, so we can't UPSERT
          // Instead: DELETE desktop records + INSERT with fresh mobile PKs
          console.log(`  - Beginning DELETE+INSERT operation (mobile-only PK table)...`);
        } else {
          // Desktop PK tables (jobshead, climaster, reminder, etc.)
          // Desktop PKs are stable/unique, use UPSERT to preserve them
          console.log(`  - Beginning UPSERT operation (desktop PK table)...`);
        }

        // Disable FK checks temporarily for speed
        await client.query('SET CONSTRAINTS ALL DEFERRED');

        try {
          if (hasMobileOnlyPK) {
            // DELETE+INSERT pattern for mobile-only PK tables

            // Step 6a: Delete ONLY desktop records from production
            // Mobile records (source='M') remain untouched!
            const deleteResult = await client.query(`
              DELETE FROM ${targetTableName}
              WHERE source = 'D' OR source IS NULL
            `);
            console.log(`  - [OK] Deleted ${deleteResult.rowCount} desktop records (mobile data preserved)`);

            // Step 6b: Insert ALL records from staging (get fresh mobile PKs)
            // Desktop records get new mobile-generated primary keys
            const insertResult = await client.query(`
              INSERT INTO ${targetTableName}
              SELECT * FROM ${stagingTableName}
            `);
            console.log(`  - [OK] Inserted ${insertResult.rowCount} desktop records with fresh mobile PKs`);

          } else {
            // UPSERT pattern for desktop PK tables

            const pkColumn = this.getPrimaryKey(targetTableName);

            // Check if table has a 'source' column for filtering mobile data
            const hasSource = await this.hasSourceColumn(targetTableName);

            // Get all columns from staging table (except the PK itself for SET clause)
            const columnsResult = await client.query(`
              SELECT column_name
              FROM information_schema.columns
              WHERE table_name = $1
              AND column_name != $2
              ORDER BY ordinal_position
            `, [targetTableName, pkColumn]);

            const updateColumns = columnsResult.rows.map(r => r.column_name);
            const setClause = updateColumns
              .map(col => `${col} = EXCLUDED.${col}`)
              .join(', ');

            // Build UPSERT query with conditional WHERE clause
            // If table has 'source' column, only update desktop records (source='D')
            // If no 'source' column, update all conflicting records
            const whereClause = hasSource
              ? `WHERE ${targetTableName}.source = 'D' OR ${targetTableName}.source IS NULL`
              : '';

            const upsertQuery = `
              INSERT INTO ${targetTableName}
              SELECT * FROM ${stagingTableName}
              ON CONFLICT (${pkColumn}) DO UPDATE SET
                ${setClause}
              ${whereClause}
            `;

            const upsertResult = await client.query(upsertQuery);

            if (hasSource) {
              console.log(`  - [OK] Upserted ${upsertResult.rowCount} desktop records (preserved desktop PKs, mobile data untouched)`);
            } else {
              console.log(`  - [OK] Upserted ${upsertResult.rowCount} records (preserved desktop PKs)`);
            }
          }

          // Update sync metadata timestamp (for incremental sync tracking)
          // Use max timestamp from source records OR fallback to NOW() if no timestamps
          // This prevents race condition where updates between SELECT and this write are skipped
          const syncTimestamp = maxTimestamp || new Date();
          await client.query(`
            INSERT INTO _sync_metadata (table_name, last_sync_timestamp, records_synced)
            VALUES ($1, $2, $3)
            ON CONFLICT (table_name) DO UPDATE
            SET last_sync_timestamp = $2,
                records_synced = $3,
                updated_at = NOW()
          `, [targetTableName, syncTimestamp, stagingLoaded]);
          console.log(`  - [OK] Updated sync metadata for ${targetTableName}`);

          // COMMIT - this is the atomic moment!
          await client.query('COMMIT');

          if (hasMobileOnlyPK) {
            console.log(`  - [OK] Transaction committed (DELETE+INSERT complete)`);
          } else {
            console.log(`  - [OK] Transaction committed (UPSERT complete)`);
          }

          // Refresh FK cache if this table is referenced by other tables
          const tablesWithDependents = ['jobshead', 'climaster', 'mbstaff'];
          if (tablesWithDependents.includes(targetTableName)) {
            await this.refreshForeignKeyCache(targetTableName);
          }

        } catch (error) {
          // ROLLBACK - production data is restored!
          await client.query('ROLLBACK');
          console.error(`  - [X] Sync operation failed, rolling back:`, error.message);
          console.log(`  - [OK] Production data restored (unchanged)`);
          throw error;
        }

        // Step 7: Cleanup staging table (happens automatically with ON COMMIT DROP)
        console.log(`  - [OK] Staging table dropped`);

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        console.log(`  [OK] Loaded ${stagingLoaded} records to target`);
        console.log(`  Duration: ${duration}s\n`);

        this.syncStats.tablesProcessed++;
        this.syncStats.recordsProcessed += stagingLoaded;

      } finally {
        client.release();
      }

    } catch (error) {
      console.error(`  [X] Error syncing ${sourceTableName}:`, error.message);
      throw error;
    }
  }

  /**
   * Transform a record with column mappings
   */
  transformRecord(row, columnMapping, tableName) {
    const transformed = { ...row };

    if (columnMapping) {
      // Remove skip columns
      if (columnMapping.skipColumns) {
        columnMapping.skipColumns.forEach(col => {
          delete transformed[col];
        });
      }

      // Add additional columns
      if (columnMapping.addColumns) {
        Object.keys(columnMapping.addColumns).forEach(col => {
          const value = columnMapping.addColumns[col];
          transformed[col] = typeof value === 'function' ? value() : value;
        });
      }

      // Apply lookups from cache
      if (columnMapping.lookups) {
        Object.keys(columnMapping.lookups).forEach(targetColumn => {
          const lookupDef = columnMapping.lookups[targetColumn];
          const { matchOn } = lookupDef;

          // Get the lookup cache for this column
          const cacheKey = `${tableName}.${targetColumn}`;
          const lookupMap = this.lookupCache[cacheKey];

          if (lookupMap) {
            // Lookup the value using the matchOn field from the row
            const matchValue = row[matchOn]?.toString();
            const lookedUpValue = lookupMap.get(matchValue);

            if (lookedUpValue !== undefined) {
              transformed[targetColumn] = lookedUpValue;
            } else {
              // No matching value found in lookup table
              transformed[targetColumn] = null;
            }
          }
        });
      }
    }

    return transformed;
  }

  /**
   * Sync all tables
   */
  async syncAll(mode = 'full') {
    this.syncStats.startTime = new Date();
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Starting ${mode.toUpperCase()} SYNC (STAGING TABLE PATTERN)`);
    console.log(`Time: ${this.syncStats.startTime.toISOString()}`);
    console.log('='.repeat(60));
    console.log('\n[SAFE]  SAFE SYNC: Production data protected by staging tables');
    console.log('   If sync fails, production data remains untouched!\n');

    try {
      // Ensure _sync_metadata table exists (auto-provision if needed)
      await this.ensureSyncMetadataTable();

      // Pre-load FK references
      await this.preloadForeignKeys();

      // CRITICAL: Validate timestamp columns if running in incremental mode
      // This fails fast if tables are missing required columns
      if (mode === 'incremental') {
        await this.validateTimestampColumns();
      }

      // Sync master tables
      console.log('--- MASTER TABLES (Full Sync) ---');
      for (const sourceTableName of config.masterTables) {
        await this.syncTableSafe(sourceTableName, 'full');

        // Reload FK cache after each master table
        if (['orgmaster', 'locmaster', 'conmaster', 'climaster', 'mbstaff'].includes(sourceTableName)) {
          await this.preloadForeignKeys();
        }
      }

      // Sync transactional tables
      console.log('\n--- TRANSACTIONAL TABLES (Incremental Sync) ---');
      for (const sourceTableName of config.transactionalTables) {
        await this.syncTableSafe(sourceTableName, mode);
      }

      // Print summary
      this.syncStats.endTime = new Date();
      const duration = ((this.syncStats.endTime - this.syncStats.startTime) / 1000).toFixed(2);

      console.log('\n' + '='.repeat(60));
      console.log('SYNC COMPLETE!');
      console.log('='.repeat(60));
      console.log(`  Tables Synced:      ${this.syncStats.tablesProcessed}`);
      console.log(`  Records Processed:  ${this.syncStats.recordsProcessed}`);
      console.log(`  Records Filtered:   ${this.syncStats.recordsFiltered}`);
      console.log(`  Total Duration:     ${duration}s`);
      console.log('='.repeat(60));

    } catch (error) {
      console.error('\n[ERROR] SYNC FAILED:', error.message);
      console.error('Stack:', error.stack);
      throw error;
    } finally {
      await this.sourcePool.end();
      await this.targetPool.end();
    }
  }
}

module.exports = StagingSyncEngine;
