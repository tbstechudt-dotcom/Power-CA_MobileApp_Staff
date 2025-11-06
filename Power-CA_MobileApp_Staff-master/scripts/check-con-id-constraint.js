/**
 * Check con_id constraints in Supabase
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

async function checkConstraints() {
  try {
    console.log('='.repeat(60));
    console.log('CHECKING con_id CONSTRAINTS');
    console.log('='.repeat(60));

    // Check climaster column definition
    console.log('\n1. climaster.con_id column definition:');
    const colDef = await pool.query(`
      SELECT
        column_name,
        data_type,
        is_nullable,
        column_default
      FROM information_schema.columns
      WHERE table_name = 'climaster' AND column_name = 'con_id'
    `);
    console.log(colDef.rows[0]);

    // Check FK constraints on con_id
    console.log('\n2. Foreign key constraints on con_id:');
    const fkConstraints = await pool.query(`
      SELECT
        tc.constraint_name,
        tc.table_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name
      FROM information_schema.table_constraints AS tc
      JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
      JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
      WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_name = 'climaster'
        AND kcu.column_name = 'con_id'
    `);

    if (fkConstraints.rows.length === 0) {
      console.log('   No FK constraint on con_id');
    } else {
      console.log(fkConstraints.rows[0]);
    }

    // Check if con_id=0 exists in conmaster
    console.log('\n3. Checking if con_id=0 exists in conmaster:');
    const con0 = await pool.query('SELECT * FROM conmaster WHERE con_id = 0');
    if (con0.rows.length === 0) {
      console.log('   ❌ con_id=0 does NOT exist in conmaster');
    } else {
      console.log('   ✅ con_id=0 EXISTS in conmaster');
      console.log('   ', con0.rows[0]);
    }

    // Check count of clients with con_id=0 in desktop
    console.log('\n4. Clients with con_id=0 or NULL in DESKTOP:');
    const localPool = new Pool({
      host: process.env.LOCAL_DB_HOST || 'localhost',
      port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
      database: process.env.LOCAL_DB_NAME || 'enterprise_db',
      user: process.env.LOCAL_DB_USER || 'postgres',
      password: process.env.LOCAL_DB_PASSWORD,
    });

    const con0Count = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster
      WHERE con_id = 0 OR con_id IS NULL
    `);
    console.log(`   Clients with con_id=0 or NULL: ${con0Count.rows[0].count}`);

    await localPool.end();

    console.log('\n' + '='.repeat(60));
    await pool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

checkConstraints();
