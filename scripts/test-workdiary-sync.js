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

async function testWorkdiarySync() {
  try {
    // Get an existing job_id
    const jobResult = await desktopPool.query('SELECT job_id FROM jobshead LIMIT 1');
    const validJobId = jobResult.rows[0]?.job_id || 4;

    console.log('Using job_id:', validJobId);

    // Create workdiary with valid job_id
    console.log('\nCreating workdiary with valid job_id...');
    await desktopPool.query(`
      INSERT INTO workdiary (
        job_id, staff_id, org_id, loc_id, con_id, date, minutes, tasknotes, created_at, updated_at
      ) VALUES ($1, 1, 1, 1, 3, CURRENT_DATE, 270, 'TEST-VALID-JOB', NOW(), NOW())
    `, [validJobId]);
    console.log('✓ Created workdiary record');

    // Sync
    console.log('\nRunning sync...');
    const engine = new StagingSyncEngine();
    await engine.preloadForeignKeys();

    await engine.syncTableSafe('workdiary', 'full');
    console.log('\n✓ SUCCESS: Workdiary sync completed!');

    // Cleanup
    await desktopPool.query("DELETE FROM workdiary WHERE tasknotes = 'TEST-VALID-JOB'");
    console.log('✓ Cleaned up test data');

  } catch (error) {
    console.error('\n❌ FAILED:', error.message);
    if (error.message.includes('wd_id')) {
      console.log('\n🔍 This is the wd_id NULL constraint error!');
      console.log('Stack trace:', error.stack);
    }
  } finally {
    await desktopPool.end();
  }
}

testWorkdiarySync();
