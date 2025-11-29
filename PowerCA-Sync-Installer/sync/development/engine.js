/**
 * Sync Engine - Core Sync Logic
 *
 * Handles data synchronization from local Power CA PostgreSQL to Supabase Cloud.
 * Implements table mapping, column transformations, and incremental sync logic.
 */

const { Pool } = require('pg');
const config = require('./config');

class SyncEngine {
  constructor() {
    this.sourcePool = null;
    this.targetPool = null;
    this.syncStats = {
      startTime: null,
      endTime: null,
      tablesProcessed: 0,
      recordsSynced: 0,
      errors: [],
    };
  }

  /**
   * Initialize database connections
   */
  async initialize() {
    console.log('Initializing sync engine...');

    try {
      // Connect to source database (local Power CA)
      this.sourcePool = new Pool(config.source);
      await this.sourcePool.query('SELECT NOW()');
      console.log('✓ Connected to source database (Local Power CA)');

      // Connect to target database (Supabase Cloud)
      this.targetPool = new Pool(config.target);
      await this.targetPool.query('SELECT NOW()');
      console.log('✓ Connected to target database (Supabase Cloud)');

      return true;
    } catch (error) {
      console.error('✗ Failed to initialize database connections:', error.message);
      throw error;
    }
  }

  /**
   * Close database connections
   */
  async cleanup() {
    console.log('\nCleaning up connections...');

    if (this.sourcePool) {
      await this.sourcePool.end();
      console.log('✓ Source connection closed');
    }

    if (this.targetPool) {
      await this.targetPool.end();
      console.log('✓ Target connection closed');
    }
  }

  /**
   * Sync all tables based on mode
   * @param {string} mode - 'full' or 'incremental'
   */
  async syncAll(mode = 'full') {
    this.syncStats.startTime = new Date();
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Starting ${mode.toUpperCase()} SYNC`);
    console.log(`Time: ${this.syncStats.startTime.toISOString()}`);
    console.log('='.repeat(60));

    try {
      // Sync master tables (always full sync)
      console.log('\n--- MASTER TABLES (Full Sync) ---');
      for (const sourceTableName of config.masterTables) {
        await this.syncTable(sourceTableName, 'full');
      }

      // Sync transactional tables
      console.log('\n--- TRANSACTIONAL TABLES (Incremental Sync) ---');
      for (const sourceTableName of config.transactionalTables) {
        await this.syncTable(sourceTableName, mode);
      }

      this.syncStats.endTime = new Date();
      this.printSummary();

      return this.syncStats;
    } catch (error) {
      console.error('\n✗ Sync failed:', error.message);
      this.syncStats.errors.push({ table: 'GENERAL', error: error.message });
      throw error;
    }
  }

  /**
   * Sync a single table
   * @param {string} sourceTableName - Source table name (desktop schema)
   * @param {string} mode - 'full' or 'incremental'
   */
  async syncTable(sourceTableName, mode = 'full') {
    const targetTableName = config.tableMapping[sourceTableName] || sourceTableName;
    const startTime = Date.now();

    console.log(`\nSyncing: ${sourceTableName} → ${targetTableName} (${mode})`);

    try {
      // Step 1: Extract data from source
      const sourceData = await this.extractData(sourceTableName, mode);
      console.log(`  - Extracted ${sourceData.length} records from source`);

      if (sourceData.length === 0) {
        console.log('  - No records to sync, skipping...');
        await this.updateSyncMetadata(targetTableName, 0, 'success', null);
        return;
      }

      // Step 2: Transform data
      const transformedData = await this.transformData(sourceTableName, sourceData);
      console.log(`  - Transformed ${transformedData.length} records`);

      // Step 3: Load data to target
      if (!config.sync.dryRun) {
        const recordsSynced = await this.loadData(targetTableName, transformedData, mode);
        console.log(`  ✓ Loaded ${recordsSynced} records to target`);

        // Step 4: Update sync metadata
        await this.updateSyncMetadata(targetTableName, recordsSynced, 'success', null);

        this.syncStats.tablesProcessed++;
        this.syncStats.recordsSynced += recordsSynced;
      } else {
        console.log('  [DRY RUN] Would have loaded records');
      }

      const duration = ((Date.now() - startTime) / 1000).toFixed(2);
      console.log(`  Duration: ${duration}s`);

    } catch (error) {
      console.error(`  ✗ Error syncing ${sourceTableName}:`, error.message);
      this.syncStats.errors.push({ table: sourceTableName, error: error.message });
      await this.updateSyncMetadata(targetTableName, 0, 'error', error.message);

      // Continue with other tables even if one fails
      if (!config.sync.continueOnError) {
        throw error;
      }
    }
  }

  /**
   * Extract data from source database
   */
  async extractData(tableName, mode) {
    let query = `SELECT * FROM ${tableName}`;

    // For incremental sync, only get records updated since last sync
    if (mode === 'incremental') {
      const targetTableName = config.tableMapping[tableName] || tableName;
      const lastSync = await this.getLastSyncTimestamp(targetTableName);

      if (lastSync && tableName !== 'mbstaff') {
        // Assuming tables have updated_at or similar timestamp column
        // For Power CA, we'll use a different approach based on available columns
        console.log(`  - Last sync: ${lastSync.toISOString()}`);
        // Note: This requires timestamp columns in source tables
        // For now, we'll do full sync and improve this later
      }
    }

    const result = await this.sourcePool.query(query);
    return result.rows;
  }

  /**
   * Transform data according to column mappings
   */
  async transformData(sourceTableName, sourceData) {
    const mapping = config.columnMappings[sourceTableName];

    if (!mapping) {
      // No special transformation needed, just add default columns
      return sourceData.map(row => ({
        ...row,
        source: 'D',
        created_at: new Date(),
        updated_at: new Date(),
      }));
    }

    const transformedData = [];

    for (const sourceRow of sourceData) {
      const transformedRow = { ...sourceRow };

      // Remove columns that should be skipped
      if (mapping.skipColumns) {
        mapping.skipColumns.forEach(col => {
          delete transformedRow[col];
        });
      }

      // Add new columns
      if (mapping.addColumns) {
        for (const [colName, value] of Object.entries(mapping.addColumns)) {
          transformedRow[colName] = typeof value === 'function' ? value() : value;
        }
      }

      // Handle lookups (e.g., client_id for jobtasks)
      if (mapping.lookups) {
        for (const [colName, lookup] of Object.entries(mapping.lookups)) {
          const lookupValue = await this.performLookup(
            lookup.fromTable,
            lookup.matchOn,
            sourceRow[lookup.matchOn],
            lookup.selectColumn
          );
          transformedRow[colName] = lookupValue;
        }
      }

      transformedData.push(transformedRow);
    }

    return transformedData;
  }

  /**
   * Perform database lookup for column values
   */
  async performLookup(fromTable, matchColumn, matchValue, selectColumn) {
    const query = `SELECT ${selectColumn} FROM ${fromTable} WHERE ${matchColumn} = $1`;
    const result = await this.sourcePool.query(query, [matchValue]);

    if (result.rows.length > 0) {
      return result.rows[0][selectColumn];
    }

    return null;
  }

  /**
   * Load data to target database
   */
  async loadData(tableName, data, mode) {
    let recordsLoaded = 0;
    let recordsFailed = 0;

    try {
      // Step 1: Clear existing data (if full sync) - use transaction for this
      if (mode === 'full') {
        const deleteClient = await this.targetPool.connect();
        try {
          await deleteClient.query('BEGIN');
          // Temporarily disable FK constraints for this session
          await deleteClient.query('SET CONSTRAINTS ALL DEFERRED');
          await deleteClient.query(`TRUNCATE TABLE ${tableName} CASCADE`);
          await deleteClient.query('COMMIT');
          console.log(`  - Cleared existing records from ${tableName}`);
        } catch (error) {
          await deleteClient.query('ROLLBACK');
          throw error;
        } finally {
          deleteClient.release();
        }
      }

      // Step 2: Insert records ONE BY ONE (autocommit mode) to handle FK errors gracefully
      const batchSize = config.sync.batchSize;

      for (let i = 0; i < data.length; i += batchSize) {
        const batch = data.slice(i, i + batchSize);

        for (const row of batch) {
          // Get a fresh connection for each insert (autocommit mode)
          const insertClient = await this.targetPool.connect();
          try {
            await this.upsertRecord(insertClient, tableName, row);
            recordsLoaded++;
          } catch (error) {
            recordsFailed++;
            // Only show first few errors to avoid cluttering output
            if (recordsFailed <= 3) {
              console.error(`  ✗ Error inserting record:`, error.message.split('\n')[0]);
            } else if (recordsFailed === 4) {
              console.error(`  ✗ (suppressing further error messages...)`);
            }
            await this.logSyncError(tableName, row, error.message);
          } finally {
            insertClient.release();
          }
        }

        const processed = Math.min(i + batchSize, data.length);
        console.log(`  - Processed ${processed}/${data.length} records (${recordsLoaded} succeeded, ${recordsFailed} failed)`);
      }

      if (recordsFailed > 0) {
        console.log(`  ⚠ Warning: ${recordsFailed} records failed due to data integrity issues`);
      }

      return recordsLoaded;

    } catch (error) {
      throw error;
    }
  }

  /**
   * Upsert a single record (insert or update on conflict)
   */
  async upsertRecord(client, tableName, record) {
    const columns = Object.keys(record);
    const values = Object.values(record);
    const placeholders = columns.map((_, i) => `$${i + 1}`);

    // Get primary key column for this table
    const pkColumn = await this.getPrimaryKeyColumn(tableName);

    if (!pkColumn) {
      // If no PK, just insert
      const insertQuery = `
        INSERT INTO ${tableName} (${columns.join(', ')})
        VALUES (${placeholders.join(', ')})
      `;
      return await client.query(insertQuery, values);
    }

    // Build UPSERT query with conflict resolution
    const updateColumns = columns
      .filter(col => col !== pkColumn)
      .map(col => `${col} = EXCLUDED.${col}`)
      .join(', ');

    const upsertQuery = `
      INSERT INTO ${tableName} (${columns.join(', ')})
      VALUES (${placeholders.join(', ')})
      ON CONFLICT (${pkColumn})
      DO UPDATE SET ${updateColumns}
    `;

    return await client.query(upsertQuery, values);
  }

  /**
   * Get primary key column for a table
   */
  async getPrimaryKeyColumn(tableName) {
    // Cache for primary keys
    if (!this._pkCache) {
      this._pkCache = {};
    }

    if (this._pkCache[tableName]) {
      return this._pkCache[tableName];
    }

    const query = `
      SELECT a.attname
      FROM pg_index i
      JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
      WHERE i.indrelid = $1::regclass AND i.indisprimary
    `;

    try {
      const result = await this.targetPool.query(query, [tableName]);
      const pkColumn = result.rows.length > 0 ? result.rows[0].attname : null;
      this._pkCache[tableName] = pkColumn;
      return pkColumn;
    } catch (error) {
      console.warn(`  Warning: Could not get PK for ${tableName}`);
      return null;
    }
  }

  /**
   * Get last sync timestamp for a table
   */
  async getLastSyncTimestamp(tableName) {
    const query = `
      SELECT last_sync_timestamp
      FROM _sync_metadata
      WHERE table_name = $1
    `;

    try {
      const result = await this.targetPool.query(query, [tableName]);
      if (result.rows.length > 0 && result.rows[0].last_sync_timestamp) {
        return new Date(result.rows[0].last_sync_timestamp);
      }
    } catch (error) {
      // Table might not exist yet
      console.warn(`  Warning: Could not get last sync timestamp for ${tableName}`);
    }

    return null;
  }

  /**
   * Update sync metadata after sync operation
   */
  async updateSyncMetadata(tableName, recordsSynced, status, errorMessage) {
    const query = `
      INSERT INTO _sync_metadata
        (table_name, last_sync_timestamp, records_synced, sync_status, error_message, updated_at)
      VALUES ($1, NOW(), $2, $3, $4, NOW())
      ON CONFLICT (table_name)
      DO UPDATE SET
        last_sync_timestamp = NOW(),
        records_synced = $2,
        sync_status = $3,
        error_message = $4,
        updated_at = NOW()
    `;

    try {
      await this.targetPool.query(query, [tableName, recordsSynced, status, errorMessage]);
    } catch (error) {
      console.warn(`  Warning: Could not update sync metadata:`, error.message);
    }
  }

  /**
   * Log sync error to _sync_log table
   */
  async logSyncError(tableName, record, errorMessage) {
    const query = `
      INSERT INTO _sync_log
        (table_name, operation, record_id, sync_timestamp, success, error_message)
      VALUES ($1, $2, $3, NOW(), false, $4)
    `;

    try {
      const recordId = JSON.stringify(record).substring(0, 100);
      await this.targetPool.query(query, [tableName, 'SYNC', recordId, errorMessage]);
    } catch (error) {
      console.warn(`  Warning: Could not log sync error:`, error.message);
    }
  }

  /**
   * Print sync summary
   */
  printSummary() {
    const duration = (this.syncStats.endTime - this.syncStats.startTime) / 1000;

    console.log('\n' + '='.repeat(60));
    console.log('SYNC SUMMARY');
    console.log('='.repeat(60));
    console.log(`Start Time:       ${this.syncStats.startTime.toISOString()}`);
    console.log(`End Time:         ${this.syncStats.endTime.toISOString()}`);
    console.log(`Duration:         ${duration.toFixed(2)}s`);
    console.log(`Tables Processed: ${this.syncStats.tablesProcessed}`);
    console.log(`Records Synced:   ${this.syncStats.recordsSynced}`);
    console.log(`Errors:           ${this.syncStats.errors.length}`);

    if (this.syncStats.errors.length > 0) {
      console.log('\nErrors:');
      this.syncStats.errors.forEach(err => {
        console.log(`  - ${err.table}: ${err.error}`);
      });
    }

    console.log('='.repeat(60));
  }

  /**
   * Test database connections
   */
  async testConnections() {
    console.log('Testing database connections...\n');

    try {
      // Test source
      const sourceResult = await this.sourcePool.query('SELECT version(), current_database()');
      console.log('✓ Source Database (Local Power CA):');
      console.log(`  Database: ${sourceResult.rows[0].current_database}`);
      console.log(`  Version: ${sourceResult.rows[0].version.split(' ').slice(0, 2).join(' ')}`);

      // Test target
      const targetResult = await this.targetPool.query('SELECT version(), current_database()');
      console.log('\n✓ Target Database (Supabase Cloud):');
      console.log(`  Database: ${targetResult.rows[0].current_database}`);
      console.log(`  Version: ${targetResult.rows[0].version.split(' ').slice(0, 2).join(' ')}`);

      // Check if sync metadata tables exist
      const metadataCheck = await this.targetPool.query(`
        SELECT COUNT(*) as count
        FROM information_schema.tables
        WHERE table_name IN ('_sync_metadata', '_sync_log')
      `);

      console.log(`\n✓ Sync metadata tables: ${metadataCheck.rows[0].count}/2 found`);

      return true;
    } catch (error) {
      console.error('✗ Connection test failed:', error.message);
      return false;
    }
  }
}

module.exports = SyncEngine;
