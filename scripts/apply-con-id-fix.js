/**
 * Apply con_id constraint fix to Supabase
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

async function applyFix() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(60));
    console.log('APPLYING con_id CONSTRAINT FIX');
    console.log('='.repeat(60));

    // 1. Insert dummy conmaster record
    console.log('\n1. Creating dummy contractor record (con_id=0)...');
    await client.query(`
      INSERT INTO conmaster (org_id, con_id, conname, source, created_at, updated_at)
      VALUES (1, 0, 'No Contractor', 'S', NOW(), NOW())
      ON CONFLICT (con_id) DO NOTHING
    `);

    const con0Check = await client.query('SELECT * FROM conmaster WHERE con_id = 0');
    if (con0Check.rows.length > 0) {
      console.log('   ✓ con_id=0 record created:', con0Check.rows[0]);
    } else {
      console.log('   ✗ Failed to create con_id=0 record');
      process.exit(1);
    }

    // 2. Make con_id nullable
    console.log('\n2. Making climaster.con_id nullable...');
    await client.query(`
      ALTER TABLE climaster
      ALTER COLUMN con_id DROP NOT NULL
    `);

    const columnCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'climaster' AND column_name = 'con_id'
    `);
    console.log('   ✓ Column definition:', columnCheck.rows[0]);

    // 3. Verify FK constraint still exists
    console.log('\n3. Verifying FK constraint...');
    const fkCheck = await client.query(`
      SELECT constraint_name, table_name, column_name
      FROM information_schema.key_column_usage
      WHERE table_name = 'climaster' AND column_name = 'con_id'
        AND constraint_name LIKE '%fkey%'
    `);

    if (fkCheck.rows.length > 0) {
      console.log('   ✓ FK constraint intact:', fkCheck.rows[0].constraint_name);
    }

    console.log('\n' + '='.repeat(60));
    console.log('✓ MIGRATION COMPLETED SUCCESSFULLY!');
    console.log('='.repeat(60));
    console.log('\nChanges applied:');
    console.log('  1. conmaster now includes con_id=0 ("No Contractor")');
    console.log('  2. climaster.con_id is now nullable');
    console.log('\nReady to restart sync with improved coverage!');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('\n❌ Error applying migration:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

applyFix();
