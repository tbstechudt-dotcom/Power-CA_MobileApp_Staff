/**
 * Apply Fixed sync_views_to_tables() Function
 *
 * This script replaces the old INSERT...ON CONFLICT DO NOTHING pattern
 * with proper UPSERT logic to prevent duplicate rows.
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const pool = new Pool({
  host: 'localhost',
  port: 5433,
  database: 'enterprise_db',
  user: 'postgres',
  password: process.env.LOCAL_DB_PASSWORD
});

async function applyFix() {
  try {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     FIX sync_views_to_tables() - UPSERT Logic            ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    // Read the SQL file (v2 - DELETE+INSERT pattern for tables without constraints)
    const sqlFile = path.join(__dirname, 'fix-sync-views-to-tables-v2.sql');
    const sql = fs.readFileSync(sqlFile, 'utf8');

    console.log('[INFO] Applying fixed function...\n');

    // Execute the SQL
    await pool.query(sql);

    console.log('[OK] Function updated successfully!\n');

    // Verify the function exists
    const verify = await pool.query(`
      SELECT pg_get_functiondef(p.oid) as definition
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'sync_views_to_tables'
        AND n.nspname = 'public'
    `);

    if (verify.rows.length > 0) {
      const def = verify.rows[0].definition;
      const hasUpsert = def.includes('ON CONFLICT') && def.includes('DO UPDATE');
      const hasWhereClause = def.includes('WHERE') && def.includes('source =');

      console.log('[OK] Verification:');
      console.log(`  - Function exists: ✅`);
      console.log(`  - Has UPSERT logic: ${hasUpsert ? '✅' : '❌'}`);
      console.log(`  - Preserves mobile data: ${hasWhereClause ? '✅' : '❌'}`);
      console.log('');

      if (hasUpsert && hasWhereClause) {
        console.log('╔═══════════════════════════════════════════════════════════╗');
        console.log('║              ✅ FIX APPLIED SUCCESSFULLY                  ║');
        console.log('╚═══════════════════════════════════════════════════════════╝\n');
        console.log('What changed:');
        console.log('  ✅ Replaced INSERT...ON CONFLICT DO NOTHING');
        console.log('  ✅ With INSERT...ON CONFLICT DO UPDATE');
        console.log('  ✅ Prevents duplicate rows from being created');
        console.log('  ✅ Updates existing rows instead of skipping');
        console.log('  ✅ Preserves mobile data (WHERE source = \'D\')');
        console.log('');
        console.log('Next Steps:');
        console.log('  1. Clean up existing duplicates:');
        console.log('     node cleanup-desktop-duplicates.js');
        console.log('  2. Test the full sync:');
        console.log('     node sync/scheduler/test-single-client.js');
        console.log('');
      } else {
        console.log('[WARN] Function updated but verification failed');
        console.log('       Please check the function manually');
      }
    } else {
      console.log('[ERROR] Function not found after update!');
    }

    await pool.end();
    process.exit(0);

  } catch (error) {
    console.error('\n[ERROR] Failed to apply fix:', error.message);
    console.error(error.stack);
    await pool.end();
    process.exit(1);
  }
}

applyFix();
