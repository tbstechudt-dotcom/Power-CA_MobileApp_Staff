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

      // Seed initial records for all reverse sync tables (using DESKTOP table names)
      const tables = [
        'orgmaster', 'locmaster', 'conmaster', 'climaster', 'mbstaff', 'taskmaster',
        'jobshead', 'mbreminder', 'learequest'  // Note: mbreminder (desktop) not reminder (Supabase)
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
      // Sync ALL tables in correct dependency order
      // Master tables first (reference data)
      const masterTables = [
        'orgmaster',     // Organizations
        'locmaster',     // Locations
        'conmaster',     // Contacts
        'climaster',     // Clients
        'mbstaff',       // Staff members
        'taskmaster',    // Task templates (optional)
        'jobmaster',     // Job templates (optional)
        'cliunimaster',  // Client units (optional)
      ];

      // Transactional tables (depend on master tables)
      // IMPORTANT: Only sync tables that can have TRULY mobile-created records
      // Tables with mobile-generated PKs are EXCLUDED to prevent duplicates
      const transactionalTables = [
        'jobshead',      // Job headers (uses job_id from desktop, safe to sync)
        // 'jobtasks',   // EXCLUDED: Uses jt_id (mobile-generated PK) - causes duplicates!
        // 'taskchecklist', // EXCLUDED: Uses tc_id (mobile-generated PK) - causes duplicates!
        // 'workdiary',  // EXCLUDED: Uses wd_id (mobile-generated PK) - causes duplicates!
        'reminder',      // Reminders (uses rem_id from desktop, safe to sync)
        // 'remdetail',  // EXCLUDED: Uses remd_id (mobile-generated PK) - causes duplicates!
        'learequest',    // Leave requests (mobile-created, uses lea_id)
      ];

      console.log('\n--- Master Tables ---');
      for (const tableName of masterTables) {
        await this.syncTable(tableName);
      }

      console.log('\n--- Transactional Tables ---');
      for (const tableName of transactionalTables) {
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
    const desktopRecord = { ...record };
    delete desktopRecord.created_at;
    delete desktopRecord.updated_at;
    delete desktopRecord.source;

    // CRITICAL FIX: Only include columns that exist in desktop table
    // Filter out columns that exist in Supabase but not in desktop
    const filteredRecord = {};
    for (const [key, value] of Object.entries(desktopRecord)) {
      if (desktopColumns.has(key)) {
        filteredRecord[key] = value;
      }
    }

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
      'learequest': 'lea_id',
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
