const { Pool } = require('pg');

const pool = new Pool({
  host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Powerca@2025',
  ssl: { rejectUnauthorized: false }
});

async function checkMMOrg() {
  try {
    // Get MM's details
    const staffResult = await pool.query(`
      SELECT staff_id, name, org_id, loc_id
      FROM mbstaff
      WHERE app_username = 'MM'
    `);

    const staff = staffResult.rows[0];
    console.log('MM Staff Details:');
    console.log(`  staff_id: ${staff.staff_id}`);
    console.log(`  name: ${staff.name}`);
    console.log(`  org_id: ${staff.org_id}`);
    console.log(`  loc_id: ${staff.loc_id}`);
    console.log('');

    // Count jobs by org_id
    if (staff.org_id) {
      const orgJobsResult = await pool.query(`
        SELECT COUNT(*) as count
        FROM jobshead
        WHERE org_id = $1
      `, [staff.org_id]);

      console.log(`Jobs for org_id ${staff.org_id}: ${orgJobsResult.rows[0].count}`);
    }

    // Count jobs by loc_id
    if (staff.loc_id) {
      const locJobsResult = await pool.query(`
        SELECT COUNT(*) as count
        FROM jobshead
        WHERE loc_id = $1
      `, [staff.loc_id]);

      console.log(`Jobs for loc_id ${staff.loc_id}: ${locJobsResult.rows[0].count}`);
    }

    console.log('');
    console.log('Recommendation: Show ALL jobs or filter by org_id/loc_id');
    console.log('Since jobshead has no staff_id column, we cannot filter by staff.');

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkMMOrg();
