/**
 * Remove FK constraint on client_id in reminder
 * This allows reminder to accept any client_id without validation
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
    console.log('REMOVING client_id FK CONSTRAINT FROM reminder');
    console.log('='.repeat(60));

    // Drop the FK constraint
    console.log('\nDropping FK constraint...');
    await client.query(`
      ALTER TABLE reminder
      DROP CONSTRAINT reminder_client_id_fkey
    `);
    console.log('✓ FK constraint dropped');

    // Verify
    console.log('\nVerifying FK constraint removal...');
    const finalCheck = await client.query(`
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'reminder'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name = 'reminder_client_id_fkey'
    `);

    if (finalCheck.rows.length === 0) {
      console.log('✓ No FK constraint on client_id (success!)');
    } else {
      console.log('✗ FK constraint still exists');
    }

    console.log('\n' + '='.repeat(60));
    console.log('✓ OPERATION COMPLETED!');
    console.log('='.repeat(60));
    console.log('\nclient_id in reminder is now:');
    console.log('  - Not validated by FK constraint');
    console.log('  - Can accept any value');
    console.log('\nReady to sync all reminder records!');
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
