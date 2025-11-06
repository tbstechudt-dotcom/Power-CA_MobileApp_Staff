/**
 * Check why client_id=500 is invalid
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

async function checkClient500() {
  try {
    console.log('='.repeat(60));
    console.log('CHECKING CLIENT_ID = 500');
    console.log('='.repeat(60));

    // Check if client 500 exists in desktop
    console.log('\n1. Checking DESKTOP database (enterprise_db)...');
    const desktopClient = await localPool.query(`
      SELECT client_id, client_name, org_id, loc_id, con_id
      FROM climaster
      WHERE client_id = 500
    `);

    if (desktopClient.rows.length === 0) {
      console.log('   ❌ client_id=500 does NOT exist in desktop database');
    } else {
      console.log('   ✅ client_id=500 EXISTS in desktop database:');
      console.log('   ', JSON.stringify(desktopClient.rows[0], null, 2));

      // Check FK values
      const client = desktopClient.rows[0];
      console.log('\n   FK Values:');
      console.log(`      org_id:  ${client.org_id}`);
      console.log(`      loc_id:  ${client.loc_id}`);
      console.log(`      con_id:  ${client.con_id}`);

      // Check if FK values are valid
      const validOrgs = await localPool.query('SELECT org_id FROM orgmaster');
      const validLocs = await localPool.query('SELECT loc_id FROM locmaster');
      const validCons = await localPool.query('SELECT con_id FROM conmaster');

      console.log('\n   FK Validation:');
      console.log(`      org_id=${client.org_id}: ${validOrgs.rows.some(r => r.org_id == client.org_id) ? '✓ Valid' : '✗ Invalid'}`);
      console.log(`      loc_id=${client.loc_id}: ${validLocs.rows.some(r => r.loc_id == client.loc_id) ? '✓ Valid' : '✗ Invalid'}`);
      console.log(`      con_id=${client.con_id}: ${validCons.rows.some(r => r.con_id == client.con_id) ? '✗ Invalid (0 or NULL)' : '✓ Valid'}`);
    }

    // Check if client 500 exists in Supabase
    console.log('\n2. Checking SUPABASE database...');
    const supabaseClient = await supabasePool.query(`
      SELECT client_id, client_name, org_id, loc_id, con_id
      FROM climaster
      WHERE client_id = 500
    `);

    if (supabaseClient.rows.length === 0) {
      console.log('   ❌ client_id=500 does NOT exist in Supabase');
      console.log('   Reason: Did not pass FK validation during sync');
    } else {
      console.log('   ✅ client_id=500 EXISTS in Supabase');
      console.log('   ', JSON.stringify(supabaseClient.rows[0], null, 2));
    }

    // Check what clients ARE in Supabase
    console.log('\n3. Checking what clients ARE in Supabase...');
    const supabaseClients = await supabasePool.query(`
      SELECT COUNT(*) as count,
             MIN(client_id) as min_id,
             MAX(client_id) as max_id
      FROM climaster
    `);
    console.log(`   Total clients in Supabase: ${supabaseClients.rows[0].count}`);
    console.log(`   Client ID range: ${supabaseClients.rows[0].min_id} to ${supabaseClients.rows[0].max_id}`);

    // Sample of valid client IDs
    const sampleClients = await supabasePool.query(`
      SELECT client_id, client_name
      FROM climaster
      ORDER BY client_id
      LIMIT 20
    `);
    console.log('\n   Sample of valid client_ids in Supabase:');
    sampleClients.rows.forEach(c => {
      console.log(`      ${c.client_id}: ${c.client_name}`);
    });

    // Check jobs referencing client 500
    console.log('\n4. Checking jobs referencing client_id=500 in DESKTOP...');
    const jobsWithClient500 = await localPool.query(`
      SELECT COUNT(*) as count
      FROM jobshead
      WHERE client_id = 500
    `);
    console.log(`   Jobs with client_id=500: ${jobsWithClient500.rows[0].count}`);

    // Check breakdown of why clients failed
    console.log('\n5. Analyzing why 495 clients FAILED to sync (729 - 234)...');

    // Clients with invalid con_id
    const invalidCon = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster
      WHERE con_id = 0 OR con_id IS NULL
    `);
    console.log(`   Clients with con_id=0 or NULL: ${invalidCon.rows[0].count}`);

    // Clients with invalid org_id
    const invalidOrg = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM orgmaster o WHERE o.org_id = c.org_id)
    `);
    console.log(`   Clients with invalid org_id: ${invalidOrg.rows[0].count}`);

    // Clients with invalid loc_id
    const invalidLoc = await localPool.query(`
      SELECT COUNT(*) as count
      FROM climaster c
      WHERE NOT EXISTS (SELECT 1 FROM locmaster l WHERE l.loc_id = c.loc_id)
    `);
    console.log(`   Clients with invalid loc_id: ${invalidLoc.rows[0].count}`);

    console.log('\n' + '='.repeat(60));

    await localPool.end();
    await supabasePool.end();

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkClient500();
