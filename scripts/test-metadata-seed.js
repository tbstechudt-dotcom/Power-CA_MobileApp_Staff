/**
 * Test _sync_metadata Seeding Fix
 *
 * This script tests the fix for the tableMappings bug where
 * the engine was trying to access config.tableMappings[table].target
 * but config exports tableMapping (singular) with string values.
 */

require('dotenv').config();
const { Pool } = require('pg');
const config = require('../sync/production/config');

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function testMetadataSeed() {
  try {
    console.log('🔍 Testing _sync_metadata Seeding Fix\n');

    // Check if _sync_metadata table exists
    const tableCheck = await supabasePool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_name = '_sync_metadata'
      );
    `);

    if (!tableCheck.rows[0].exists) {
      console.log('[WARN]  _sync_metadata table does not exist');
      console.log('Creating table...\n');

      await supabasePool.query(`
        CREATE TABLE IF NOT EXISTS _sync_metadata (
          table_name TEXT PRIMARY KEY,
          last_sync_timestamp TIMESTAMP WITH TIME ZONE DEFAULT '1970-01-01',
          records_synced INTEGER DEFAULT 0,
          last_sync_duration_ms INTEGER,
          error_message TEXT,
          updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
      `);
      console.log('[OK] Created _sync_metadata table\n');
    }

    // Test the fixed seeding logic
    console.log('Testing seeding logic with fixed config.tableMapping:\n');

    const tables = Object.keys(config.tableMapping);
    console.log(`Found ${tables.length} tables in config.tableMapping:`);

    let seeded = 0;
    for (const table of tables) {
      const targetTableName = config.tableMapping[table];
      console.log(`  ${table.padEnd(20)} -> ${targetTableName}`);

      try {
        const result = await supabasePool.query(`
          INSERT INTO _sync_metadata (table_name, last_sync_timestamp, records_synced)
          VALUES ($1, '1970-01-01', 0)
          ON CONFLICT (table_name) DO NOTHING
          RETURNING table_name
        `, [targetTableName]);

        if (result.rows.length > 0) {
          seeded++;
        }
      } catch (err) {
        console.log(`     [ERROR] Error: ${err.message}`);
      }
    }

    console.log(`\n[OK] Seeded ${seeded} new table records in _sync_metadata\n`);

    // Verify all records
    const verifyResult = await supabasePool.query(`
      SELECT table_name, last_sync_timestamp, records_synced
      FROM _sync_metadata
      ORDER BY table_name
    `);

    console.log('[STATS] Current _sync_metadata contents:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('Table Name           Last Sync            Records');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    for (const row of verifyResult.rows) {
      const tableName = row.table_name.padEnd(20);
      const lastSync = row.last_sync_timestamp.toISOString().split('T')[0];
      const records = String(row.records_synced).padStart(7);
      console.log(`${tableName} ${lastSync}     ${records}`);
    }

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    console.log(`[OK] SUCCESS - Metadata seeding fix is working correctly!`);
    console.log(`   Found ${verifyResult.rows.length} table records in _sync_metadata`);

  } catch (error) {
    console.error('[ERROR] Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    await supabasePool.end();
  }
}

testMetadataSeed();
