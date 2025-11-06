/**
 * Verify all tables synced correctly
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

async function verifySync() {
  try {
    console.log('='.repeat(70));
    console.log('SYNC VERIFICATION - LOCAL vs SUPABASE');
    console.log('='.repeat(70));

    const tables = [
      'orgmaster',
      'locmaster',
      'conmaster',
      'climaster',
      'mbstaff',
      'jobshead',
      'jobtasks',
      'taskchecklist',
      'workdiary',
      'reminder',
      'remdetail',
      'learequest'
    ];

    console.log('\n📊 TABLE COMPARISON:\n');
    console.log('  Table                 Local      Supabase   Status');
    console.log('  ' + '-'.repeat(65));

    let totalLocal = 0;
    let totalSupabase = 0;

    for (const table of tables) {
      try {
        const localResult = await localPool.query(`SELECT COUNT(*) as count FROM ${table}`);
        const localCount = parseInt(localResult.rows[0].count);
        totalLocal += localCount;

        const supabaseResult = await supabasePool.query(`SELECT COUNT(*) as count FROM ${table}`);
        const supabaseCount = parseInt(supabaseResult.rows[0].count);
        totalSupabase += supabaseCount;

        const status = supabaseCount === localCount ? '✅ Match' :
                      supabaseCount === 0 && localCount === 0 ? '⚪ Empty' :
                      supabaseCount < localCount ? '⚠️ Filtered' : '❓ Check';

        const padding1 = ' '.repeat(22 - table.length);
        const padding2 = ' '.repeat(10 - localCount.toString().length);
        const padding3 = ' '.repeat(10 - supabaseCount.toString().length);

        console.log(`  ${table}${padding1}${localCount}${padding2}${supabaseCount}${padding3}${status}`);
      } catch (error) {
        console.log(`  ${table}${' '.repeat(22 - table.length)}ERROR: ${error.message}`);
      }
    }

    console.log('  ' + '-'.repeat(65));
    console.log(`  TOTAL${' '.repeat(17)}${totalLocal}${' '.repeat(10 - totalLocal.toString().length)}${totalSupabase}`);

    console.log('\n' + '='.repeat(70));
    console.log('✅ SYNC VERIFICATION COMPLETE!');
    console.log('='.repeat(70));

    await localPool.end();
    await supabasePool.end();

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

verifySync();
