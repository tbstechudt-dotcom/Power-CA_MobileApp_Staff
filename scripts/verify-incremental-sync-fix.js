/**
 * Verify Incremental Sync Fix - No Data Loss
 *
 * This script verifies that the incremental DELETE+INSERT data loss bug has been fixed.
 *
 * Expected Results:
 * - jobshead should have 24,562 desktop records (no loss)
 * - jobtasks should have 64,542 desktop records (no loss)
 * - Mobile records (source='M') should be preserved
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

async function verifyFix() {
  try {
    console.log('\n🔍 Verifying Incremental Sync Fix - No Data Loss\n');
    console.log('Expected Results:');
    console.log('  - jobshead: 24,562 desktop records');
    console.log('  - jobtasks: 64,542 desktop records');
    console.log('  - Mobile records preserved (source=\'M\')\n');

    // Check jobshead
    const jobsheadResult = await supabasePool.query(`
      SELECT
        COUNT(*) as total_records,
        COUNT(*) FILTER (WHERE source='D' OR source IS NULL) as desktop_records,
        COUNT(*) FILTER (WHERE source='M') as mobile_records
      FROM jobshead
    `);

    const jobshead = jobsheadResult.rows[0];
    console.log('📊 jobshead:');
    console.log(`   Total:   ${jobshead.total_records.padStart(6)}`);
    console.log(`   Desktop: ${jobshead.desktop_records.padStart(6)} ${jobshead.desktop_records === '24562' ? '✅' : '❌ EXPECTED 24562'}`);
    console.log(`   Mobile:  ${jobshead.mobile_records.padStart(6)}`);

    // Check jobtasks
    const jobtasksResult = await supabasePool.query(`
      SELECT
        COUNT(*) as total_records,
        COUNT(*) FILTER (WHERE source='D' OR source IS NULL) as desktop_records,
        COUNT(*) FILTER (WHERE source='M') as mobile_records
      FROM jobtasks
    `);

    const jobtasks = jobtasksResult.rows[0];
    console.log('\n📊 jobtasks:');
    console.log(`   Total:   ${jobtasks.total_records.padStart(6)}`);
    console.log(`   Desktop: ${jobtasks.desktop_records.padStart(6)} ${jobtasks.desktop_records === '64542' ? '✅' : '❌ EXPECTED 64542'}`);
    console.log(`   Mobile:  ${jobtasks.mobile_records.padStart(6)}`);

    // Final verdict
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    const jobsheadOK = jobshead.desktop_records === '24562';
    const jobtasksOK = jobtasks.desktop_records === '64542';

    if (jobsheadOK && jobtasksOK) {
      console.log('✅ VERIFICATION PASSED - No Data Loss!');
      console.log('   Incremental sync fix is working correctly.');
      console.log('   All desktop records preserved during DELETE+INSERT.');
    } else {
      console.log('❌ VERIFICATION FAILED - Data Loss Detected!');
      if (!jobsheadOK) {
        console.log(`   jobshead: Expected 24562, got ${jobshead.desktop_records}`);
        console.log(`   Loss: ${24562 - parseInt(jobshead.desktop_records)} records`);
      }
      if (!jobtasksOK) {
        console.log(`   jobtasks: Expected 64542, got ${jobtasks.desktop_records}`);
        console.log(`   Loss: ${64542 - parseInt(jobtasks.desktop_records)} records`);
      }
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await supabasePool.end();
  }
}

verifyFix();
