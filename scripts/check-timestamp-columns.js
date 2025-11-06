/**
 * Check which desktop tables have updated_at/created_at columns
 * This is critical for incremental sync functionality
 */

require('dotenv').config();
const { Pool } = require('pg');
const config = require('../sync/config');

async function checkTimestampColumns() {
  const pool = new Pool(config.source);

  const tables = [
    'orgmaster', 'locmaster', 'conmaster', 'climaster', 'mbstaff',
    'taskmaster', 'jobmaster', 'cliunimaster',
    'jobshead', 'jobtasks', 'taskchecklist', 'workdiary',
    'mbreminder', 'mbremdetail', 'learequest'
  ];

  console.log('Checking Desktop PostgreSQL for timestamp columns:\n');
  console.log('Table Name        | updated_at | created_at | Notes');
  console.log('─'.repeat(70));

  const results = [];

  for (const table of tables) {
    try {
      const result = await pool.query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = $1
        AND column_name IN ('updated_at', 'created_at')
      `, [table]);

      const hasUpdated = result.rows.some(r => r.column_name === 'updated_at');
      const hasCreated = result.rows.some(r => r.column_name === 'created_at');

      const updatedMark = hasUpdated ? '✓' : '✗';
      const createdMark = hasCreated ? '✓' : '✗';
      const note = (!hasUpdated && !hasCreated) ? 'NO TIMESTAMP COLUMNS!' : '';

      console.log(`${table.padEnd(17)} | ${updatedMark.padEnd(10)} | ${createdMark.padEnd(10)} | ${note}`);

      results.push({
        table,
        hasUpdated,
        hasCreated,
        canUseIncremental: hasUpdated || hasCreated
      });
    } catch (err) {
      console.log(`${table.padEnd(17)} | ERROR: ${err.message}`);
      results.push({
        table,
        hasUpdated: false,
        hasCreated: false,
        canUseIncremental: false,
        error: err.message
      });
    }
  }

  await pool.end();

  // Summary
  console.log('─'.repeat(70));
  const noTimestamps = results.filter(r => !r.canUseIncremental);
  console.log(`\nSummary:`);
  console.log(`  Total tables: ${results.length}`);
  console.log(`  With timestamps: ${results.filter(r => r.canUseIncremental).length}`);
  console.log(`  Without timestamps: ${noTimestamps.length}`);

  if (noTimestamps.length > 0) {
    console.log(`\n⚠️  Tables without timestamp columns (cannot use incremental sync):`);
    noTimestamps.forEach(r => console.log(`     - ${r.table}`));
  }

  return results;
}

if (require.main === module) {
  checkTimestampColumns()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Error:', err);
      process.exit(1);
    });
}

module.exports = checkTimestampColumns;
