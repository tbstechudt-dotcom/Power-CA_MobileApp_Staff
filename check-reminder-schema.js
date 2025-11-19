const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.SUPABASE_DB_HOST,
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: process.env.SUPABASE_DB_PASSWORD,
  ssl: { rejectUnauthorized: false }
});

async function checkReminderSchema() {
  try {
    console.log('[INFO] Checking reminder and remdetail table schemas...\n');

    // Get reminder column info
    const reminderColumns = await pool.query(`
      SELECT column_name, data_type, character_maximum_length,
             is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'reminder'
      ORDER BY ordinal_position
    `);

    console.log('reminder table columns:');
    reminderColumns.rows.forEach(col => {
      const length = col.character_maximum_length ? `(${col.character_maximum_length})` : '';
      const nullable = col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL';
      const defaultVal = col.column_default ? ` DEFAULT ${col.column_default}` : '';
      console.log(`  - ${col.column_name}: ${col.data_type}${length} ${nullable}${defaultVal}`);
    });

    // Get remdetail column info
    const remdetailColumns = await pool.query(`
      SELECT column_name, data_type, character_maximum_length,
             is_nullable, column_default
      FROM information_schema.columns
      WHERE table_name = 'remdetail'
      ORDER BY ordinal_position
    `);

    console.log('\n\nremdetail table columns:');
    remdetailColumns.rows.forEach(col => {
      const length = col.character_maximum_length ? `(${col.character_maximum_length})` : '';
      const nullable = col.is_nullable === 'YES' ? 'NULL' : 'NOT NULL';
      const defaultVal = col.column_default ? ` DEFAULT ${col.column_default}` : '';
      console.log(`  - ${col.column_name}: ${col.data_type}${length} ${nullable}${defaultVal}`);
    });

    // Check sample reminder data
    const sampleReminders = await pool.query(`
      SELECT
        r.rem_id,
        r.staff_id,
        r.client_id,
        r.remtype,
        r.remdate,
        r.remduedate,
        r.remtime,
        r.remtitle,
        r.remnotes,
        r.remstatus,
        c.clientname
      FROM reminder r
      LEFT JOIN climaster c ON r.client_id = c.client_id
      ORDER BY r.rem_id DESC
      LIMIT 5
    `);

    console.log(`\n\nSample reminder records (${sampleReminders.rows.length} records):`);
    sampleReminders.rows.forEach((row, idx) => {
      console.log(`\n${idx + 1}. Reminder:`);
      Object.keys(row).forEach(key => {
        console.log(`   ${key}: ${row[key]}`);
      });
    });

    // Check sample remdetail data
    const sampleRemdetail = await pool.query(`
      SELECT
        remdetid,
        rem_id,
        staff_id,
        remresponse,
        remresstatus
      FROM remdetail
      ORDER BY remdetid DESC
      LIMIT 5
    `);

    console.log(`\n\nSample remdetail records (${sampleRemdetail.rows.length} records):`);
    sampleRemdetail.rows.forEach((row, idx) => {
      console.log(`\n${idx + 1}. RemDetail:`);
      Object.keys(row).forEach(key => {
        console.log(`   ${key}: ${row[key]}`);
      });
    });

    // Check reminder types
    const remTypes = await pool.query(`
      SELECT DISTINCT remtype, COUNT(*) as count
      FROM reminder
      WHERE remtype IS NOT NULL
      GROUP BY remtype
      ORDER BY count DESC
    `);

    console.log('\n\nReminder types in database:');
    remTypes.rows.forEach(row => {
      console.log(`  - ${row.remtype}: ${row.count} reminders`);
    });

    // Check reminder status values
    const remStatuses = await pool.query(`
      SELECT DISTINCT remstatus, COUNT(*) as count
      FROM reminder
      WHERE remstatus IS NOT NULL
      GROUP BY remstatus
      ORDER BY count DESC
    `);

    console.log('\n\nReminder statuses in database:');
    remStatuses.rows.forEach(row => {
      console.log(`  - ${row.remstatus}: ${row.count} reminders`);
    });

    // Check record counts by staff
    const staffCounts = await pool.query(`
      SELECT staff_id, COUNT(*) as count
      FROM reminder
      GROUP BY staff_id
      ORDER BY count DESC
      LIMIT 10
    `);

    console.log('\n\nTop 10 staff by reminder count:');
    staffCounts.rows.forEach(row => {
      console.log(`  - Staff ${row.staff_id}: ${row.count} reminders`);
    });

    await pool.end();
  } catch (err) {
    console.error('[ERROR]', err.message);
    await pool.end();
  }
}

checkReminderSchema();
