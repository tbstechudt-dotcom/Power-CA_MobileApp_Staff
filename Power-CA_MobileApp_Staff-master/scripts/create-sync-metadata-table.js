/**
 * Create _sync_metadata table for tracking incremental sync timestamps
 *
 * This table stores the last successful sync timestamp for each table,
 * enabling incremental sync (only sync changed records since last sync).
 *
 * Usage:
 *   node scripts/create-sync-metadata-table.js
 */

require('dotenv').config();
const { Pool } = require('pg');
const config = require('../sync/config');

async function createSyncMetadataTable() {
  const pool = new Pool(config.target); // Supabase Cloud

  try {
    console.log('Creating _sync_metadata table in Supabase...\n');

    // Create table if not exists
    await pool.query(`
      CREATE TABLE IF NOT EXISTS _sync_metadata (
        table_name VARCHAR(255) PRIMARY KEY,
        last_sync_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT '1970-01-01',
        last_sync_records INTEGER DEFAULT 0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);

    console.log('[OK] Table created successfully');

    // Initialize metadata for all synced tables
    const allTables = [
      // Master tables
      'orgmaster',
      'locmaster',
      'conmaster',
      'climaster',
      'mbstaff',
      'taskmaster',
      'jobmaster',
      'cliunimaster',
      // Transactional tables (using Supabase names)
      'jobshead',
      'jobtasks',
      'taskchecklist',
      'workdiary',
      'reminder',
      'remdetail',
      'learequest',
    ];

    console.log('\nInitializing sync metadata for all tables...\n');

    for (const tableName of allTables) {
      await pool.query(`
        INSERT INTO _sync_metadata (table_name, last_sync_timestamp)
        VALUES ($1, '1970-01-01')
        ON CONFLICT (table_name) DO NOTHING
      `, [tableName]);

      console.log(`  [OK] Initialized metadata for ${tableName}`);
    }

    console.log('\n[OK] All metadata initialized');

    // Show current state
    const result = await pool.query(`
      SELECT table_name, last_sync_timestamp, last_sync_records
      FROM _sync_metadata
      ORDER BY table_name
    `);

    console.log('\nCurrent sync metadata:');
    console.log('-'.repeat(70));
    console.log('Table Name          | Last Sync            | Records');
    console.log('-'.repeat(70));

    result.rows.forEach(row => {
      const tableName = row.table_name.padEnd(18);
      const lastSync = row.last_sync_timestamp.toISOString().substring(0, 19);
      const records = (row.last_sync_records || 0).toString().padStart(7);
      console.log(`${tableName} | ${lastSync} | ${records}`);
    });

    console.log('-'.repeat(70));
    console.log(`\nTotal tables tracked: ${result.rows.length}`);

  } catch (error) {
    console.error('\n[X] Error creating sync metadata table:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

// Run if executed directly
if (require.main === module) {
  createSyncMetadataTable()
    .then(() => {
      console.log('\n[OK] Sync metadata table ready for use!');
      process.exit(0);
    })
    .catch(error => {
      console.error('\n[X] Failed:', error);
      process.exit(1);
    });
}

module.exports = createSyncMetadataTable;
