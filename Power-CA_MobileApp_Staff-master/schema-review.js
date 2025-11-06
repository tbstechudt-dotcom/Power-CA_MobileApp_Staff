const { Pool } = require('pg');

const pool = new Pool({
  host: 'db.jacqfogzgzvbjeizljqf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Powerca@2025',
  ssl: { rejectUnauthorized: false }
});

// Tables used in the app and columns we expect
const appTables = {
  'mbstaff': ['staff_id', 'app_username', 'app_pw', 'name', 'org_id', 'loc_id'],
  'jobshead': ['job_id', 'job_name', 'work_desc', 'job_status', 'staff_id', 'org_id', 'client_id', 'jstartdate', 'jenddate', 'jobdate', 'targetdate'],
  'jobtasks': ['jt_id', 'job_id', 'staff_id', 'task_status', 'jt_status'],
  'workdiary': ['wd_id', 'staff_id', 'job_id', 'date', 'wd_date', 'minutes', 'wd_hours', 'tasknotes', 'wd_notes'],
  'climaster': ['client_id', 'client_name'],
  'reminder': ['rem_id', 'staff_id', 'remdate', 'rem_date', 'remstatus', 'rem_status'],
  'learequest': ['learequest_id', 'lr_id', 'staff_id', 'approval_status', 'lr_status', 'fromdate', 'todate', 'fhvalue', 'shvalue', 'leavetype']
};

async function reviewSchema() {
  try {
    console.log('========================================');
    console.log('DATABASE SCHEMA REVIEW');
    console.log('========================================\n');

    for (const [tableName, expectedColumns] of Object.entries(appTables)) {
      console.log(`\n[TABLE] ${tableName}`);
      console.log('----------------------------------------');

      // Get actual columns from database
      const result = await pool.query(`
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = $1
        ORDER BY ordinal_position
      `, [tableName]);

      const actualColumns = result.rows.map(r => r.column_name);

      // Check each expected column
      console.log('\nExpected Columns:');
      expectedColumns.forEach(col => {
        const exists = actualColumns.includes(col);
        const status = exists ? '[OK]' : '[X] NOT FOUND';
        console.log(`  ${status} ${col}`);
      });

      // Show actual columns for reference
      console.log('\nActual Columns in Database:');
      result.rows.forEach(row => {
        console.log(`  - ${row.column_name} (${row.data_type})`);
      });

      // Identify mismatches
      const notFound = expectedColumns.filter(col => !actualColumns.includes(col));
      if (notFound.length > 0) {
        console.log('\n[WARN] Missing columns:');
        notFound.forEach(col => {
          console.log(`  - ${col}`);

          // Suggest alternatives
          const similar = actualColumns.filter(ac =>
            ac.includes(col.toLowerCase()) || col.toLowerCase().includes(ac)
          );
          if (similar.length > 0) {
            console.log(`    Possible alternatives: ${similar.join(', ')}`);
          }
        });
      }
    }

    console.log('\n========================================');
    console.log('REVIEW COMPLETE');
    console.log('========================================\n');

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await pool.end();
  }
}

reviewSchema();
