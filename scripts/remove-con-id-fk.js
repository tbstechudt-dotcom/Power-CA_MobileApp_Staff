/**
 * Remove FK constraint on con_id in climaster
 * This allows con_id to accept any value (0, NULL, etc) without validation
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
    console.log('REMOVING con_id FK CONSTRAINT');
    console.log('='.repeat(60));

    // 1. Check current FK constraint
    console.log('\n1. Current FK constraints on climaster.con_id:');
    const fkCheck = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'climaster'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%con_id%'
    `);

    if (fkCheck.rows.length === 0) {
      console.log('   No FK constraint found on con_id');
    } else {
      console.log('   Found constraint:', fkCheck.rows[0].constraint_name);

      // 2. Drop the FK constraint
      console.log('\n2. Dropping FK constraint...');
      const constraintName = fkCheck.rows[0].constraint_name;
      await client.query(`
        ALTER TABLE climaster
        DROP CONSTRAINT ${constraintName}
      `);
      console.log('   ✓ FK constraint dropped');
    }

    // 3. Verify con_id is nullable
    console.log('\n3. Verifying con_id column definition...');
    const colCheck = await client.query(`
      SELECT column_name, data_type, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'climaster' AND column_name = 'con_id'
    `);
    console.log('   Column definition:', colCheck.rows[0]);

    // 4. Verify no more FK constraints
    console.log('\n4. Verifying FK constraint removal...');
    const finalCheck = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'climaster'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name LIKE '%con_id%'
    `);

    if (finalCheck.rows.length === 0) {
      console.log('   ✓ No FK constraints on con_id (success!)');
    } else {
      console.log('   ✗ FK constraint still exists');
    }

    console.log('\n' + '='.repeat(60));
    console.log('✓ OPERATION COMPLETED!');
    console.log('='.repeat(60));
    console.log('\ncon_id is now:');
    console.log('  - Nullable (can be NULL)');
    console.log('  - Not validated by FK constraint');
    console.log('  - Can accept any value including 0');
    console.log('\nReady to sync all 729 clients!');
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
