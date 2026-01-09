/**
 * Script to change workdiary timefrom/timeto columns from timestamp to time type
 * This allows storing only time values (HH:mm:ss) instead of full datetime
 *
 * Run: node scripts/change-workdiary-time-columns.js
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function changeColumnTypes() {
  console.log('\n==============================================');
  console.log('  Change workdiary time columns to TIME type');
  console.log('==============================================\n');

  try {
    // Note: Supabase JS client cannot run ALTER TABLE directly
    // We need to use the SQL Editor in Supabase Dashboard or use pg driver

    // For now, let's verify the current data and provide SQL to run manually
    console.log('[INFO] Checking current workdiary data...\n');

    const { data, error } = await supabase
      .from('workdiary')
      .select('wd_id, timefrom, timeto')
      .limit(5);

    if (error) {
      console.error('[ERROR] Failed to query workdiary:', error.message);
      return;
    }

    console.log('Sample current data:');
    if (data && data.length > 0) {
      data.forEach(row => {
        console.log(`  wd_id: ${row.wd_id}, timefrom: ${row.timefrom}, timeto: ${row.timeto}`);
      });
    } else {
      console.log('  (No data in workdiary table)');
    }

    console.log('\n[IMPORTANT] Run this SQL in Supabase SQL Editor to change column types:');
    console.log('');
    console.log('==================================================');
    console.log(`
-- Change timefrom and timeto columns from timestamp to time type
-- This allows storing time-only values (HH:mm:ss)

ALTER TABLE workdiary
ALTER COLUMN timefrom TYPE time
USING timefrom::time;

ALTER TABLE workdiary
ALTER COLUMN timeto TYPE time
USING timeto::time;
`);
    console.log('==================================================');
    console.log('\n[INFO] Go to Supabase Dashboard -> SQL Editor and run the above SQL');
    console.log('[INFO] URL: https://supabase.com/dashboard/project/jacqfogzgzvbjeizljqf/sql/new\n');

  } catch (error) {
    console.error('[ERROR] Unexpected error:', error.message);
  }

  console.log('==============================================\n');
}

changeColumnTypes();
