/**
 * Check User Active Status
 *
 * Checks if a user exists and their active status in mbstaff table
 */

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
});

async function checkUserStatus(username) {
  try {
    console.log(`\nChecking status for user: ${username}\n`);

    const result = await pool.query(
      `SELECT
        staff_id,
        app_username,
        sname,
        isactive,
        org_id,
        loc_id
      FROM mbstaff
      WHERE app_username = $1`,
      [username]
    );

    if (result.rows.length > 0) {
      const user = result.rows[0];
      console.log('[OK] User found:');
      console.log('---------------------');
      console.log(`Staff ID: ${user.staff_id}`);
      console.log(`Username: ${user.app_username}`);
      console.log(`Name: ${user.sname}`);
      console.log(`Active: ${user.isactive}`);
      console.log(`Org ID: ${user.org_id}`);
      console.log(`Loc ID: ${user.loc_id}`);
      console.log('---------------------\n');

      if (user.isactive !== true) {
        console.log('[ERROR] User account is INACTIVE!');
        console.log('To activate this user, run:');
        console.log(`UPDATE mbstaff SET isactive = true WHERE app_username = '${username}';\n`);
      } else {
        console.log('[OK] User account is ACTIVE\n');
      }
    } else {
      console.log(`[ERROR] User '${username}' not found in database\n`);
    }

  } catch (error) {
    console.error('[ERROR] Database query failed:', error.message);
  } finally {
    await pool.end();
  }
}

// Get username from command line or use default
const username = process.argv[2] || 'MM';
checkUserStatus(username);
