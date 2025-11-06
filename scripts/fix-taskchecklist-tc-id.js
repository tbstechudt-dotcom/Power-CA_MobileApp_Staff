/**
 * Fix taskchecklist tc_id constraint
 * Make tc_id an auto-incrementing primary key
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

async function fixTcIdConstraint() {
  const client = await pool.connect();

  try {
    console.log('='.repeat(70));
    console.log('FIXING taskchecklist tc_id - Make Auto-Increment PK');
    console.log('='.repeat(70));

    // Check current constraint
    console.log('\n1. Checking current tc_id structure...');
    const checkConstraint = await client.query(`
      SELECT
        column_name,
        is_nullable,
        column_default,
        data_type
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist'
      AND column_name = 'tc_id'
    `);

    if (checkConstraint.rows.length > 0) {
      const col = checkConstraint.rows[0];
      console.log(`   Column: ${col.column_name}`);
      console.log(`   Type: ${col.data_type}`);
      console.log(`   Nullable: ${col.is_nullable}`);
      console.log(`   Default: ${col.column_default || 'NULL'}`);
    }

    // Check if sequence exists
    console.log('\n2. Checking for sequence...');
    const checkSeq = await client.query(`
      SELECT sequence_name
      FROM information_schema.sequences
      WHERE sequence_name LIKE '%taskchecklist%tc_id%'
    `);

    let sequenceName;
    if (checkSeq.rows.length > 0) {
      sequenceName = checkSeq.rows[0].sequence_name;
      console.log(`   ✓ Found existing sequence: ${sequenceName}`);
    } else {
      // Create sequence
      console.log('   Creating new sequence...');
      sequenceName = 'taskchecklist_tc_id_seq';
      await client.query(`
        CREATE SEQUENCE IF NOT EXISTS ${sequenceName}
        START WITH 1
        INCREMENT BY 1
      `);
      console.log(`   ✓ Created sequence: ${sequenceName}`);
    }

    // Drop NOT NULL constraint first
    console.log('\n3. Dropping NOT NULL constraint...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN tc_id DROP NOT NULL
    `);
    console.log('   ✓ NOT NULL constraint dropped');

    // Set default to use sequence
    console.log('\n4. Setting auto-increment default...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN tc_id SET DEFAULT nextval('${sequenceName}')
    `);
    console.log(`   ✓ tc_id now defaults to nextval('${sequenceName}')`);

    // Update existing NULL values to use sequence
    console.log('\n5. Checking for existing NULL values...');
    const nullCount = await client.query(`
      SELECT COUNT(*) FROM taskchecklist WHERE tc_id IS NULL
    `);
    console.log(`   Found ${nullCount.rows[0].count} records with NULL tc_id`);

    if (parseInt(nullCount.rows[0].count) > 0) {
      console.log('   Updating NULL values to use sequence...');
      await client.query(`
        UPDATE taskchecklist
        SET tc_id = nextval('${sequenceName}')
        WHERE tc_id IS NULL
      `);
      console.log('   ✓ Updated NULL values');
    }

    // Now make it NOT NULL again
    console.log('\n6. Restoring NOT NULL constraint...');
    await client.query(`
      ALTER TABLE taskchecklist
      ALTER COLUMN tc_id SET NOT NULL
    `);
    console.log('   ✓ NOT NULL constraint restored');

    // Add primary key constraint if not exists
    console.log('\n7. Adding primary key constraint...');
    try {
      await client.query(`
        ALTER TABLE taskchecklist
        ADD PRIMARY KEY (tc_id)
      `);
      console.log('   ✓ Primary key constraint added');
    } catch (error) {
      if (error.message.includes('already exists')) {
        console.log('   ✓ Primary key constraint already exists');
      } else {
        throw error;
      }
    }

    // Verify the final state
    console.log('\n8. Verifying final structure...');
    const verifyConstraint = await client.query(`
      SELECT
        column_name,
        is_nullable,
        column_default,
        data_type
      FROM information_schema.columns
      WHERE table_name = 'taskchecklist'
      AND column_name = 'tc_id'
    `);

    if (verifyConstraint.rows.length > 0) {
      const col = verifyConstraint.rows[0];
      console.log(`   Column: ${col.column_name}`);
      console.log(`   Type: ${col.data_type}`);
      console.log(`   Nullable: ${col.is_nullable}`);
      console.log(`   Default: ${col.column_default}`);
    }

    console.log('\n' + '='.repeat(70));
    console.log('✓ CONSTRAINT FIX COMPLETE!');
    console.log('='.repeat(70));
    console.log('\ntaskchecklist.tc_id is now:');
    console.log('  ✓ Auto-incrementing (uses sequence)');
    console.log('  ✓ Primary key');
    console.log('  ✓ NOT NULL');
    console.log('\nSync engine must skip tc_id column during INSERT');
    console.log('(Let PostgreSQL auto-generate tc_id values)');
    console.log('='.repeat(70));

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

fixTcIdConstraint();
