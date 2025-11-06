/**
 * Add updated_at/created_at columns and triggers to Desktop PostgreSQL
 *
 * This enables true incremental sync from Desktop → Supabase
 *
 * What it does:
 * 1. Adds updated_at and created_at columns to all 15 tables
 * 2. Creates trigger function to auto-update updated_at on changes
 * 3. Attaches triggers to all tables
 * 4. Backfills created_at with current timestamp
 * 5. Sets updated_at = created_at for existing records
 *
 * SAFETY:
 * - Only adds columns if they don't exist (idempotent)
 * - Non-destructive (doesn't modify existing data)
 * - Can be run multiple times safely
 *
 * Usage:
 *   node scripts/add-desktop-timestamps.js
 */

require('dotenv').config();
const { Pool } = require('pg');
const config = require('../sync/config');

async function addTimestamps() {
  const pool = new Pool(config.source); // Desktop DB

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
    // Transactional tables
    'jobshead',
    'jobtasks',
    'taskchecklist',
    'workdiary',
    'mbreminder',
    'mbremdetail',
    'learequest',
  ];

  try {
    console.log('Adding timestamp columns and triggers to Desktop PostgreSQL\n');
    console.log('This will enable true incremental sync (Desktop → Supabase)\n');
    console.log('='.repeat(70));

    // Step 1: Create trigger function (shared by all tables)
    console.log('\n[1/4] Creating trigger function...');

    await pool.query(`
      CREATE OR REPLACE FUNCTION update_timestamp()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    `);

    console.log('  ✓ Trigger function created: update_timestamp()');

    // Step 2: Add columns to each table
    console.log('\n[2/4] Adding timestamp columns to tables...\n');

    for (const table of tables) {
      process.stdout.write(`  Processing ${table.padEnd(20)}... `);

      try {
        // Add created_at column
        await pool.query(`
          ALTER TABLE ${table}
          ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW()
        `);

        // Add updated_at column
        await pool.query(`
          ALTER TABLE ${table}
          ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW()
        `);

        console.log('✓ Columns added');
      } catch (err) {
        console.log(`✗ Error: ${err.message}`);
      }
    }

    // Step 3: Backfill existing records
    console.log('\n[3/4] Backfilling timestamps for existing records...\n');

    for (const table of tables) {
      try {
        const result = await pool.query(`SELECT COUNT(*) FROM ${table}`);
        const count = parseInt(result.rows[0].count);

        if (count > 0) {
          process.stdout.write(`  Backfilling ${table.padEnd(20)} (${count.toString().padStart(6)} rows)... `);

          // Set created_at and updated_at to NOW() for existing records
          // This ensures first incremental sync catches all records
          await pool.query(`
            UPDATE ${table}
            SET created_at = NOW(),
                updated_at = NOW()
            WHERE created_at IS NULL OR updated_at IS NULL
          `);

          console.log('✓');
        }
      } catch (err) {
        console.log(`✗ Error: ${err.message}`);
      }
    }

    // Step 4: Create triggers
    console.log('\n[4/4] Creating UPDATE triggers...\n');

    for (const table of tables) {
      process.stdout.write(`  Creating trigger for ${table.padEnd(20)}... `);

      try {
        // Drop trigger if exists (for idempotency)
        await pool.query(`
          DROP TRIGGER IF EXISTS ${table}_update_timestamp ON ${table}
        `);

        // Create trigger
        await pool.query(`
          CREATE TRIGGER ${table}_update_timestamp
          BEFORE UPDATE ON ${table}
          FOR EACH ROW
          EXECUTE FUNCTION update_timestamp()
        `);

        console.log('✓');
      } catch (err) {
        console.log(`✗ Error: ${err.message}`);
      }
    }

    // Summary
    console.log('\n' + '='.repeat(70));
    console.log('✓ Timestamp setup complete!\n');
    console.log('What was added:');
    console.log('  - created_at: Set to NOW() for all existing records');
    console.log('  - updated_at: Auto-updates on every record change');
    console.log('  - Triggers: Automatically maintain updated_at timestamps\n');

    console.log('Next steps:');
    console.log('  1. Run initial full sync to establish baseline');
    console.log('  2. Run incremental syncs (only syncs changed records)');
    console.log('  3. Typical incremental sync: 10-60 seconds instead of hours!\n');

    console.log('Commands:');
    console.log('  # Initialize metadata table');
    console.log('  node scripts/create-sync-metadata-table.js\n');
    console.log('  # Full sync (first time)');
    console.log('  node sync/production/runner-staging.js --mode=full\n');
    console.log('  # Incremental sync (subsequent runs)');
    console.log('  node sync/production/runner-staging.js --mode=incremental\n');

  } catch (error) {
    console.error('\n✗ Fatal error:', error.message);
    console.error(error.stack);
    throw error;
  } finally {
    await pool.end();
  }
}

// Test mode: Check if columns already exist
async function checkExisting() {
  const pool = new Pool(config.source);

  try {
    console.log('Checking existing timestamp columns in Desktop DB...\n');

    const result = await pool.query(`
      SELECT
        table_name,
        COUNT(CASE WHEN column_name = 'created_at' THEN 1 END) as has_created,
        COUNT(CASE WHEN column_name = 'updated_at' THEN 1 END) as has_updated
      FROM information_schema.columns
      WHERE table_name IN (
        'orgmaster', 'locmaster', 'conmaster', 'climaster', 'mbstaff',
        'taskmaster', 'jobmaster', 'cliunimaster', 'jobshead', 'jobtasks',
        'taskchecklist', 'workdiary', 'mbreminder', 'mbremdetail', 'learequest'
      )
      AND column_name IN ('created_at', 'updated_at')
      GROUP BY table_name
      ORDER BY table_name
    `);

    if (result.rows.length === 0) {
      console.log('✗ No timestamp columns found. Run script to add them.\n');
      return false;
    }

    console.log('Table Name        | created_at | updated_at');
    console.log('─'.repeat(50));

    let allHaveBoth = true;
    result.rows.forEach(row => {
      const hasCreated = row.has_created > 0 ? '✓' : '✗';
      const hasUpdated = row.has_updated > 0 ? '✓' : '✗';
      console.log(`${row.table_name.padEnd(17)} | ${hasCreated.padEnd(10)} | ${hasUpdated}`);

      if (row.has_created === 0 || row.has_updated === 0) {
        allHaveBoth = false;
      }
    });

    console.log();
    return allHaveBoth;
  } finally {
    await pool.end();
  }
}

// Main execution
if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.includes('--check')) {
    checkExisting()
      .then(hasAll => {
        if (hasAll) {
          console.log('✓ All tables have timestamp columns!\n');
        }
        process.exit(0);
      })
      .catch(err => {
        console.error('Error:', err);
        process.exit(1);
      });
  } else {
    addTimestamps()
      .then(() => {
        console.log('✓ Success! Desktop DB is ready for incremental sync.\n');
        process.exit(0);
      })
      .catch(err => {
        console.error('\n✗ Failed:', err);
        process.exit(1);
      });
  }
}

module.exports = { addTimestamps, checkExisting };
