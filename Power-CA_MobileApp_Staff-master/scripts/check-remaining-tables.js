/**
 * Check why remaining tables didn't sync
 */

require('dotenv').config();
const { Pool } = require('pg');

const localPool = new Pool({
  host: process.env.LOCAL_DB_HOST || 'localhost',
  port: parseInt(process.env.LOCAL_DB_PORT || '5433'),
  database: process.env.LOCAL_DB_NAME || 'enterprise_db',
  user: process.env.LOCAL_DB_USER || 'postgres',
  password: process.env.LOCAL_DB_PASSWORD,
});

async function checkTables() {
  try {
    console.log('='.repeat(70));
    console.log('CHECKING UNSYNCED TABLES');
    console.log('='.repeat(70));

    // 1. taskchecklist
    console.log('\n1. TASKCHECKLIST (2,894 records in local):');
    const taskcheckTotal = await localPool.query('SELECT COUNT(*) as count FROM taskchecklist');
    console.log(`   Total records: ${taskcheckTotal.rows[0].count}`);

    // Check FK to jobshead
    const taskcheckValidJob = await localPool.query(`
      SELECT COUNT(*) as count
      FROM taskchecklist t
      WHERE EXISTS (SELECT 1 FROM jobshead j WHERE j.job_id = t.job_id)
    `);
    console.log(`   ✓ Valid job_id: ${taskcheckValidJob.rows[0].count}`);
    console.log(`   ✗ Invalid job_id: ${parseInt(taskcheckTotal.rows[0].count) - parseInt(taskcheckValidJob.rows[0].count)}`);

    // 2. reminder
    console.log('\n2. REMINDER (132 records in local):');
    const reminderTotal = await localPool.query('SELECT COUNT(*) as count FROM mbreminder');
    console.log(`   Total records: ${reminderTotal.rows[0].count}`);

    // Check FK to mbstaff
    const reminderValidStaff = await localPool.query(`
      SELECT COUNT(*) as count
      FROM mbreminder r
      WHERE EXISTS (SELECT 1 FROM mbstaff s WHERE s.staff_id = r.staff_id)
    `);
    console.log(`   ✓ Valid staff_id: ${reminderValidStaff.rows[0].count}`);
    console.log(`   ✗ Invalid staff_id: ${parseInt(reminderTotal.rows[0].count) - parseInt(reminderValidStaff.rows[0].count)}`);

    // 3. remdetail
    console.log('\n3. REMDETAIL (39 records in local):');
    const remdetailTotal = await localPool.query('SELECT COUNT(*) as count FROM mbremdetail');
    console.log(`   Total records: ${remdetailTotal.rows[0].count}`);

    // Check FK to jobshead and mbreminder
    const remdetailValidJob = await localPool.query(`
      SELECT COUNT(*) as count
      FROM mbremdetail r
      WHERE EXISTS (SELECT 1 FROM jobshead j WHERE j.job_id = r.job_id)
    `);
    console.log(`   ✓ Valid job_id: ${remdetailValidJob.rows[0].count}`);

    const remdetailValidRem = await localPool.query(`
      SELECT COUNT(*) as count
      FROM mbremdetail r
      WHERE EXISTS (SELECT 1 FROM mbreminder m WHERE m.rem_id = r.rem_id)
    `);
    console.log(`   ✓ Valid rem_id: ${remdetailValidRem.rows[0].count}`);

    const remdetailBothValid = await localPool.query(`
      SELECT COUNT(*) as count
      FROM mbremdetail r
      WHERE EXISTS (SELECT 1 FROM jobshead j WHERE j.job_id = r.job_id)
        AND EXISTS (SELECT 1 FROM mbreminder m WHERE m.rem_id = r.rem_id)
    `);
    console.log(`   ✓ Valid job_id AND rem_id: ${remdetailBothValid.rows[0].count}`);

    console.log('\n' + '='.repeat(70));
    console.log('SUMMARY:');
    console.log(`  taskchecklist: ${taskcheckValidJob.rows[0].count} records can sync (have valid job_id)`);
    console.log(`  reminder: ${reminderValidStaff.rows[0].count} records can sync (have valid staff_id)`);
    console.log(`  remdetail: ${remdetailBothValid.rows[0].count} records can sync (have valid FKs)`);
    console.log('='.repeat(70));

    await localPool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

checkTables();
