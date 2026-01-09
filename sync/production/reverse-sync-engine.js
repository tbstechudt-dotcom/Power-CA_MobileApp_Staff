/**
 * Reverse Sync Engine - Supabase -> Desktop PostgreSQL
 *
 * Syncs mobile-generated data from Supabase Cloud back to local desktop database.
 * This enables full bidirectional sync and ensures all data exists in local PostgreSQL.
 */

const { Pool } = require('pg');
const config = require('./config');

class ReverseSyncEngine {
  constructor() {
    this.sourcePool = null; // Supabase (source)
    this.targetPool = null; // Local PostgreSQL (target)
    this.syncStats = {
      startTime: null,
      endTime: null,
      recordsSynced: 0,
      errors: [],
    };
    // Cache desktop table schemas to avoid repeated queries
    this.desktopSchemaCache = new Map();
  }

  /**
   * Initialize database connections
   */
  async initialize() {
    console.log('Initializing reverse sync engine (Supabase -> Desktop)...');

    try {
      // Connect to source (Supabase Cloud)
      this.sourcePool = new Pool(config.target); // Note: target config for Supabase
      await this.sourcePool.query('SELECT NOW()');
      console.log('[OK] Connected to Supabase Cloud (source)');

      // Connect to target (Local Desktop PostgreSQL)
      this.targetPool = new Pool(config.source); // Note: source config for local
      await this.targetPool.query('SELECT NOW()');
      console.log('[OK] Connected to Desktop PostgreSQL (target)');

      // Ensure _reverse_sync_metadata table exists (defensive bootstrap)
      await this.ensureReverseSyncMetadataTable();

      return true;
    } catch (error) {
      console.error('[X] Failed to initialize connections:', error.message);
      throw error;
    }
  }

  /**
   * Ensure _reverse_sync_metadata table exists (auto-provision if needed)
   * This makes the engine defensive - won't crash on first run
   */
  async ensureReverseSyncMetadataTable() {
    try {
      // Check if table exists
      const tableExists = await this.targetPool.query(`
        SELECT table_name
        FROM information_schema.tables
        WHERE table_name = '_reverse_sync_metadata'
      `);

      if (tableExists.rows.length > 0) {
        // Table already exists, skip creation
        return;
      }

      console.log('[WARN]  _reverse_sync_metadata table not found, creating...');

      // Create the table
      await this.targetPool.query(`
        CREATE TABLE _reverse_sync_metadata (
          table_name VARCHAR(100) PRIMARY KEY,
          last_sync_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT '1970-01-01',
          created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
      `);
      console.log('[OK] Created _reverse_sync_metadata table');

      // Seed initial records for mobile-created tables only (using DESKTOP table names)
      const tables = [
        'workdiary',           // Mobile time tracking
        'learequest',          // Mobile leave requests
        'mbjobreviewnotes',    // NEW: Job Review Notes
        'mbjobreviewresponse'  // NEW: Job Review Responses
      ];

      for (const table of tables) {
        await this.targetPool.query(`
          INSERT INTO _reverse_sync_metadata (table_name, last_sync_timestamp)
          VALUES ($1, '1970-01-01')
          ON CONFLICT (table_name) DO NOTHING
        `, [table]);
      }
      console.log(`[OK] Seeded ${tables.length} table records in _reverse_sync_metadata\n`);

    } catch (error) {
      console.error('[WARN]  Error ensuring _reverse_sync_metadata table:', error.message);
      // Don't throw - fall back gracefully, metadata tracking just won't work on first run
    }
  }

  /**
   * Close connections
   */
  async cleanup() {
    console.log('\nCleaning up connections...');
    if (this.sourcePool) await this.sourcePool.end();
    if (this.targetPool) await this.targetPool.end();
  }

  /**
   * Sync all records back to desktop (incremental)
   * Syncs ALL tables, but only inserts new records (no delete/update)
   */
  async syncMobileData() {
    this.syncStats.startTime = new Date();
    console.log(`\n${'='.repeat(60)}`);
    console.log(`REVERSE SYNC - Supabase to Desktop (Incremental)`);
    console.log(`Time: ${this.syncStats.startTime.toISOString()}`);
    console.log('='.repeat(60));
    console.log('\nMode: Incremental INSERT only (no delete/update)');
    console.log('Tracking: Metadata-based (last_sync_timestamp per table)');

    try {
      // ONLY sync mobile-created tables (workdiary, learequest, and review tables)
      // All other tables sync forward only (Desktop -> Supabase)
      const mobileCreatedTables = [
        'workdiary',           // Work diary entries (mobile time tracking)
        'learequest',          // Leave requests (mobile leave applications)
        'mbjobreviewnotes',    // NEW: Job Review Notes (mobile can add notes)
        'mbjobreviewresponse', // NEW: Job Review Responses (mobile can add responses)
      ];

      console.log('\n--- Mobile-Created Tables (Reverse Sync) ---');
      for (const tableName of mobileCreatedTables) {
        await this.syncTable(tableName);
      }

      this.syncStats.endTime = new Date();
      this.printSummary();

      return this.syncStats;
    } catch (error) {
      console.error('\n[X] Reverse sync failed:', error.message);
      throw error;
    }
  }

  /**
   * Sync a single table (incremental - new records only)
   * Uses metadata tracking to remember last sync timestamp
   */
  async syncTable(tableName) {
    console.log(`\nReverse syncing: ${tableName}`);
    const startTime = Date.now();

    try {
      // Get desktop table name for metadata lookup
      const desktopTableName = this.getDesktopTableName(tableName);

      // Get last sync timestamp from metadata (if exists)
      const lastSyncResult = await this.targetPool.query(`
        SELECT last_sync_timestamp
        FROM _reverse_sync_metadata
        WHERE table_name = $1
      `, [desktopTableName]);

      const lastSync = lastSyncResult.rows[0]?.last_sync_timestamp;

      // Check if table has updated_at column
      const hasUpdatedAt = await this.hasColumn(tableName, 'updated_at');

      let query;
      let queryParams = [];

      if (hasUpdatedAt && lastSync) {
        // Incremental: Only records updated since last sync
        query = `
          SELECT * FROM ${tableName}
          WHERE updated_at > $1
          ORDER BY updated_at DESC
        `;
        queryParams = [lastSync];
        console.log(`  - Fetching records updated since ${lastSync}`);
      } else if (hasUpdatedAt && !lastSync) {
        // First sync with updated_at: Get all records (no timestamp filter)
        query = `
          SELECT * FROM ${tableName}
          ORDER BY updated_at DESC
        `;
        console.log(`  - First sync: fetching all records`);
      } else {
        // No updated_at column: Get all records and check existence
        // WARNING: This can be slow for large tables
        query = `SELECT * FROM ${tableName}`;
        console.log(`  - [WARN]  Table lacks updated_at: fetching all records (may be slow)`);
      }

      const result = await this.sourcePool.query(query, queryParams);
      const supabaseRecords = result.rows;

      console.log(`  - Found ${supabaseRecords.length} records in Supabase`);

      if (supabaseRecords.length === 0) {
        console.log('  - No records to sync');
        return;
      }

      // Insert new records only (skip existing)
      let synced = 0;
      let skipped = 0;
      let maxTimestamp = null; // Track maximum timestamp actually processed

      for (const record of supabaseRecords) {
        try {
          const inserted = await this.insertNewToDesktop(desktopTableName, record);
          if (inserted) {
            synced++;
          } else {
            skipped++;
          }

          // Track maximum updated_at from processed records (to avoid race condition)
          if (hasUpdatedAt && record.updated_at) {
            const recordTimestamp = new Date(record.updated_at);
            if (!maxTimestamp || recordTimestamp > maxTimestamp) {
              maxTimestamp = recordTimestamp;
            }
          }
        } catch (error) {
          console.error(`  [X] Error syncing record:`, error.message.split('\n')[0]);
        }
      }

      console.log(`  [OK] Synced ${synced} new records to desktop (${skipped} already existed)`);
      this.syncStats.recordsSynced += synced;

      // Update metadata with MAX timestamp from processed records (NOT NOW())
      // This prevents race condition where records inserted between SELECT and UPDATE are skipped
      if (hasUpdatedAt && maxTimestamp) {
        await this.targetPool.query(`
          INSERT INTO _reverse_sync_metadata (table_name, last_sync_timestamp)
          VALUES ($1, $2)
          ON CONFLICT (table_name)
          DO UPDATE SET last_sync_timestamp = $2
        `, [desktopTableName, maxTimestamp]);
      }

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(`  Duration: ${duration}s`);

    } catch (error) {
      console.error(`  [X] Error syncing ${tableName}:`, error.message);
      this.syncStats.errors.push({ table: tableName, error: error.message });
    }
  }

  /**
   * Check if table has a specific column
   */
  async hasColumn(tableName, columnName) {
    try {
      const result = await this.sourcePool.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = $1 AND column_name = $2
      `, [tableName, columnName]);
      return result.rows.length > 0;
    } catch (error) {
      return false;
    }
  }

  /**
   * Get columns that exist in desktop table (with caching)
   * Returns Set of column names
   */
  async getDesktopTableColumns(tableName) {
    // Check cache first
    if (this.desktopSchemaCache.has(tableName)) {
      return this.desktopSchemaCache.get(tableName);
    }

    try {
      const result = await this.targetPool.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY ordinal_position
      `, [tableName]);

      const columns = new Set(result.rows.map(row => row.column_name));

      // Cache for future use
      this.desktopSchemaCache.set(tableName, columns);

      return columns;
    } catch (error) {
      console.error(`  [WARN]  Error getting desktop table columns for ${tableName}:`, error.message);
      return new Set();
    }
  }

  /**
   * Map mobile table names back to desktop table names
   */
  getDesktopTableName(mobileTableName) {
    const reverseMapping = {
      'reminder': 'mbreminder',
      'remdetail': 'mbremdetail',
    };

    return reverseMapping[mobileTableName] || mobileTableName;
  }

  /**
   * Insert new record to desktop database (ONLY INSERT, NO UPDATE/DELETE)
   * Returns true if inserted, false if already exists
   */
  async insertNewToDesktop(tableName, record) {
    // Get desktop table schema
    const desktopColumns = await this.getDesktopTableColumns(tableName);

    if (desktopColumns.size === 0) {
      throw new Error(`Could not get schema for desktop table: ${tableName}`);
    }

    // Remove mobile-specific columns that don't exist in desktop schema
    // NOTE: Keep 'source' column - desktop should track record origin (M=mobile, D=desktop)
    const desktopRecord = { ...record };
    delete desktopRecord.created_at;
    delete desktopRecord.updated_at;
    // Don't delete source - let column filtering handle it based on desktop schema

    // CRITICAL FIX: Only include columns that exist in desktop table
    // Filter out columns that exist in Supabase but not in desktop
    const filteredRecord = {};
    for (const [key, value] of Object.entries(desktopRecord)) {
      if (desktopColumns.has(key)) {
        filteredRecord[key] = value;
      }
    }

    // Transform data types to match desktop schema
    this.transformRecordForDesktop(tableName, filteredRecord);

    const pkColumn = this.getPrimaryKeyColumn(tableName);

    // Check if record already exists in desktop
    if (pkColumn && filteredRecord[pkColumn]) {
      const checkQuery = `SELECT 1 FROM ${tableName} WHERE ${pkColumn} = $1`;
      const exists = await this.targetPool.query(checkQuery, [filteredRecord[pkColumn]]);

      if (exists.rows.length > 0) {
        // Record already exists - SKIP (no update per requirement)
        return false;
      }
    }

    // Insert new record only
    const columns = Object.keys(filteredRecord);
    const values = Object.values(filteredRecord);
    const placeholders = columns.map((_, i) => `$${i + 1}`);

    const insertQuery = `
      INSERT INTO ${tableName} (${columns.join(', ')})
      VALUES (${placeholders.join(', ')})
    `;

    await this.targetPool.query(insertQuery, values);
    return true;
  }

  /**
   * Transform record data types to match desktop schema
   * Handles type mismatches between Supabase and Desktop PostgreSQL
   */
  transformRecordForDesktop(tableName, record) {
    // Workdiary-specific transformations
    if (tableName === 'workdiary') {
      // Convert TIME to TIMESTAMP by combining with date
      // Supabase: timefrom/timeto are TIME (e.g., "09:50:00")
      // Desktop: timefrom/timeto are TIMESTAMP (e.g., "2025-12-27 09:50:00")
      if (record.date) {
        const dateStr = record.date instanceof Date
          ? record.date.toISOString().split('T')[0]
          : String(record.date).split('T')[0];

        if (record.timefrom && typeof record.timefrom === 'string') {
          // Combine date + time into full timestamp
          record.timefrom = `${dateStr} ${record.timefrom}`;
        }
        if (record.timeto && typeof record.timeto === 'string') {
          // Combine date + time into full timestamp
          record.timeto = `${dateStr} ${record.timeto}`;
        }
      }

      // Truncate tasknotes to 50 chars (desktop varchar(50))
      if (record.tasknotes && record.tasknotes.length > 50) {
        record.tasknotes = record.tasknotes.substring(0, 50);
      }

      // Truncate doc_ref to 15 chars (desktop varchar(15))
      if (record.doc_ref && record.doc_ref.length > 15) {
        record.doc_ref = record.doc_ref.substring(0, 15);
      }
    }

    // Learequest-specific transformations (if needed)
    if (tableName === 'learequest') {
      // Add any learequest-specific transformations here
    }
  }

  /**
   * Get primary key column for a table
   */
  getPrimaryKeyColumn(tableName) {
    // Known primary keys for ALL Power CA tables
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
      'learequest': 'learequest_id',  // Desktop uses learequest_id, not lea_id
      'mbjobreviewnotes': 'rn_id',    // NEW: Job Review Notes
      'mbjobreviewresponse': 'res_id', // NEW: Job Review Responses
    };

    return primaryKeys[tableName];
  }

  /**
   * Print sync summary
   */
  printSummary() {
    const duration = (this.syncStats.endTime - this.syncStats.startTime) / 1000;

    console.log('\n' + '='.repeat(60));
    console.log('REVERSE SYNC SUMMARY');
    console.log('='.repeat(60));
    console.log(`Start Time:     ${this.syncStats.startTime.toISOString()}`);
    console.log(`End Time:       ${this.syncStats.endTime.toISOString()}`);
    console.log(`Duration:       ${duration.toFixed(2)}s`);
    console.log(`Records Synced: ${this.syncStats.recordsSynced}`);
    console.log(`Errors:         ${this.syncStats.errors.length}`);

    if (this.syncStats.errors.length > 0) {
      console.log('\nErrors:');
      this.syncStats.errors.forEach(err => {
        console.log(`  - ${err.table}: ${err.error}`);
      });
    }

    console.log('='.repeat(60));
  }
}

module.exports = ReverseSyncEngine;
