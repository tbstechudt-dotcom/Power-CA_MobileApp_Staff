/**
 * Add DEFAULT to wd_id column in Supabase workdiary table
 *
 * Issue: wd_id is a PRIMARY KEY with NOT NULL but NO DEFAULT
 * When sync creates staging table and INSERTs without wd_id, it fails
 *
 * Solution: Add DEFAULT nextval() to auto-generate wd_id values
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function addWdIdDefault() {
  try {
    console.log('\n' + '='.repeat(80));
    console.log('ADDING DEFAULT TO wd_id COLUMN IN workdiary');
    console.log('='.repeat(80));

    // Check if sequence exists
    console.log('\n[Step 1] Checking for existing sequence...');
    const seqCheck = await pool.query(`
      SELECT sequence_name
      FROM information_schema.sequences
      WHERE sequence_name LIKE '%workdiary%wd%'
         OR sequence_name LIKE '%wd_id%'
    `);

    let seqName;
    if (seqCheck.rows.length > 0) {
      seqName = seqCheck.rows[0].sequence_name;
      console.log('  ✓ Found existing sequence:', seqName);
    } else {
      console.log('  → No sequence found, creating workdiary_wd_id_seq...');
      await pool.query('CREATE SEQUENCE workdiary_wd_id_seq');

      // Set sequence to start after current max wd_id
      const maxResult = await pool.query('SELECT COALESCE(MAX(wd_id), 0) + 1 as next_val FROM workdiary');
      const nextVal = maxResult.rows[0].next_val;
      await pool.query(`SELECT setval('workdiary_wd_id_seq', ${nextVal})`);

      seqName = 'workdiary_wd_id_seq';
      console.log(`  ✓ Created sequence starting at ${nextVal}`);
    }

    // Add DEFAULT to wd_id column
    console.log('\n[Step 2] Adding DEFAULT to wd_id column...');
    await pool.query(`
      ALTER TABLE workdiary
      ALTER COLUMN wd_id SET DEFAULT nextval('${seqName}')
    `);
    console.log('  ✓ wd_id now has DEFAULT nextval()');

    // Verify
    console.log('\n[Step 3] Verifying...');
    const verify = await pool.query(`
      SELECT column_name, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'workdiary' AND column_name = 'wd_id'
    `);

    console.log('  wd_id column:');
    console.log('    - is_nullable:', verify.rows[0].is_nullable);
    console.log('    - column_default:', verify.rows[0].column_default);

    console.log('\n' + '='.repeat(80));
    console.log('✅ SUCCESS: wd_id can now auto-generate values!');
    console.log('='.repeat(80));
    console.log('\nSync should now work - staging table will inherit the DEFAULT');
    console.log('');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    throw error;
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  addWdIdDefault()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}

module.exports = addWdIdDefault;
