/**
 * Compare climaster records between local and Supabase
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

const supabasePool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: parseInt(process.env.SUPABASE_DB_PORT || '5432'),
  database: process.env.SUPABASE_DB_NAME || 'postgres',
  user: process.env.SUPABASE_DB_USER || 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function compareClimaster() {
  try {
    console.log('='.repeat(70));
    console.log('CLIMASTER COMPARISON - LOCAL vs SUPABASE');
    console.log('='.repeat(70));

    // 1. Get total count from local
    console.log('\n1. LOCAL DATABASE (Desktop):');
    const localTotal = await localPool.query('SELECT COUNT(*) as count FROM climaster');
    console.log(`   Total records: ${localTotal.rows[0].count}`);

    // 2. Get total count from Supabase
    console.log('\n2. SUPABASE DATABASE (Mobile):');
    const supabaseTotal = await supabasePool.query('SELECT COUNT(*) as count FROM climaster');
    console.log(`   Total records: ${supabaseTotal.rows[0].count}`);

    // 3. Calculate missing
    const missing = parseInt(localTotal.rows[0].count) - parseInt(supabaseTotal.rows[0].count);
    console.log('\n3. DIFFERENCE:');
    console.log(`   Missing records: ${missing}`);

    // 4. Check for invalid FK records
    console.log('\n4. CHECKING FOR INVALID FK RECORDS IN LOCAL:');

    // Check org_id
    const invalidOrg = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM orgmaster o WHERE o.org_id = c.org_id)
    `);
    console.log(`   Invalid org_id: ${invalidOrg.rows[0].count} records`);

    // Check loc_id
    const invalidLoc = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
    `);
    console.log(`   Invalid loc_id: ${invalidLoc.rows[0].count} records`);

    // Check con_id (0 or NULL should be OK now)
    const invalidCon = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE c.con_id IS NOT NULL
        AND c.con_id != 0
        AND NOT EXISTS (SELECT 1 FROM conmaster cn WHERE cn.con_id = c.con_id)
    `);
    console.log(`   Invalid con_id (excluding 0/NULL): ${invalidCon.rows[0].count} records`);

    // 5. Get sample of missing records
    console.log('\n5. FINDING MISSING RECORDS:');
    const missingRecords = await localPool.query(`
      SELECT c.client_id, c.org_id, c.loc_id, c.con_id, c.cliename
      FROM climaster c
      WHERE NOT EXISTS (
        SELECT 1 FROM climaster
        WHERE client_id = c.client_id
      )
      ORDER BY c.client_id
      LIMIT 10
    `);

    // Actually, let me get client_ids from local that are NOT in Supabase
    console.log('   Getting client_ids from local...');
    const localIds = await localPool.query('SELECT client_id, org_id, loc_id, con_id FROM climaster ORDER BY client_id');
    const supabaseIds = await supabasePool.query('SELECT client_id FROM climaster ORDER BY client_id');

    const localClientIds = new Set(localIds.rows.map(r => r.client_id));
    const supabaseClientIds = new Set(supabaseIds.rows.map(r => r.client_id));

    const missingIds = [];
    for (const row of localIds.rows) {
      if (!supabaseClientIds.has(row.client_id)) {
        missingIds.push(row);
      }
    }

    console.log(`\n   Found ${missingIds.length} missing client_ids`);

    if (missingIds.length > 0) {
      console.log('\n6. SAMPLE OF MISSING RECORDS (first 20):');
      console.log('   client_id | org_id | loc_id | con_id | Reason');
      console.log('   ' + '-'.repeat(60));

      for (let i = 0; i < Math.min(20, missingIds.length); i++) {
        const rec = missingIds[i];

        // Check why it's missing
        let reason = '';

        // Check org_id
        const orgCheck = await localPool.query('SELECT org_id FROM orgmaster WHERE org_id = $1', [rec.org_id]);
        if (orgCheck.rows.length === 0) {
          reason = `Invalid org_id=${rec.org_id}`;
        }

        // Check loc_id
        const locCheck = await localPool.query('SELECT loc_id FROM locmaster WHERE loc_id = $1', [rec.loc_id]);
        if (locCheck.rows.length === 0) {
          reason = reason ? reason + ', ' : '';
          reason += `Invalid loc_id=${rec.loc_id}`;
        }

        // Check con_id (only if not 0 or NULL)
        if (rec.con_id !== null && rec.con_id !== 0) {
          const conCheck = await localPool.query('SELECT con_id FROM conmaster WHERE con_id = $1', [rec.con_id]);
          if (conCheck.rows.length === 0) {
            reason = reason ? reason + ', ' : '';
            reason += `Invalid con_id=${rec.con_id}`;
          }
        }

        if (!reason) {
          reason = 'Unknown - should be valid!';
        }

        console.log(`   ${rec.client_id} | ${rec.org_id} | ${rec.loc_id} | ${rec.con_id} | ${reason}`);
      }
    }

    console.log('\n' + '='.repeat(70));

    await localPool.end();
    await supabasePool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

compareClimaster();
