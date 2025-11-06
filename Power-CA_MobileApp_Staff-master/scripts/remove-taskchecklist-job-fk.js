/**
 * Remove FK constraint on job_id in taskchecklist
 * This allows taskchecklist to accept any job_id without validation
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

async function removeFkConstraint() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(60));
    console.log('REMOVING job_id FK CONSTRAINT FROM taskchecklist');
    console.log('='.repeat(60));

    // 1. Check current FK constraint
    console.log('\n1. Current FK constraints on taskchecklist.job_id:');
    const fkCheck = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'taskchecklist'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%job_id%'
    `);

    if (fkCheck.rows.length === 0) {
      console.log('   No FK constraint found on job_id');
    } else {
      console.log('   Found constraint:', fkCheck.rows[0].constraint_name);

      // 2. Drop the FK constraint
      console.log('\n2. Dropping FK constraint...');
      const constraintName = fkCheck.rows[0].constraint_name;
      await client.query(`
        ALTER TABLE taskchecklist
        DROP CONSTRAINT ${constraintName}
      `);
      console.log('   ✓ FK constraint dropped');
    }

    // 3. Verify job_id column definition
    console.log('\n3. Verifying job_id column definition...');
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist' AND column_name = 'job_id'
    `);
    console.log('   Column definition:', colCheck.rows[0]);

    // 4. Verify no more FK constraints
    console.log('\n4. Verifying FK constraint removal...');
    const finalCheck = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'taskchecklist'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%job_id%'
    `);

    if (finalCheck.rows.length === 0) {
      console.log('   ✓ No FK constraints on job_id (success!)');
    } else {
      console.log('   ✗ FK constraint still exists');
    }

    console.log('\n' + '='.repeat(60));
    console.log('✓ OPERATION COMPLETED!');
    console.log('='.repeat(60));
    console.log('\njob_id in taskchecklist is now:');
    console.log('  - Not validated by FK constraint');
    console.log('  - Can accept any value');
    console.log('\nReady to sync all taskchecklist records!');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

removeFkConstraint();
