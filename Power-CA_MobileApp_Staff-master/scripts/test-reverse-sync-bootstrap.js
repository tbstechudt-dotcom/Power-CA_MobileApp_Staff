/**
 * Test: Reverse Sync Metadata Bootstrap (Fresh Deployment)
 *
 * Simulates a fresh deployment where _reverse_sync_metadata table doesn't exist.
 * Verifies that the reverse sync engine auto-creates the table and seeds it.
 */

const { Pool } = require('pg');
const ReverseSyncEngine = require('../sync/production/reverse-sync-engine');

async function testBootstrap() {
  console.log('\n[TEST] Reverse Sync Metadata Bootstrap Test');
  console.log('='.repeat(60));
  console.log('Scenario: Fresh deployment - _reverse_sync_metadata table missing\n');

  const desktopPool = new Pool({
    host: 'localhost',
    port: 5433,
    database: 'enterprise_db',
    user: 'postgres',
    password: process.env.LOCAL_DB_PASSWORD
  });

  try {
    // Step 1: Drop the metadata table to simulate fresh deployment
    console.log('[INFO] Step 1: Simulating fresh deployment...');
    await desktopPool.query('DROP TABLE IF EXISTS _reverse_sync_metadata CASCADE');
    console.log('[OK] Dropped _reverse_sync_metadata table (if it existed)\n');

    // Step 2: Verify table doesn't exist
    console.log('[INFO] Step 2: Verifying table is missing...');
    const beforeCheck = await desktopPool.query(`
      SELECT table_name FROM information_schema.tables
      WHERE table_name = '_reverse_sync_metadata'
    `);

    if (beforeCheck.rows.length > 0) {
      throw new Error('Table still exists after drop!');
    }
    console.log('[OK] Confirmed: _reverse_sync_metadata table does not exist\n');

    // Step 3: Initialize reverse sync engine (should auto-create table)
    console.log('[INFO] Step 3: Initializing reverse sync engine...');
    const engine = new ReverseSyncEngine();
    await engine.initialize();
    console.log('[OK] Reverse sync engine initialized successfully\n');

    // Step 4: Verify table was created
    console.log('[INFO] Step 4: Verifying table was auto-created...');
    const afterCheck = await desktopPool.query(`
      SELECT table_name FROM information_schema.tables
      WHERE table_name = '_reverse_sync_metadata'
    `);

    if (afterCheck.rows.length === 0) {
      throw new Error('Table was NOT created during initialization!');
    }
    console.log('[OK] Table _reverse_sync_metadata was created\n');

    // Step 5: Verify table schema
    console.log('[INFO] Step 5: Verifying table schema...');
    const schemaCheck = await desktopPool.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_name = '_reverse_sync_metadata'
      ORDER BY ordinal_position
    `);

    const expectedColumns = ['table_name', 'last_sync_timestamp', 'created_at', 'updated_at'];
    const actualColumns = schemaCheck.rows.map(r => r.column_name);

    for (const col of expectedColumns) {
      if (!actualColumns.includes(col)) {
        throw new Error(`Missing column: ${col}`);
      }
    }
    console.log('[OK] Table schema is correct:');
    schemaCheck.rows.forEach(r => {
      console.log(`  - ${r.column_name} (${r.data_type})`);
    });
    console.log('');

    // Step 6: Verify table was seeded
    console.log('[INFO] Step 6: Verifying table was seeded...');
    const seedCheck = await desktopPool.query(`
      SELECT table_name, last_sync_timestamp
      FROM _reverse_sync_metadata
      ORDER BY table_name
    `);

    if (seedCheck.rows.length === 0) {
      throw new Error('Table was NOT seeded with initial records!');
    }

    console.log(`[OK] Table was seeded with ${seedCheck.rows.length} records:`);
    seedCheck.rows.forEach(r => {
      console.log(`  - ${r.table_name}: ${r.last_sync_timestamp}`);
    });
    console.log('');

    // Step 7: Test that queries don't crash
    console.log('[INFO] Step 7: Testing metadata queries...');
    const queryTest = await desktopPool.query(`
      SELECT last_sync_timestamp
      FROM _reverse_sync_metadata
      WHERE table_name = 'jobshead'
    `);

    if (queryTest.rows.length === 0) {
      throw new Error('Expected to find jobshead metadata record!');
    }
    console.log('[OK] Metadata queries work correctly');
    console.log(`  - jobshead last_sync_timestamp: ${queryTest.rows[0].last_sync_timestamp}\n`);

    // Cleanup
    await engine.cleanup();
    await desktopPool.end();

    // Final result
    console.log('='.repeat(60));
    console.log('[SUCCESS] Bootstrap test PASSED!');
    console.log('='.repeat(60));
    console.log('\n[STATS] Test Summary\n');
    console.log('[OK] Table auto-creation: Working');
    console.log('[OK] Schema validation: Correct');
    console.log('[OK] Table seeding: Working');
    console.log('[OK] Metadata queries: Working');
    console.log('[OK] Fresh deployment support: Verified\n');

    process.exit(0);

  } catch (error) {
    console.error('\n[ERROR] Bootstrap test FAILED:', error.message);
    console.error('\nStack trace:', error.stack);

    await desktopPool.end();
    process.exit(1);
  }
}

testBootstrap();
