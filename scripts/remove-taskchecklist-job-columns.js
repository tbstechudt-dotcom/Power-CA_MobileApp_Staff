/**
 * Remove job-specific columns from taskchecklist table
 * Makes it match the desktop structure (generic task templates)
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

async function removeColumns() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(70));
    console.log('REMOVING JOB-SPECIFIC COLUMNS FROM TASKCHECKLIST');
    console.log('='.repeat(70));

    await client.query('BEGIN');

    // 1. Drop primary key (includes job_id)
    console.log('\n1. Dropping primary key...');
    await client.query(`
      ALTER TABLE taskchecklist
      DROP CONSTRAINT IF EXISTS taskchecklist_pkey
    `);
    console.log('   ✓ Primary key dropped');

    // 2. Drop foreign key constraints
    console.log('\n2. Dropping foreign key constraints...');

    // Get all FK constraints
    const fks = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'taskchecklist'
      AND constraint_type = 'FOREIGN KEY'
    `);

    for (const fk of fks.rows) {
      console.log(`   - Dropping ${fk.constraint_name}...`);
      await client.query(`
        ALTER TABLE taskchecklist
        DROP CONSTRAINT IF EXISTS ${fk.constraint_name}
      `);
    }
    console.log('   ✓ All foreign keys dropped');

    // 3. Drop job-specific columns
    console.log('\n3. Dropping job-specific columns...');

    const columnsToDrop = ['con_id', 'job_id', 'year_id', 'client_id'];
    for (const col of columnsToDrop) {
      console.log(`   - Dropping ${col}...`);
      await client.query(`
        ALTER TABLE taskchecklist
        DROP COLUMN IF EXISTS ${col}
      `);
    }
    console.log('   ✓ All job-specific columns dropped');

    // 4. Add tc_id as BIGSERIAL primary key
    console.log('\n4. Adding tc_id as primary key...');
    await client.query(`
      ALTER TABLE taskchecklist
      ADD COLUMN tc_id BIGSERIAL PRIMARY KEY
    `);
    console.log('   ✓ tc_id column added as BIGSERIAL PRIMARY KEY');

    // 5. Re-add foreign keys for remaining columns
    console.log('\n5. Re-adding foreign key constraints...');

    await client.query(`
      ALTER TABLE taskchecklist
      ADD CONSTRAINT taskchecklist_org_id_fkey
      FOREIGN KEY (org_id) REFERENCES orgmaster(org_id)
    `);
    console.log('   ✓ org_id FK added');

    await client.query(`
      ALTER TABLE taskchecklist
      ADD CONSTRAINT taskchecklist_loc_id_fkey
      FOREIGN KEY (loc_id) REFERENCES locmaster(loc_id)
    `);
    console.log('   ✓ loc_id FK added');

    await client.query(`
      ALTER TABLE taskchecklist
      ADD CONSTRAINT taskchecklist_task_id_fkey
      FOREIGN KEY (task_id) REFERENCES taskmaster(task_id)
    `);
    console.log('   ✓ task_id FK added');

    await client.query('COMMIT');

    console.log('\n' + '='.repeat(70));
    console.log('✓ SCHEMA UPDATE COMPLETE!');
    console.log('='.repeat(70));
    console.log('\ntaskchecklist structure now matches desktop:');
    console.log('  - Generic task checklist templates');
    console.log('  - No job-specific information');
    console.log('  - Primary key: tc_id (auto-increment)');
    console.log('\nReady to sync taskchecklist!');
    console.log('='.repeat(70));

  } catch (error) {
    await client.query('ROLLBACK');
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

removeColumns();
