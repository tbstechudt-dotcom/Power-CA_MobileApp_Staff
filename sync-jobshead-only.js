const StagingSyncEngine = require('./sync/production/engine-staging');

async function syncJobshead() {
  const engine = new StagingSyncEngine();

  try {
    await engine.initialize();
    console.log('[INFO] Syncing jobshead table to populate job_uid...\n');

    // Sync only jobshead table
    await engine.syncTableSafe('jobshead', 'full');

    console.log('\n[OK] Sync completed!');
    console.log('[INFO] Now verify job_uid has data:');
    console.log('       node check-job-uid.js');

    await engine.close();
    process.exit(0);
  } catch (err) {
    console.error('[ERROR]', err.message);
    await engine.close();
    process.exit(1);
  }
}

syncJobshead();
