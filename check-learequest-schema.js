const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkLeaRequestSchema() {
  try {
    console.log('[INFO] Checking learequest table schema...\n');

    // Get column info
    const columns = await pool.query(`
      SELECT column_name, data_type, character_maximum_length,
             is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'learequest'
      ORDER BY ordinal_position
    `);

    console.log('learequest table columns:');
    columns.rows.forEach(col => {
      const length = col.character_maximum_length ? `(${col.character_maximum_length})` : '';
      const nullable = col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL';
      const defaultVal = col.column_default ? ` DEFAULT ${col.column_default}` : '';
      console.log(`  - ${col.column_name}: ${col.data_type}${length} ${nullable}${defaultVal}`);
    });

    // Check for foreign key constraints
    const fkConstraints = await pool.query(`
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
        AND tc.table_name = 'learequest'
    `);

    if (fkConstraints.rows.length > 0) {
      console.log('\nForeign key constraints:');
      fkConstraints.rows.forEach(fk => {
        console.log(`  - ${fk.column_name} -> ${fk.foreign_table_name}.${fk.foreign_column_name}`);
      });
    } else {
      console.log('\n[INFO] No foreign key constraints');
    }

    // Check sample data
    const sampleData = await pool.query(`
      SELECT * FROM learequest
      ORDER BY created_at DESC
      LIMIT 3
    `);

    console.log(`\nSample records (${sampleData.rows.length} records):`);
    sampleData.rows.forEach((row, idx) => {
      console.log(`\n${idx + 1}. Record:`);
      Object.keys(row).forEach(key => {
        console.log(`   ${key}: ${row[key]}`);
      });
    });

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
  }
}

checkLeaRequestSchema();
