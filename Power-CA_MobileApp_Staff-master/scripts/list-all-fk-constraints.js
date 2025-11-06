/**
 * List ALL Foreign Key Constraints on Transactional Tables
 *
 * This script queries Supabase to display all FK constraints on tables
 * that are involved in the sync process. Use this to verify which constraints
 * exist before and after removal.
 *
 * Usage:
 *   node scripts/list-all-fk-constraints.js
 *
 * Output:
 *   Displays constraint name, column, and referenced table for each FK
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function listAllFKConstraints() {
  try {
    const tables = [
      'jobshead',
      'jobtasks',
      'taskchecklist',
      'workdiary',
      'reminder',
      'remdetail',
      'climaster',
      'mbstaff',
      'learequest'
    ];

    console.log('\n' + '='.repeat(80));
    console.log('FOREIGN KEY CONSTRAINTS ON SYNC TABLES');
    console.log('='.repeat(80));
    console.log('Querying Supabase for FK constraints...\n');

    let totalConstraints = 0;
    const constraintsByTable = {};

    for (const table of tables) {
      const result = await pool.query(`
        SELECT
          tc.constraint_name,
          kcu.column_name,
          ccu.table_name AS foreign_table_name,
          ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_name = $1
          AND tc.table_schema = 'public'
        ORDER BY kcu.column_name
      `, [table]);

      constraintsByTable[table] = result.rows;
      totalConstraints += result.rows.length;
    }

    // Display results
    for (const table of tables) {
      const constraints = constraintsByTable[table];

      console.log(`${table.toUpperCase()}`);
      console.log('-'.repeat(80));

      if (constraints.length === 0) {
        console.log('  ✓ No FK constraints\n');
      } else {
        constraints.forEach(row => {
          console.log(`  ${row.column_name.padEnd(20)} → ${row.foreign_table_name}(${row.foreign_column_name})`);
          console.log(`    Constraint: ${row.constraint_name}`);
        });
        console.log('');
      }
    }

    console.log('='.repeat(80));
    console.log(`Total FK Constraints: ${totalConstraints}`);
    console.log('='.repeat(80));
    console.log('');

    return constraintsByTable;

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

// Run if called directly
if (require.main === module) {
  listAllFKConstraints()
    .then(() => {
      console.log('✓ Query completed successfully');
      process.exit(0);
    })
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}

module.exports = listAllFKConstraints;
