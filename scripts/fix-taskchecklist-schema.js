/**
 * Fix taskchecklist schema to make job-specific columns nullable
 * This allows syncing generic task checklists from desktop
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

async function fixSchema() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(70));
    console.log('FIXING TASKCHECKLIST SCHEMA');
    console.log('='.repeat(70));

    console.log('\nMaking job-specific columns nullable...');
    console.log('(Desktop has generic task checklists without job info)');

    await client.query('BEGIN');

    // Make con_id nullable
    console.log('\n1. Making con_id nullable...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN con_id DROP NOT NULL
    `);
    console.log('   ✓ con_id is now nullable');

    // Make job_id nullable
    console.log('\n2. Making job_id nullable...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN job_id DROP NOT NULL
    `);
    console.log('   ✓ job_id is now nullable');

    // Make year_id nullable
    console.log('\n3. Making year_id nullable...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN year_id DROP NOT NULL
    `);
    console.log('   ✓ year_id is now nullable');

    // Make client_id nullable
    console.log('\n4. Making client_id nullable...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN client_id DROP NOT NULL
    `);
    console.log('   ✓ client_id is now nullable');

    // Make checklistdesc nullable (it's NOT NULL but might have nulls)
    console.log('\n5. Making checklistdesc nullable...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN checklistdesc DROP NOT NULL
    `);
    console.log('   ✓ checklistdesc is now nullable');

    await client.query('COMMIT');

    console.log('\n' + '='.repeat(70));
    console.log('✓ SCHEMA UPDATE COMPLETE!');
    console.log('='.repeat(70));
    console.log('\ntaskchecklist can now accept:');
    console.log('  - Generic task checklists (no job info)');
    console.log('  - Job-specific checklists (with job info)');
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

fixSchema();
