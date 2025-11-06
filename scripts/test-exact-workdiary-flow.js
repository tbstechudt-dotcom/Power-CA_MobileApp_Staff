/**
 * Test EXACT flow of the full bidirectional test for workdiary sync
 */

require('dotenv').config();
const { Pool } = require('pg');
const StagingSyncEngine = require('../sync/production/engine-staging');

const desktopPool = new Pool({
  host: process.env.LOCAL_DB_HOST,
  port: parseInt(process.env.LOCAL_DB_PORT),
  database: process.env.LOCAL_DB_NAME,
  user: process.env.LOCAL_DB_USER,
  password: process.env.LOCAL_DB_PASSWORD,
});

async function testExactFlow() {
  try {
    console.log('[Step 1] Creating staff and job records...');

    // Get next IDs (same as full test)
    const staffResult = await desktopPool.query('SELECT COALESCE(MAX(staff_id), 0) + 1 as next_id FROM mbstaff');
    const staffId = staffResult.rows[0].next_id;

    const jobResult = await desktopPool.query('SELECT COALESCE(MAX(job_id), 0) + 1 as next_id FROM jobshead');
    const jobId = jobResult.rows[0].next_id;

    // Create staff (like full test)
    await desktopPool.query(`
      INSERT INTO mbstaff (staff_id, org_id, loc_id, con_id, name, email)
      VALUES ($1, 1, 1, 3, 'Test-Exact-Flow', 'test@example.com')
    `, [staffId]);
    console.log('✓ Created staff:', staffId);

    // Create job (like full test)
    await desktopPool.query(`
      INSERT INTO jobshead (
        job_id, org_id, loc_id, con_id, client_id, work_desc, job_status,
        jobdate, created_at, updated_at
      ) VALUES ($1, 1, 1, 3, 1, 'TEST-EXACT-FLOW-JOB', 'A', CURRENT_DATE, NOW(), NOW())
    `, [jobId]);
    console.log('✓ Created job:', jobId);

    // Create workdiary (like full test - THIS IS THE KEY!)
    await desktopPool.query(`
      INSERT INTO workdiary (
        job_id, staff_id, org_id, loc_id, con_id, date, minutes, tasknotes, created_at, updated_at
      ) VALUES ($1, $2, 1, 1, 3, CURRENT_DATE, 270, 'TEST-EXACT-FLOW-WD', NOW(), NOW())
    `, [jobId, staffId]);
    console.log('✓ Created workdiary');

    console.log('\\n[Step 2] Syncing staff...');
    const engine = new StagingSyncEngine();
    await engine.preloadForeignKeys();
    await engine.syncTableSafe('mbstaff', 'full');
    console.log('✓ Staff synced');

    console.log('\\n[Step 3] Syncing job...');
    // Reload FK cache (like full test does)
    await engine.preloadForeignKeys();
    await engine.syncTableSafe('jobshead', 'full');
    console.log('✓ Job synced');

    console.log('\\n[Step 4] Syncing workdiary...');
    // Reload FK cache again
    await engine.preloadForeignKeys();
    await engine.syncTableSafe('workdiary', 'full');
    console.log('✓ Workdiary synced successfully!');

    console.log('\\n✅ SUCCESS: Exact flow test PASSED!');

    // Cleanup
    console.log('\\n[Cleanup]');
    await desktopPool.query("DELETE FROM workdiary WHERE tasknotes = 'TEST-EXACT-FLOW-WD'");
    await desktopPool.query('DELETE FROM jobshead WHERE job_id = $1', [jobId]);
    await desktopPool.query('DELETE FROM mbstaff WHERE staff_id = $1', [staffId]);
    console.log('✓ Cleaned up test data');

  } catch (error) {
    console.error('\\n❌ FAILED:', error.message);
    console.error('Stack:', error.stack);

    if (error.message.includes('wd_id')) {
      console.error('\\n🔍 THIS IS THE wd_id ERROR!');
      console.error('   The problem is confirmed in this exact flow test');
    }
  } finally {
    await desktopPool.end();
  }
}

testExactFlow();
