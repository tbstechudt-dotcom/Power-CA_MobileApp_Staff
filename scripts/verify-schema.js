/**
 * Verify Supabase Schema - Check actual column structure
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
  database: process.env.SUPABASE_DB_NAME,
  user: process.env.SUPABASE_DB_USER,
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkSchema() {
  try {
    console.log('Connecting to Supabase...\n');

    // Check mbstaff columns
    console.log('='.repeat(60));
    console.log('MBSTAFF TABLE COLUMNS');
    console.log('='.repeat(60));

    const mbstaffColumns = await pool.query(`
      SELECT
        column_name,
        data_type,
        column_default,
        is_nullable,
        character_maximum_length
      FROM information_schema.columns
      WHERE table_name = 'mbstaff'
      ORDER BY ordinal_position
    `);

    if (mbstaffColumns.rows.length === 0) {
      console.log('❌ mbstaff table does not exist!\n');
    } else {
      mbstaffColumns.rows.forEach(col => {
        const marker = col.column_name === 'desc_id' ? ' ✓ FOUND' : '';
        console.log(`  ${col.column_name.padEnd(25)} ${col.data_type.padEnd(20)} ${marker}`);
      });
      console.log(`\nTotal columns: ${mbstaffColumns.rows.length}`);

      const hasDescId = mbstaffColumns.rows.some(r => r.column_name === 'desc_id');
      const hasDesId = mbstaffColumns.rows.some(r => r.column_name === 'des_id');

      console.log(`\n  desc_id exists: ${hasDescId ? '✅ YES' : '❌ NO'}`);
      console.log(`  des_id exists:  ${hasDesId ? '⚠️  YES (typo column)' : '✅ NO (good)'}`);
    }

    // Check jobtasks columns
    console.log('\n' + '='.repeat(60));
    console.log('JOBTASKS TABLE COLUMNS');
    console.log('='.repeat(60));

    const jobtasksColumns = await pool.query(`
      SELECT
        column_name,
        data_type,
        column_default,
        is_nullable
      FROM information_schema.columns
      WHERE table_name = 'jobtasks'
      ORDER BY ordinal_position
    `);

    if (jobtasksColumns.rows.length === 0) {
      console.log('❌ jobtasks table does not exist!\n');
    } else {
      jobtasksColumns.rows.forEach(col => {
        const marker = col.column_name === 'jt_id' ? ' ✓ FOUND' : '';
        console.log(`  ${col.column_name.padEnd(25)} ${col.data_type.padEnd(20)} ${marker}`);
      });
      console.log(`\nTotal columns: ${jobtasksColumns.rows.length}`);

      const hasJtId = jobtasksColumns.rows.some(r => r.column_name === 'jt_id');
      console.log(`\n  jt_id exists: ${hasJtId ? '✅ YES' : '❌ NO (needs to be added)'}`);
    }

    // Check jobtasks primary key
    console.log('\n' + '='.repeat(60));
    console.log('JOBTASKS PRIMARY KEY');
    console.log('='.repeat(60));

    const pk = await pool.query(`
      SELECT
        tc.constraint_name,
        string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as key_columns
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
      WHERE tc.table_name = 'jobtasks'
        AND tc.constraint_type = 'PRIMARY KEY'
      GROUP BY tc.constraint_name
    `);

    if (pk.rows.length > 0) {
      console.log(`  Current PK: ${pk.rows[0].key_columns}`);
    } else {
      console.log('  No primary key found');
    }

    await pool.end();
    console.log('\n✅ Schema verification complete\n');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkSchema();
