/**
 * Activate Inactive Users Script
 *
 * This script:
 * 1. Finds all inactive users in mbstaff table
 * 2. Displays them for review
 * 3. Activates them (sets isactive = true)
 * 4. Confirms activation
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration (from supabase_config.dart)
const SUPABASE_URL = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function activateInactiveUsers() {
  console.log('\n==============================================');
  console.log('  Activate Inactive Users Script');
  console.log('==============================================\n');

  try {
    // Step 1: Find all inactive users
    console.log('[STEP 1] Querying inactive users...\n');

    const { data: inactiveUsers, error: queryError } = await supabase
      .from('mbstaff')
      .select('staff_id, app_username, name, email, active_status, org_id, loc_id')
      .or('active_status.is.null,active_status.neq.1');

    if (queryError) {
      console.error('[ERROR] Failed to query users:', queryError.message);
      return;
    }

    if (!inactiveUsers || inactiveUsers.length === 0) {
      console.log('[OK] No inactive users found! All users are already active.\n');
      return;
    }

    // Step 2: Display inactive users
    console.log(`[INFO] Found ${inactiveUsers.length} inactive user(s):\n`);
    console.log('┌────────────┬──────────────┬─────────────────────────┬────────────┐');
    console.log('│ Staff ID   │ Username     │ Name                    │ Is Active  │');
    console.log('├────────────┼──────────────┼─────────────────────────┼────────────┤');

    inactiveUsers.forEach(user => {
      const staffId = String(user.staff_id || 'N/A').padEnd(10);
      const username = String(user.app_username || 'N/A').padEnd(12);
      const name = String(user.name || 'N/A').substring(0, 23).padEnd(23);
      const activeStatus = user.active_status === 1 ? 'Active' : (user.active_status === 2 ? 'Inactive' : 'NULL');
      const isActive = String(activeStatus).padEnd(10);
      console.log(`│ ${staffId} │ ${username} │ ${name} │ ${isActive} │`);
    });

    console.log('└────────────┴──────────────┴─────────────────────────┴────────────┘\n');

    // Step 3: Activate all inactive users
    console.log('[STEP 2] Activating all inactive users...\n');

    const userIds = inactiveUsers.map(user => user.staff_id);

    const { data: updateData, error: updateError } = await supabase
      .from('mbstaff')
      .update({ active_status: 1 })
      .in('staff_id', userIds)
      .select();

    if (updateError) {
      console.error('[ERROR] Failed to activate users:', updateError.message);
      return;
    }

    console.log(`[OK] Successfully activated ${updateData.length} user(s)!\n`);

    // Step 4: Verify activation
    console.log('[STEP 3] Verifying activation...\n');

    const { data: verifyData, error: verifyError } = await supabase
      .from('mbstaff')
      .select('staff_id, app_username, name, active_status')
      .in('staff_id', userIds);

    if (verifyError) {
      console.error('[ERROR] Failed to verify:', verifyError.message);
      return;
    }

    console.log('┌────────────┬──────────────┬─────────────────────────┬────────────┐');
    console.log('│ Staff ID   │ Username     │ Name                    │ Is Active  │');
    console.log('├────────────┼──────────────┼─────────────────────────┼────────────┤');

    verifyData.forEach(user => {
      const staffId = String(user.staff_id || 'N/A').padEnd(10);
      const username = String(user.app_username || 'N/A').padEnd(12);
      const name = String(user.name || 'N/A').substring(0, 23).padEnd(23);
      const isActive = user.active_status === 1 ? '[OK] TRUE'.padEnd(10) : '[X] FALSE'.padEnd(10);
      console.log(`│ ${staffId} │ ${username} │ ${name} │ ${isActive} │`);
    });

    console.log('└────────────┴──────────────┴─────────────────────────┴────────────┘\n');

    // Summary
    const allActive = verifyData.every(user => user.active_status === 1);
    if (allActive) {
      console.log('[SUCCESS] All users are now active! You can now log in.\n');
    } else {
      console.log('[WARN] Some users may still be inactive. Please check manually.\n');
    }

  } catch (error) {
    console.error('[ERROR] Unexpected error:', error.message);
  }

  console.log('==============================================\n');
}

// Run the script
activateInactiveUsers();
