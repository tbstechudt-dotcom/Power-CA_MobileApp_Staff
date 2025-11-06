/**
 * Check climaster records in local database
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

async function checkLocalClimaster() {
  try {
    console.log('='.repeat(70));
    console.log('CLIMASTER ANALYSIS - LOCAL DATABASE');
    console.log('='.repeat(70));

    // 1. Total count
    console.log('\n1. TOTAL RECORDS IN LOCAL:');
    const total = await localPool.query('SELECT COUNT(*) as count FROM climaster');
    console.log(`   Total: ${total.rows[0].count}`);

    // 2. Check FK validity
    console.log('\n2. FOREIGN KEY VALIDATION:');

    // Valid org_id
    const validOrg = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE EXISTS (SELECT 1 FROM orgmaster o WHERE o.org_id = c.org_id)
    `);
    console.log(`   ✓ Valid org_id: ${validOrg.rows[0].count}`);

    // Invalid org_id
    const invalidOrg = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM orgmaster o WHERE o.org_id = c.org_id)
    `);
    console.log(`   ✗ Invalid org_id: ${invalidOrg.rows[0].count}`);

    // Valid loc_id
    const validLoc = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
    `);
    console.log(`   ✓ Valid loc_id: ${validLoc.rows[0].count}`);

    // Invalid loc_id
    const invalidLoc = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
    `);
    console.log(`   ✗ Invalid loc_id: ${invalidLoc.rows[0].count}`);

    // con_id = 0 or NULL (should be OK)
    const con0OrNull = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster
      WHERE con_id = 0 OR con_id IS NULL
    `);
    console.log(`   ✓ con_id is 0 or NULL: ${con0OrNull.rows[0].count}`);

    // Valid con_id (excluding 0/NULL)
    const validCon = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE c.con_id IS NOT NULL
        AND c.con_id != 0
        AND EXISTS (SELECT 1 FROM conmaster cn WHERE cn.con_id = c.con_id)
    `);
    console.log(`   ✓ Valid con_id (non-zero): ${validCon.rows[0].count}`);

    // Invalid con_id (excluding 0/NULL)
    const invalidCon = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE c.con_id IS NOT NULL
        AND c.con_id != 0
        AND NOT EXISTS (SELECT 1 FROM conmaster cn WHERE cn.con_id = c.con_id)
    `);
    console.log(`   ✗ Invalid con_id (non-zero): ${invalidCon.rows[0].count}`);

    // 3. Records that should sync (valid org_id AND valid loc_id)
    console.log('\n3. EXPECTED SYNC COUNT:');
    const shouldSync = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE EXISTS (SELECT 1 FROM orgmaster o WHERE o.org_id = c.org_id)
        AND EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
    `);
    console.log(`   Records with valid org_id AND loc_id: ${shouldSync.rows[0].count}`);
    console.log(`   (These should have synced to Supabase)`);

    // 4. Sample of invalid records
    console.log('\n4. SAMPLE OF INVALID RECORDS (first 10):');
    const invalidRecords = await localPool.query(`
      SELECT client_id, org_id, loc_id, con_id, cliename
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM orgmaster o WHERE o.org_id = c.org_id)
         OR NOT EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
      ORDER BY client_id
      LIMIT 10
    `);

    if (invalidRecords.rows.length > 0) {
      console.log('   client_id | org_id | loc_id | con_id | name');
      console.log('   ' + '-'.repeat(65));
      for (const rec of invalidRecords.rows) {
        const name = rec.cliename ? rec.cliename.substring(0, 20) : 'N/A';
        console.log(`   ${rec.client_id} | ${rec.org_id} | ${rec.loc_id} | ${rec.con_id} | ${name}`);
      }

      // Check why they're invalid
      console.log('\n5. WHY INVALID:');
      for (const rec of invalidRecords.rows) {
        const reasons = [];

        const orgCheck = await localPool.query('SELECT org_id FROM orgmaster WHERE org_id = $1', [rec.org_id]);
        if (orgCheck.rows.length === 0) {
          reasons.push(`org_id=${rec.org_id} not found`);
        }

        const locCheck = await localPool.query('SELECT loc_id FROM locmaster WHERE loc_id = $1', [rec.loc_id]);
        if (locCheck.rows.length === 0) {
          reasons.push(`loc_id=${rec.loc_id} not found`);
        }

        console.log(`   client_id=${rec.client_id}: ${reasons.join(', ')}`);
      }
    } else {
      console.log('   No invalid records found!');
    }

    console.log('\n' + '='.repeat(70));
    console.log('SUMMARY:');
    console.log(`  Local database has ${total.rows[0].count} total clients`);
    console.log(`  ${shouldSync.rows[0].count} clients should have synced to Supabase`);
    console.log(`  ${parseInt(total.rows[0].count) - parseInt(shouldSync.rows[0].count)} clients filtered due to FK violations`);
    console.log('='.repeat(70));

    await localPool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

checkLocalClimaster();
