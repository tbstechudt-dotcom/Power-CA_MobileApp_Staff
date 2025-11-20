/**
 * Check workdiary table schema
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function checkSchema() {
  try {
    // Get a few records to see all columns
    const { data, error } = await supabase
      .from('workdiary')
      .select('*')
      .limit(5);

    if (error) throw error;

    console.log('\n=== WORKDIARY TABLE SCHEMA ===\n');
    console.log('Total records found:', data.length);

    if (data.length > 0) {
      console.log('\nColumn names:');
      Object.keys(data[0]).forEach(col => console.log(`  - ${col}`));

      console.log('\nSample record:');
      console.log(JSON.stringify(data[0], null, 2));
    }

  } catch (error) {
    console.error('[ERROR]', error.message);
  }
}

checkSchema();
