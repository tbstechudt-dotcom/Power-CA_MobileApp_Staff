/**
 * Fix workdiary doc_ref column size
 *
 * Problem: doc_ref is VARCHAR(15) but Supabase Storage URLs are ~120+ characters
 * This causes URLs to be truncated when saved, making attachments unretrievable.
 *
 * Solution: Change doc_ref from VARCHAR(15) to TEXT
 *
 * Run: node scripts/fix-workdiary-doc-ref-column.js
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function fixDocRefColumn() {
  console.log('\n==============================================');
  console.log('  Fix workdiary doc_ref column size');
  console.log('==============================================\n');

  try {
    // Check current column info
    console.log('[INFO] Checking current doc_ref column...\n');

    const { data: columnInfo, error: infoError } = await supabase
      .from('workdiary')
      .select('wd_id, doc_ref')
      .not('doc_ref', 'is', null)
      .limit(5);

    if (infoError) {
      console.error('[ERROR] Failed to query workdiary:', infoError.message);
    } else {
      console.log('Sample doc_ref values:');
      if (columnInfo && columnInfo.length > 0) {
        columnInfo.forEach(row => {
          const docRef = row.doc_ref || '(null)';
          console.log(`  wd_id: ${row.wd_id}, doc_ref: ${docRef} (length: ${docRef.length})`);
        });
      } else {
        console.log('  (No records with doc_ref found)');
      }
    }

    console.log('\n[IMPORTANT] The doc_ref column is VARCHAR(15) which is TOO SMALL!');
    console.log('[IMPORTANT] Supabase Storage URLs are ~120+ characters.\n');

    console.log('[ACTION REQUIRED] Run this SQL in Supabase SQL Editor:\n');
    console.log('==================================================');
    console.log(`
-- Fix doc_ref column size (VARCHAR(15) is too small for URLs)
-- Supabase Storage URLs are typically 120+ characters

-- Step 1: Check current column type
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'workdiary' AND column_name = 'doc_ref';

-- Step 2: Alter column to TEXT (unlimited length for URLs)
ALTER TABLE workdiary
ALTER COLUMN doc_ref TYPE TEXT;

-- Step 3: Verify the change
SELECT column_name, data_type, character_maximum_length
FROM information_schema.columns
WHERE table_name = 'workdiary' AND column_name = 'doc_ref';
`);
    console.log('==================================================');
    console.log('\n[INFO] Go to Supabase Dashboard -> SQL Editor and run the above SQL');
    console.log('[INFO] URL: https://supabase.com/dashboard/project/jacqfogzgzvbjeizljqf/sql/new\n');

  } catch (error) {
    console.error('[ERROR] Unexpected error:', error.message);
  }

  console.log('==============================================\n');
}

fixDocRefColumn();
