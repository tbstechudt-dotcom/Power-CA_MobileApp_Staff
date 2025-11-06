/**
 * Verify client_id=500 in local database
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

async function verifyClient500() {
  try {
    console.log('='.repeat(60));
    console.log('VERIFYING CLIENT_ID = 500');
    console.log('='.repeat(60));

    // 1. Check total clients in desktop
    console.log('\n1. Total clients in DESKTOP database:');
    const totalDesktop = await localPool.query('SELECT COUNT(*) as count FROM climaster');
    console.log(`   Total: ${totalDesktop.rows[0].count}`);

    // 2. Check if client 500 exists in desktop (use all columns)
    console.log('\n2. Checking if client_id=500 exists in DESKTOP:');
    const client500 = await localPool.query('SELECT * FROM climaster WHERE client_id = 500');

    if (client500.rows.length === 0) {
      console.log('   ❌ client_id=500 does NOT exist in desktop database');
    } else {
      console.log('   ✅ client_id=500 EXISTS in desktop database:');
      const client = client500.rows[0];
      console.log('   ', JSON.stringify(client, null, 2));

      // 3. Check FK values
      console.log('\n3. Foreign Key Values for client_id=500:');
      console.log(`   org_id: ${client.org_id}`);
      console.log(`   loc_id: ${client.loc_id}`);
      console.log(`   con_id: ${client.con_id}`);

      // 4. Validate each FK
      console.log('\n4. Foreign Key Validation:');

      // Check org_id
      const orgCheck = await localPool.query('SELECT org_id FROM orgmaster WHERE org_id = $1', [client.org_id]);
      console.log(`   org_id=${client.org_id}: ${orgCheck.rows.length > 0 ? '✅ Valid' : '❌ Invalid'}`);

      // Check loc_id
      const locCheck = await localPool.query('SELECT loc_id FROM locmaster WHERE loc_id = $1', [client.loc_id]);
      console.log(`   loc_id=${client.loc_id}: ${locCheck.rows.length > 0 ? '✅ Valid' : '❌ Invalid'}`);

      // Check con_id
      const conCheck = await localPool.query('SELECT con_id FROM conmaster WHERE con_id = $1', [client.con_id]);
      console.log(`   con_id=${client.con_id}: ${conCheck.rows.length > 0 ? '✅ Valid' : '❌ Invalid (or 0/NULL)'}`);

      // 5. Check if it exists in Supabase
      console.log('\n5. Checking if client_id=500 exists in SUPABASE:');
      const supabase500 = await supabasePool.query('SELECT * FROM climaster WHERE client_id = 500');

      if (supabase500.rows.length === 0) {
        console.log('   ❌ client_id=500 does NOT exist in Supabase');
        console.log('   Reason: Failed FK validation during sync');
      } else {
        console.log('   ✅ client_id=500 EXISTS in Supabase');
        console.log('   ', JSON.stringify(supabase500.rows[0], null, 2));
      }
    }

    // 6. Sample clients around 500
    console.log('\n6. Sampling client_ids around 500 (490-510):');
    const nearbyClients = await localPool.query(`
      SELECT client_id, org_id, loc_id, con_id
      FROM climaster
      WHERE client_id BETWEEN 490 AND 510
      ORDER BY client_id
    `);

    if (nearbyClients.rows.length === 0) {
      console.log('   No clients found in range 490-510');
    } else {
      console.log(`   Found ${nearbyClients.rows.length} clients:`);
      nearbyClients.rows.forEach(c => {
        console.log(`   client_id=${c.client_id}: org_id=${c.org_id}, loc_id=${c.loc_id}, con_id=${c.con_id}`);
      });
    }

    // 7. Check Supabase client count
    console.log('\n7. Total clients in SUPABASE:');
    const totalSupabase = await supabasePool.query('SELECT COUNT(*) as count FROM climaster');
    console.log(`   Total: ${totalSupabase.rows[0].count}`);

    // 8. Check jobs referencing client 500
    console.log('\n8. Jobs referencing client_id=500 in DESKTOP:');
    const jobs500 = await localPool.query('SELECT COUNT(*) as count FROM jobshead WHERE client_id = 500');
    console.log(`   Jobs with client_id=500: ${jobs500.rows[0].count}`);

    console.log('\n' + '='.repeat(60));

    await localPool.end();
    await supabasePool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

verifyClient500();
