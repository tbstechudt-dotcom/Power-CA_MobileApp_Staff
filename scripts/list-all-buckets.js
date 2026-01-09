/**
 * List ALL storage buckets and try different bucket names
 *
 * Run: node scripts/list-all-buckets.js
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function listAllBuckets() {
  console.log('\n==============================================');
  console.log('  List ALL Storage Buckets');
  console.log('==============================================\n');

  // Try to list buckets
  console.log('[TEST 1] Listing buckets with anon key...\n');

  const { data: buckets, error } = await supabase.storage.listBuckets();

  if (error) {
    console.log('[ERROR]', error.message);
    console.log('\nThis error usually means:');
    console.log('  1. Storage is not enabled for this project');
    console.log('  2. Bucket listing is restricted by RLS');
  } else {
    console.log('Buckets found:', buckets?.length || 0);
    if (buckets && buckets.length > 0) {
      buckets.forEach(b => {
        console.log(`  - "${b.name}" (id: ${b.id}, public: ${b.public})`);
      });
    }
  }

  // Try common bucket names
  console.log('\n[TEST 2] Testing common bucket names...\n');

  const commonNames = ['attachments', 'Attachments', 'files', 'uploads', 'documents', 'workdiary', 'public'];

  for (const name of commonNames) {
    try {
      const { data, error } = await supabase.storage.from(name).list('', { limit: 1 });
      if (!error) {
        console.log(`  [OK] "${name}" bucket EXISTS!`);
      } else {
        console.log(`  [X] "${name}" - ${error.message}`);
      }
    } catch (e) {
      console.log(`  [X] "${name}" - ${e.message}`);
    }
  }

  // Direct API test
  console.log('\n[TEST 3] Direct storage API test...\n');

  try {
    const response = await fetch(`${SUPABASE_URL}/storage/v1/bucket`, {
      headers: {
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'apikey': SUPABASE_ANON_KEY
      }
    });
    const data = await response.json();
    console.log('Direct API response:', JSON.stringify(data, null, 2));
  } catch (e) {
    console.log('Direct API error:', e.message);
  }

  console.log('\n==============================================');
  console.log('  IMPORTANT: Check Supabase Dashboard');
  console.log('==============================================\n');
  console.log('Go to: https://supabase.com/dashboard/project/jacqfogzgzvbjeizljqf/storage/buckets');
  console.log('\nMake sure:');
  console.log('  1. The bucket is named exactly "attachments" (lowercase, no spaces)');
  console.log('  2. The bucket is marked as "Public"');
  console.log('  3. Storage policies allow uploads\n');
}

listAllBuckets();
