/**
 * Cleanup Duplicate Rows in Supabase Tables
 *
 * Removes duplicate rows keeping only the most recent record
 * based on updated_at timestamp.
 */

const { Pool } = require('pg');
require('dotenv').config();

// Supabase connection
const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  max: 5,
  ssl: { rejectUnauthorized: false }
});

async function cleanupDuplicates() {
  try {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║          CLEANUP DUPLICATE ROWS IN SUPABASE              ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    // Tables to clean (master tables with duplicates)
    const tables = [
      { name: 'orgmaster', pk: 'org_id' },
      { name: 'locmaster', pk: 'loc_id' },
      { name: 'conmaster', pk: 'con_id' },
      { name: 'climaster', pk: 'client_id' },
      { name: 'mbstaff', pk: 'staff_id' }
    ];

    for (const table of tables) {
      console.log(`\n--- Processing ${table.name} ---`);

      // Check for duplicates
      const duplicates = await supabasePool.query(`
        SELECT ${table.pk}, COUNT(*) as count
        FROM ${table.name}
        GROUP BY ${table.pk}
        HAVING COUNT(*) > 1
      `);

      if (duplicates.rows.length === 0) {
        console.log(`[OK] No duplicates found in ${table.name}`);
        continue;
      }

      console.log(`[WARN] Found ${duplicates.rows.length} duplicate ${table.pk} values`);

      let totalDeleted = 0;

      // For each duplicate, keep only the most recent row
      for (const dup of duplicates.rows) {
        const pkValue = dup[table.pk];

        // Delete all but the most recent row
        const deleteResult = await supabasePool.query(`
          DELETE FROM ${table.name}
          WHERE ctid IN (
            SELECT ctid
            FROM ${table.name}
            WHERE ${table.pk} = $1
            ORDER BY updated_at DESC
            OFFSET 1
          )
        `, [pkValue]);

        const deletedCount = deleteResult.rowCount;
        totalDeleted += deletedCount;

        console.log(`  - ${table.pk}=${pkValue}: Kept 1, deleted ${deletedCount} duplicates`);
      }

      console.log(`[OK] Cleaned ${table.name}: Deleted ${totalDeleted} duplicate rows`);

      // Verify cleanup
      const afterCheck = await supabasePool.query(`
        SELECT ${table.pk}, COUNT(*) as count
        FROM ${table.name}
        GROUP BY ${table.pk}
        HAVING COUNT(*) > 1
      `);

      if (afterCheck.rows.length === 0) {
        console.log(`[OK] ${table.name} verified - no duplicates remaining`);
      } else {
        console.log(`[WARN] ${table.name} still has duplicates! (${afterCheck.rows.length})`);
      }
    }

    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║              ✅ CLEANUP COMPLETED                        ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');
    console.log('Next: Run the sync test again');
    console.log('  node sync/scheduler/test-single-client.js\n');

    await supabasePool.end();
    process.exit(0);

  } catch (error) {
    console.error('\n[ERROR] Cleanup failed:', error.message);
    console.error(error.stack);
    await supabasePool.end();
    process.exit(1);
  }
}

cleanupDuplicates();
