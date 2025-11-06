/**
 * Fix jobtasks FK constraints and column nullability
 *
 * Changes:
 * 1. Remove FK constraint: jobtasks_job_id_fkey (jobtasks → jobshead)
 * 2. Remove FK constraint: jobtasks_task_id_fkey (jobtasks → taskmaster)
 * 3. Make job_id column nullable
 * 4. Make task_id column nullable
 *
 * This allows DELETE+INSERT sync pattern for jobshead without FK violations.
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

async function fixJobtasksConstraints() {
  try {
    console.log('🔍 Checking jobtasks FK constraints and column nullability...\n');

    // Check for FK constraints
    const checkFKQuery = `
      SELECT constraint_name, constraint_type
      FROM information_schema.table_constraints
      WHERE table_name = 'jobtasks'
        AND constraint_type = 'FOREIGN KEY'
        AND constraint_name IN ('jobtasks_job_id_fkey', 'jobtasks_task_id_fkey')
    `;

    const fkResult = await supabasePool.query(checkFKQuery);
    console.log(`Found ${fkResult.rows.length} FK constraints to remove:`);
    fkResult.rows.forEach(row => {
      console.log(`  - ${row.constraint_name}`);
    });
    console.log();

    // Check column nullability
    const checkNullQuery = `
      SELECT column_name, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'jobtasks'
        AND column_name IN ('job_id', 'task_id')
    `;

    const nullResult = await supabasePool.query(checkNullQuery);
    console.log('Current column nullability:');
    nullResult.rows.forEach(row => {
      console.log(`  - ${row.column_name}: ${row.is_nullable === 'YES' ? 'NULL allowed' : 'NOT NULL'}`);
    });
    console.log();

    // Remove FK constraints
    console.log('🔧 Removing FK constraints...');

    for (const row of fkResult.rows) {
      try {
        await supabasePool.query(`
          ALTER TABLE jobtasks DROP CONSTRAINT ${row.constraint_name}
        `);
        console.log(`  ✓ Removed: ${row.constraint_name}`);
      } catch (error) {
        if (error.message.includes('does not exist')) {
          console.log(`  ⊘ Already removed: ${row.constraint_name}`);
        } else {
          throw error;
        }
      }
    }
    console.log();

    // Make columns nullable
    console.log('🔧 Making columns nullable...');

    for (const row of nullResult.rows) {
      if (row.is_nullable === 'NO') {
        await supabasePool.query(`
          ALTER TABLE jobtasks ALTER COLUMN ${row.column_name} DROP NOT NULL
        `);
        console.log(`  ✓ Made nullable: ${row.column_name}`);
      } else {
        console.log(`  ⊘ Already nullable: ${row.column_name}`);
      }
    }
    console.log();

    console.log('✓ Successfully fixed jobtasks constraints!\n');
    console.log('📌 Impact:');
    console.log('   - jobshead can now use DELETE+INSERT pattern');
    console.log('   - No FK violations during sync');
    console.log('   - job_id and task_id can be NULL (mirrors desktop behavior)\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await supabasePool.end();
  }
}

fixJobtasksConstraints();
