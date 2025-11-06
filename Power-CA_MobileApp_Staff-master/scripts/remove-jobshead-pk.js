/**
 * Remove jobshead PRIMARY KEY constraint
 *
 * Desktop DB has duplicate job_id values (no PK constraint).
 * Supabase PK constraint blocks INSERT of duplicate job_ids.
 * Remove PK to mirror desktop behavior and allow sync.
 */

require('dotenv').config();
const { Pool } = require('pg');

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function removeJobsheadPK() {
  try {
    console.log('🔍 Checking jobshead PRIMARY KEY constraint...\n');

    // Check if PK exists
    const checkQuery = `
      SELECT constraint_name
      FROM information_schema.table_constraints
      WHERE table_name = 'jobshead'
        AND constraint_type = 'PRIMARY KEY'
    `;

    const result = await supabasePool.query(checkQuery);

    if (result.rows.length === 0) {
      console.log('✓ No PRIMARY KEY constraint on jobshead (already removed)\n');
      process.exit(0);
    }

    const pkName = result.rows[0].constraint_name;
    console.log(`⚠️  Found PRIMARY KEY constraint: ${pkName}`);
    console.log('📝 Desktop has DUPLICATE job_id values (no PK there)');
    console.log('📝 Removing PK to mirror desktop behavior\n');

    // Remove the PK constraint
    console.log('🔧 Removing PRIMARY KEY constraint...');
    await supabasePool.query(`
      ALTER TABLE jobshead
      DROP CONSTRAINT ${pkName}
    `);

    console.log(`✓ Successfully removed PRIMARY KEY "${pkName}"\n`);
    console.log('📌 Impact:');
    console.log('   - jobshead can now have duplicate job_id values');
    console.log('   - Mirrors desktop DB behavior (no PK enforcement)');
    console.log('   - DELETE+INSERT sync pattern will now work\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await supabasePool.end();
  }
}

removeJobsheadPK();
