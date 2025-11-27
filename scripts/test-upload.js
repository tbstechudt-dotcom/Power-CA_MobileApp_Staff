/**
 * Test upload to attachments bucket
 *
 * Run: node scripts/test-upload.js
 */

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testUpload() {
  console.log('\n==============================================');
  console.log('  Test File Upload to attachments bucket');
  console.log('==============================================\n');

  const testContent = Buffer.from('Hello, this is a test file! ' + new Date().toISOString());
  const testPath = `workdiary/test_${Date.now()}.txt`;

  console.log('[STEP 1] Uploading test file...');
  console.log(`  Path: ${testPath}`);
  console.log(`  Size: ${testContent.length} bytes\n`);

  const { data: uploadData, error: uploadError } = await supabase.storage
    .from('attachments')
    .upload(testPath, testContent, {
      contentType: 'text/plain',
      upsert: true
    });

  if (uploadError) {
    console.log('[ERROR] Upload failed:', uploadError.message);
    console.log('\nPossible issues:');
    console.log('  1. Storage policies block uploads');
    console.log('  2. Bucket is not properly configured');
    console.log('\n[FIX] Run this SQL in Supabase SQL Editor:');
    console.log(`
-- Allow all operations on storage.objects for attachments bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Create permissive policies
CREATE POLICY "Allow public read" ON storage.objects FOR SELECT USING (bucket_id = 'attachments');
CREATE POLICY "Allow all insert" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'attachments');
CREATE POLICY "Allow all update" ON storage.objects FOR UPDATE USING (bucket_id = 'attachments');
CREATE POLICY "Allow all delete" ON storage.objects FOR DELETE USING (bucket_id = 'attachments');
`);
    return;
  }

  console.log('[OK] Upload successful!');
  console.log('  Upload path:', uploadData.path);

  // Get public URL
  const { data: urlData } = supabase.storage.from('attachments').getPublicUrl(testPath);
  console.log('  Public URL:', urlData.publicUrl);

  // Test updating workdiary with this URL
  console.log('\n[STEP 2] Testing database update with URL...\n');

  // Get a sample workdiary record
  const { data: sample } = await supabase
    .from('workdiary')
    .select('wd_id, doc_ref')
    .limit(1)
    .single();

  if (sample) {
    console.log('  Sample record wd_id:', sample.wd_id);
    console.log('  Current doc_ref:', sample.doc_ref || '(NULL)');

    // Update with the URL
    const { error: updateError } = await supabase
      .from('workdiary')
      .update({ doc_ref: urlData.publicUrl })
      .eq('wd_id', sample.wd_id);

    if (updateError) {
      console.log('[ERROR] Database update failed:', updateError.message);
    } else {
      console.log('[OK] Database updated successfully!');

      // Verify
      const { data: verify } = await supabase
        .from('workdiary')
        .select('wd_id, doc_ref')
        .eq('wd_id', sample.wd_id)
        .single();

      console.log('  New doc_ref:', verify?.doc_ref);
    }
  }

  // Clean up test file
  console.log('\n[STEP 3] Cleaning up...');
  await supabase.storage.from('attachments').remove([testPath]);
  console.log('[OK] Test file removed\n');

  console.log('==============================================');
  console.log('  SUCCESS! Storage upload works!');
  console.log('==============================================\n');
}

testUpload();
