const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function testLimit() {
  console.log('Testing Supabase .limit() method...\n');

  // Test 1: Default limit (should be 1000)
  console.log('Test 1: Default limit (no .limit() call)');
  const { data: defaultData, error: defaultError } = await supabase
    .from('jobshead')
    .select('job_id, work_desc, client_id')
    .order('work_desc');

  if (defaultError) {
    console.log('Error:', defaultError.message);
  } else {
    console.log(`  - Rows returned: ${defaultData.length}`);
    const client17Count = defaultData.filter(j => j.client_id === 17).length;
    console.log(`  - Jobs for client_id 17: ${client17Count}`);
  }

  // Test 2: With .limit(50000)
  console.log('\nTest 2: With .limit(50000)');
  const { data: limitData, error: limitError } = await supabase
    .from('jobshead')
    .select('job_id, work_desc, client_id')
    .order('work_desc')
    .limit(50000);

  if (limitError) {
    console.log('Error:', limitError.message);
  } else {
    console.log(`  - Rows returned: ${limitData.length}`);
    const client17Count = limitData.filter(j => j.client_id === 17).length;
    console.log(`  - Jobs for client_id 17: ${client17Count}`);

    if (client17Count > 0) {
      console.log('\n  - First 5 jobs for client 17:');
      limitData.filter(j => j.client_id === 17).slice(0, 5).forEach((job, i) => {
        console.log(`    ${i + 1}. job_id: ${job.job_id}, work_desc: "${job.work_desc}"`);
      });
    }
  }

  console.log('\nConclusion:');
  if (defaultData && limitData && defaultData.length === limitData.length && defaultData.length === 1000) {
    console.log('❌ .limit() method appears to NOT be working!');
    console.log('   Both queries returned exactly 1000 rows.');
  } else if (limitData && limitData.length > 1000) {
    console.log('✅ .limit() method IS working!');
    console.log(`   Fetched ${limitData.length} rows (more than default 1000).`);
  } else {
    console.log('⚠️  Inconclusive - need more data to determine.');
  }
}

testLimit().catch(console.error);
