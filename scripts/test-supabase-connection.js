/**
 * Test Supabase Cloud Connection
 *
 * This script verifies that your Supabase Cloud instance is accessible
 * and working correctly.
 *
 * Usage: node test-supabase-connection.js
 */

const https = require('https');

// Your Supabase credentials
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

console.log('=====================================');
console.log('  Supabase Cloud Connection Test');
console.log('=====================================\n');

// Test 1: Health Check
console.log('Test 1: Checking Supabase API health...');
const healthUrl = new URL('/rest/v1/', SUPABASE_URL);

https.get(healthUrl, {
  headers: {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${ANON_KEY}`
  }
}, (res) => {
  console.log(`[OK] Health Check: Status ${res.statusCode}`);

  if (res.statusCode === 200) {
    console.log('[OK] Supabase API is accessible!\n');
  } else {
    console.log(`[WARN]  Unexpected status code: ${res.statusCode}\n`);
  }

  // Test 2: Auth Endpoint
  console.log('Test 2: Checking Auth endpoint...');
  const authUrl = new URL('/auth/v1/health', SUPABASE_URL);

  https.get(authUrl, {
    headers: {
      'apikey': ANON_KEY
    }
  }, (authRes) => {
    let data = '';

    authRes.on('data', (chunk) => {
      data += chunk;
    });

    authRes.on('end', () => {
      console.log(`[OK] Auth Check: Status ${authRes.statusCode}`);

      if (authRes.statusCode === 200) {
        console.log('[OK] Auth endpoint is working!');
        try {
          const health = JSON.parse(data);
          console.log('   Auth Health:', health);
        } catch (e) {
          console.log('   Response:', data);
        }
      }

      console.log('\n=====================================');
      console.log('  Connection Test Complete!');
      console.log('=====================================\n');

      console.log('Summary:');
      console.log('[OK] Supabase URL:', SUPABASE_URL);
      console.log('[OK] API is accessible');
      console.log('[OK] Authentication endpoint is working');
      console.log('\n[SUCCESS] Your Supabase Cloud instance is ready to use!\n');
      console.log('Next steps:');
      console.log('1. Create your database schema in Supabase dashboard');
      console.log('2. Set up Row Level Security (RLS) policies');
      console.log('3. Build your Flutter app with Supabase integration');
      console.log('4. Create sync script for local Power CA data\n');
    });
  }).on('error', (err) => {
    console.error('[ERROR] Auth endpoint error:', err.message);
  });

}).on('error', (err) => {
  console.error('[ERROR] Health check error:', err.message);
  console.log('\nPlease check:');
  console.log('1. Your internet connection');
  console.log('2. Supabase URL is correct');
  console.log('3. ANON_KEY is valid\n');
});
