require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST || 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function getStaff() {
  try {
    const result = await pool.query('SELECT * FROM mbstaff ORDER BY staff_id LIMIT 5');

    if (result.rows.length > 0) {
      console.log('Found ' + result.rows.length + ' staff members:\n');
      result.rows.forEach((staff, index) => {
        console.log('Staff #' + (index + 1) + ':');
        console.log('  staff_id: ' + staff.staff_id);
        console.log('  name: ' + staff.name);
        console.log('  username: ' + staff.username);
        console.log('  email: ' + staff.email);
        console.log('  phone_number: ' + staff.phone_number);
        console.log('  org_id: ' + staff.org_id);
        console.log('  loc_id: ' + staff.loc_id);
        console.log('  con_id: ' + staff.con_id);
        console.log('  date_of_birth: ' + staff.date_of_birth);
        console.log('  staff_type: ' + staff.staff_type);
        console.log('  is_active: ' + staff.is_active);
        console.log('');
      });
    } else {
      console.log('No staff members found in database');
    }
  } catch (err) {
    console.log('Error:', err.message);
  } finally {
    await pool.end();
  }
}

getStaff();
