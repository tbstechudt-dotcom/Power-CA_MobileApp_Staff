/**
 * Check Supabase Storage bucket configuration
 *
 * Run: node scripts/check-storage-bucket.js
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkStorageBucket() {
  console.log('\n==============================================');
  console.log('  Check Supabase Storage Bucket');
  console.log('==============================================\n');

  try {
    // Step 1: List all buckets
    console.log('[STEP 1] Listing all storage buckets...\n');

    const { data: buckets, error: bucketsError } = await supabase
      .storage
      .listBuckets();

    if (bucketsError) {
      console.error('[ERROR] Cannot list buckets:', bucketsError.message);
    } else if (!buckets || buckets.length === 0) {
      console.log('[WARN] No storage buckets found!');
      console.log('[INFO] You need to create a bucket named "attachments"');
    } else {
      console.log('Available buckets:');
      buckets.forEach(bucket => {
        console.log(`  - ${bucket.name} (public: ${bucket.public})`);
      });

      // Check if 'attachments' bucket exists
      const attachmentsBucket = buckets.find(b => b.name === 'attachments');
      if (attachmentsBucket) {
        console.log('\n[OK] "attachments" bucket exists!');
        console.log(`  Public: ${attachmentsBucket.public}`);
      } else {
        console.log('\n[ERROR] "attachments" bucket NOT FOUND!');
      }
    }

    // Step 2: Try to list files in attachments bucket
    console.log('\n[STEP 2] Checking "attachments" bucket contents...\n');

    const { data: files, error: filesError } = await supabase
      .storage
      .from('attachments')
      .list('workdiary', { limit: 5 });

    if (filesError) {
      console.error('[ERROR] Cannot access "attachments" bucket:', filesError.message);
      console.log('\n[INFO] The bucket might not exist or you need permissions.');
    } else {
      console.log(`Files in attachments/workdiary: ${files?.length || 0}`);
      if (files && files.length > 0) {
        files.forEach(file => {
          console.log(`  - ${file.name} (${file.metadata?.size || 'unknown'} bytes)`);
        });
      }
    }

    // Step 3: Test upload
    console.log('\n[STEP 3] Testing file upload...\n');

    const testContent = Buffer.from('test file content');
    const testPath = `workdiary/test_${Date.now()}.txt`;

    const { data: uploadData, error: uploadError } = await supabase
      .storage
      .from('attachments')
      .upload(testPath, testContent, {
        contentType: 'text/plain',
        upsert: true
      });

    if (uploadError) {
      console.error('[ERROR] Upload failed:', uploadError.message);
      console.log('\n[INFO] Storage bucket might not allow uploads.');
    } else {
      console.log('[OK] Test upload successful!');
      console.log('  Path:', uploadData.path);

      // Get public URL
      const { data: urlData } = supabase
        .storage
        .from('attachments')
        .getPublicUrl(testPath);

      console.log('  Public URL:', urlData.publicUrl);

      // Clean up test file
      console.log('\n[STEP 4] Cleaning up test file...');
      await supabase.storage.from('attachments').remove([testPath]);
      console.log('[OK] Test file removed');
    }

  } catch (error) {
    console.error('[ERROR] Unexpected error:', error.message);
  }

  console.log('\n==============================================');
  console.log('  Create Storage Bucket (if needed)');
  console.log('==============================================\n');
  console.log(`
If the "attachments" bucket doesn't exist, create it in Supabase Dashboard:

1. Go to: https://supabase.com/dashboard/project/jacqfogzgzvbjeizljqf/storage/buckets
2. Click "New bucket"
3. Name: attachments
4. Check "Public bucket" (allows public access to files)
5. Click "Create bucket"

Then set up bucket policies:
1. Click on "attachments" bucket
2. Go to "Policies" tab
3. Add these policies:

-- Allow public read access
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'attachments');

-- Allow authenticated uploads
CREATE POLICY "Allow uploads" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'attachments');

-- Allow updates
CREATE POLICY "Allow updates" ON storage.objects FOR UPDATE USING (bucket_id = 'attachments');
`);
}

checkStorageBucket();
