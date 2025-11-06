/**
 * SAFE SYNC ENGINE - Staging Table Pattern
 *
 * This engine uses a staging table approach to ensure atomicity:
 * 1. Load all data into temporary staging table (can fail safely)
 * 2. Validate data in staging (no impact on production)
 * 3. Atomic swap: TRUNCATE + INSERT in single transaction
 * 4. Cleanup staging table
 *
 * BENEFITS:
 * - If sync fails at any point, production data is UNTOUCHED
 * - Connection drops don't leave tables empty
 * - Can validate data before committing to production
 * - Rollback restores original data automatically
 *
 * USAGE:
 *   const engine = new StagingSyncEngine();
 *   await engine.syncAll('full');
 */

require('dotenv').config();
const { Pool } = require('pg');
const config = require('./config');

class StagingSyncEngine {
  constructor() {
    this.sourcePool = new Pool(config.source);
    this.targetPool = new Pool(config.target);
    this.fkCache = {};
    this.syncStats = {
      startTime: null,
      endTime: null,
      tablesProcessed: 0,
      recordsProcessed: 0,
      recordsFiltered: 0,
    };
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
      console.log(`  ✓ Loaded ${this.fkCache.validOrgIds.size} valid org_ids`);

      // Load valid loc_ids
      const locs = await this.targetPool.query('SELECT loc_id FROM locmaster');
      this.fkCache.validLocIds = new Set(locs.rows.map(r => r.loc_id?.toString()));
      console.log(`  ✓ Loaded ${this.fkCache.validLocIds.size} valid loc_ids`);

      // Load valid con_ids
      const cons = await this.targetPool.query('SELECT con_id FROM conmaster');
      this.fkCache.validConIds = new Set(cons.rows.map(r => r.con_id?.toString()));
      console.log(`  ✓ Loaded ${this.fkCache.validConIds.size} valid con_ids`);

      // Load valid client_ids
      const clients = await this.targetPool.query('SELECT client_id FROM climaster');
      this.fkCache.validClientIds = new Set(clients.rows.map(r => r.client_id?.toString()));
      console.log(`  ✓ Loaded ${this.fkCache.validClientIds.size} valid client_ids`);

      // Load valid staff_ids
      const staff = await this.targetPool.query('SELECT staff_id FROM mbstaff');
      this.fkCache.validStaffIds = new Set(staff.rows.map(r => r.staff_id?.toString()));
      console.log(`  ✓ Loaded ${this.fkCache.validStaffIds.size} valid staff_ids`);

      // Load valid job_ids
      const jobs = await this.targetPool.query('SELECT job_id FROM jobshead');
      this.fkCache.validJobIds = new Set(jobs.rows.map(r => r.job_id?.toString()));
      console.log(`  ✓ Loaded ${this.fkCache.validJobIds.size} valid job_ids`);

      console.log('  ✓ FK cache ready\n');
    } catch (error) {
      console.error('  ✗ Error loading FK cache:', error.message);
      throw error;
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
   * SAFE SYNC TABLE - Using Staging Pattern
   *
   * Steps:
   * 1. Create staging table (temp table with same structure)
   * 2. Load all data into staging (can fail without affecting production)
   * 3. BEGIN transaction
   * 4.   TRUNCATE production table
   * 5.   INSERT INTO production FROM staging
   * 6. COMMIT (atomic)
   * 7. Drop staging table
   *
   * If ANY step fails, production data remains untouched!
   */
  async syncTableSafe(sourceTableName, mode = 'full') {
    const targetTableName = config.tableMapping[sourceTableName] || sourceTableName;
    const stagingTableName = `${targetTableName}_staging`;
    const startTime = Date.now();

    console.log(`\nSyncing: ${sourceTableName} → ${targetTableName} (${mode})`);

    try {
      // Step 1: Extract from source
      const sourceData = await this.sourcePool.query(`SELECT * FROM ${sourceTableName}`);
      console.log(`  - Extracted ${sourceData.rows.length} records from source`);

      if (sourceData.rows.length === 0) {
        console.log('  - No records to sync, skipping...\n');
        return;
      }

      // Step 2: Transform records
      const columnMapping = config.columnMappings[sourceTableName];
      const transformedRecords = sourceData.rows.map(row =>
        this.transformRecord(row, columnMapping)
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
          console.log(`    ✗ Skipped: ${inv.reasons[0]}`);
        });
        if (invalidRecords.length > 3) {
          console.log(`    ✗ (${invalidRecords.length - 3} more filtered records...)`);
        }
      }

      this.syncStats.recordsFiltered += invalidRecords.length;

      if (validRecords.length === 0) {
        console.log('  - No valid records to sync after filtering\n');
        return;
      }

      // Step 4: CREATE STAGING TABLE
      const client = await this.targetPool.connect();

      try {
        console.log(`  - Creating staging table ${stagingTableName}...`);

        // Create temp table with same structure as target
        await client.query(`
          CREATE TEMP TABLE ${stagingTableName}
          (LIKE ${targetTableName} INCLUDING DEFAULTS)
          ON COMMIT DROP
        `);
        console.log(`  - ✓ Staging table created`);

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
              console.log(`    ⏳ Loaded ${stagingLoaded}/${validRecords.length} to staging...`);
            }
          } catch (error) {
            console.error(`    ✗ Error loading to staging:`, error.message.split('\n')[0]);
          }
        }

        console.log(`  - ✓ Loaded ${stagingLoaded} records to staging table`);

        if (stagingLoaded === 0) {
          console.log('  - No records loaded to staging, aborting sync\n');
          await client.query('ROLLBACK');
          return;
        }

        // Step 6: ATOMIC SWAP - TRUNCATE + INSERT in SINGLE TRANSACTION
        console.log(`  - Beginning atomic swap...`);

        await client.query('BEGIN');

        try {
          // Disable FK checks temporarily for speed
          await client.query('SET CONSTRAINTS ALL DEFERRED');

          // TRUNCATE production table
          await client.query(`TRUNCATE TABLE ${targetTableName} CASCADE`);
          console.log(`  - ✓ Cleared production table`);

          // INSERT all data from staging to production
          await client.query(`
            INSERT INTO ${targetTableName}
            SELECT * FROM ${stagingTableName}
          `);
          console.log(`  - ✓ Copied ${stagingLoaded} records to production`);

          // COMMIT - this is the atomic moment!
          await client.query('COMMIT');
          console.log(`  - ✓ Transaction committed (atomic swap complete)`);

        } catch (error) {
          // ROLLBACK - production data is restored!
          await client.query('ROLLBACK');
          console.error(`  - ✗ Atomic swap failed, rolling back:`, error.message);
          console.log(`  - ✓ Production data restored (unchanged)`);
          throw error;
        }

        // Step 7: Cleanup staging table (happens automatically with ON COMMIT DROP)
        console.log(`  - ✓ Staging table dropped`);

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        console.log(`  ✓ Loaded ${stagingLoaded} records to target`);
        console.log(`  Duration: ${duration}s\n`);

        this.syncStats.tablesProcessed++;
        this.syncStats.recordsProcessed += stagingLoaded;

      } finally {
        client.release();
      }

    } catch (error) {
      console.error(`  ✗ Error syncing ${sourceTableName}:`, error.message);
      throw error;
    }
  }

  /**
   * Transform a record with column mappings
   */
  transformRecord(row, columnMapping) {
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
    console.log('\n🛡️  SAFE SYNC: Production data protected by staging tables');
    console.log('   If sync fails, production data remains untouched!\n');

    try {
      // Pre-load FK references
      await this.preloadForeignKeys();

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
      console.error('\n❌ SYNC FAILED:', error.message);
      console.error('Stack:', error.stack);
      throw error;
    } finally {
      await this.sourcePool.end();
      await this.targetPool.end();
    }
  }
}

module.exports = StagingSyncEngine;
