/**
 * Create _reverse_sync_metadata Table in Desktop PostgreSQL
 *
 * This table tracks the last sync timestamp for each table during reverse sync
 * (Supabase -> Desktop), enabling proper incremental sync without 7-day window
 * or 10k record limits.
 *
 * Run this script ONCE before running reverse sync.
 */

require('dotenv').config();
const { Pool } = require('pg');

async function createReverseMetadataTable() {
  // Desktop PostgreSQL connection
  const desktopPool = new Pool({
    host: process.env.LOCAL_DB_HOST || 'localhost',
    port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
    database: process.env.LOCAL_DB_NAME || 'enterprise_db',
    user: process.env.LOCAL_DB_USER || 'postgres',
    password: process.env.LOCAL_DB_PASSWORD,
  });

  try {
    console.log('\n[INFO] Creating _reverse_sync_metadata table in desktop PostgreSQL...\n');

    // Check if table already exists
    const checkTable = await desktopPool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = '_reverse_sync_metadata'
      );
    `);

    if (checkTable.rows[0].exists) {
      console.log('[WARN]  Table _reverse_sync_metadata already exists!');
      console.log('   Would you like to:');
      console.log('   1. Keep existing table (preserves sync history)');
      console.log('   2. Drop and recreate (resets all timestamps)\n');
      console.log('   Keeping existing table...\n');

      // Show current metadata
      const metadata = await desktopPool.query(`
        SELECT table_name, last_sync_timestamp
        FROM _reverse_sync_metadata
        ORDER BY last_sync_timestamp DESC
      `);

      console.log('[STATS] Current reverse sync metadata:');
      if (metadata.rows.length === 0) {
        console.log('   (empty - no tables synced yet)');
      } else {
        metadata.rows.forEach(row => {
          console.log(`   - ${row.table_name}: ${row.last_sync_timestamp}`);
        });
      }

      console.log('\n[OK] Table exists and is ready to use.');
      return;
    }

    // Create the metadata table
    await desktopPool.query(`
      CREATE TABLE _reverse_sync_metadata (
        table_name VARCHAR(100) PRIMARY KEY,
        last_sync_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT '1970-01-01 00:00:00+00',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
    `);

    console.log('[OK] Created _reverse_sync_metadata table');

    // Create index for faster lookups
    await desktopPool.query(`
      CREATE INDEX idx_reverse_sync_metadata_timestamp
      ON _reverse_sync_metadata(last_sync_timestamp);
    `);

    console.log('[OK] Created index on last_sync_timestamp');

    // Seed with all tables that reverse sync processes
    const tables = [
      // Master tables
      'orgmaster',
      'locmaster',
      'conmaster',
      'climaster',
      'mbstaff',
      'taskmaster',
      'jobmaster',
      'cliunimaster',
      // Transactional tables (only safe ones that don't have mobile-PK issues)
      'jobshead',
      'mbreminder',  // Desktop name for 'reminder' Supabase table
      'learequest',
    ];

    console.log('\n📝 Seeding metadata for all reverse sync tables...');

    for (const table of tables) {
      await desktopPool.query(`
        INSERT INTO _reverse_sync_metadata (table_name, last_sync_timestamp)
        VALUES ($1, '1970-01-01 00:00:00+00')
        ON CONFLICT (table_name) DO NOTHING
      `, [table]);
      console.log(`   - Seeded: ${table}`);
    }

    console.log('\n[OK] Metadata table created and seeded successfully!');
    console.log('\n[STATS] Table structure:');
    console.log('   - table_name: Name of the desktop table');
    console.log('   - last_sync_timestamp: Last time this table was synced');
    console.log('   - created_at: When this metadata entry was created');
    console.log('   - updated_at: When this metadata entry was last updated');

    console.log('\n[>>] Ready to run reverse sync with proper incremental tracking!');
    console.log('   Run: node sync/production/reverse-sync-engine.js\n');

  } catch (error) {
    console.error('\n[ERROR] Error creating metadata table:', error.message);
    console.error(error.stack);
    process.exit(1);
  } finally {
    await desktopPool.end();
  }
}

if (require.main === module) {
  createReverseMetadataTable()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Error:', err);
      process.exit(1);
    });
}

module.exports = createReverseMetadataTable;
