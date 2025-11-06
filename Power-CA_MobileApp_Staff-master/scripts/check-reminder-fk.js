/**
 * Check reminder FK constraints
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
  database: process.env.SUPABASE_DB_NAME || 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkReminderFK() {
  try {
    console.log('='.repeat(60));
    console.log('CHECKING REMINDER FK CONSTRAINTS');
    console.log('='.repeat(60));

    // Get all FK constraints on reminder table
    console.log('\nFK constraints on reminder table:');
    const reminderFKs = await pool.query(`
      SELECT
        tc.constraint_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name
      FROM information_schema.table_constraints AS tc
      JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
      JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
      WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_name = 'reminder'
    `);

    for (const fk of reminderFKs.rows) {
      console.log(`  - ${fk.column_name} → ${fk.foreign_table_name}(${fk.foreign_column_name})`);
      console.log(`    Constraint: ${fk.constraint_name}`);
    }

    console.log('\n' + '='.repeat(60));

    await pool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkReminderFK();
