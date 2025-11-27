/**
 * Check workdiary RLS policies and test update capability
 *
 * Run: node scripts/check-workdiary-rls.js
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkRLSAndTestUpdate() {
  console.log('\n==============================================');
  console.log('  Check workdiary RLS and Test Updates');
  console.log('==============================================\n');

  try {
    // Step 1: Get a sample workdiary record
    console.log('[STEP 1] Fetching a sample workdiary record...\n');

    const { data: sampleRecord, error: fetchError } = await supabase
      .from('workdiary')
      .select('wd_id, staff_id, doc_ref, source')
      .limit(1)
      .single();

    if (fetchError) {
      console.error('[ERROR] Cannot fetch workdiary:', fetchError.message);
      console.log('\n[INFO] This might indicate RLS is blocking SELECT operations.');
      return;
    }

    console.log('Sample record found:');
    console.log(`  wd_id: ${sampleRecord.wd_id}`);
    console.log(`  staff_id: ${sampleRecord.staff_id}`);
    console.log(`  doc_ref: ${sampleRecord.doc_ref || '(NULL)'}`);
    console.log(`  source: ${sampleRecord.source || '(NULL)'}`);

    // Step 2: Try to update doc_ref
    console.log('\n[STEP 2] Testing UPDATE on doc_ref column...\n');

    const testUrl = 'https://test-url.com/test-file.jpg';
    const { data: updateResult, error: updateError } = await supabase
      .from('workdiary')
      .update({ doc_ref: testUrl })
      .eq('wd_id', sampleRecord.wd_id)
      .select();

    if (updateError) {
      console.error('[ERROR] UPDATE failed:', updateError.message);
      console.error('[ERROR] Code:', updateError.code);
      console.error('[ERROR] Details:', updateError.details);
      console.log('\n[INFO] RLS policy is likely blocking UPDATE operations!');
    } else if (!updateResult || updateResult.length === 0) {
      console.log('[WARN] UPDATE returned no rows - RLS might be blocking!');
      console.log('[INFO] The update query ran but affected 0 rows.');
    } else {
      console.log('[OK] UPDATE successful!');
      console.log('Updated record:', updateResult[0]);

      // Revert the test
      console.log('\n[STEP 3] Reverting test update...');
      await supabase
        .from('workdiary')
        .update({ doc_ref: sampleRecord.doc_ref })
        .eq('wd_id', sampleRecord.wd_id);
      console.log('[OK] Reverted to original value');
    }

    // Step 3: Check column info
    console.log('\n[STEP 4] Checking doc_ref column type...\n');

    const { data: columnCheck, error: columnError } = await supabase
      .from('workdiary')
      .select('doc_ref')
      .limit(1);

    if (!columnError) {
      console.log('[OK] doc_ref column is accessible');
    }

  } catch (error) {
    console.error('[ERROR] Unexpected error:', error.message);
  }

  console.log('\n==============================================');
  console.log('  SQL to Disable RLS (if needed)');
  console.log('==============================================\n');
  console.log(`
-- Option 1: Disable RLS entirely on workdiary (for development)
ALTER TABLE workdiary DISABLE ROW LEVEL SECURITY;

-- Option 2: Create a policy allowing all operations (recommended)
-- First check if RLS is enabled:
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'workdiary';

-- If RLS is enabled, create permissive policies:
CREATE POLICY "Allow all select" ON workdiary FOR SELECT USING (true);
CREATE POLICY "Allow all insert" ON workdiary FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow all update" ON workdiary FOR UPDATE USING (true);
CREATE POLICY "Allow all delete" ON workdiary FOR DELETE USING (true);

-- Or grant full access to anon role:
GRANT ALL ON workdiary TO anon;
GRANT ALL ON workdiary TO authenticated;
`);

  console.log('\n[INFO] Run the above SQL in Supabase SQL Editor:');
  console.log('[INFO] https://supabase.com/dashboard/project/jacqfogzgzvbjeizljqf/sql/new\n');
}

checkRLSAndTestUpdate();
