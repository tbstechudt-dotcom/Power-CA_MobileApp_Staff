/**
 * Remove FK constraint on task_id in jobtasks
 * This allows task_id to accept any value without validation
 * Similar to con_id fix - desktop DB doesn't enforce FK constraints
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
    console.log('REMOVING task_id FK CONSTRAINT');
    console.log('='.repeat(60));

    // 1. Check current FK constraint
    console.log('\n1. Current FK constraints on jobtasks.task_id:');
    const fkCheck = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'jobtasks'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%task_id%'
    `);

    if (fkCheck.rows.length === 0) {
      console.log('   No FK constraint found on task_id');
    } else {
      console.log('   Found constraint:', fkCheck.rows[0].constraint_name);

      // 2. Drop the FK constraint
      console.log('\n2. Dropping FK constraint...');
      const constraintName = fkCheck.rows[0].constraint_name;
      await client.query(`
        ALTER TABLE jobtasks
        DROP CONSTRAINT ${constraintName}
      `);
      console.log('   ✓ FK constraint dropped');
    }

    // 3. Verify task_id column definition
    console.log('\n3. Verifying task_id column definition...');
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'jobtasks' AND column_name = 'task_id'
    `);
    console.log('   Column definition:', colCheck.rows[0]);

    // 4. Verify no more FK constraints
    console.log('\n4. Verifying FK constraint removal...');
    const finalCheck = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'jobtasks'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%task_id%'
    `);

    if (finalCheck.rows.length === 0) {
      console.log('   ✓ No FK constraints on task_id (success!)');
    } else {
      console.log('   ✗ FK constraint still exists');
    }

    console.log('\n' + '='.repeat(60));
    console.log('✓ OPERATION COMPLETED!');
    console.log('='.repeat(60));
    console.log('\ntask_id is now:');
    console.log('  - Not validated by FK constraint');
    console.log('  - Can accept any value (desktop has orphaned task_ids)');
    console.log('\nReady to sync all jobtasks!');
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
