const { Pool } = require('pg');

const pool = new Pool({
  host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Powerca@2025',
  ssl: { rejectUnauthorized: false }
});

async function checkMMUser() {
  try {
    const result = await pool.query(`
      SELECT staff_id, name, app_username, app_pw, active_status, stafftype
      FROM mbstaff
      WHERE app_username = 'MM'
    `);

    if (result.rows.length === 0) {
      console.log('User "MM" not found');
      console.log('\nChecking for users with similar usernames:');
      const similar = await pool.query(`
        SELECT staff_id, name, app_username, active_status
        FROM mbstaff
        WHERE app_username ILIKE '%MM%'
        LIMIT 10
      `);
      console.log(JSON.stringify(similar.rows, null, 2));
    } else {
      console.log('User "MM" found:');
      console.log(JSON.stringify(result.rows[0], null, 2));
      console.log('\nYou can login with:');
      console.log(`Username: ${result.rows[0].app_username}`);
      console.log(`Password: ${result.rows[0].app_pw}`);
    }
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

checkMMUser();
