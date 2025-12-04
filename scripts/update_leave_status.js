const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

const supabase = createClient(supabaseUrl, supabaseKey);

async function updatePendingToApproved() {
  try {
    // First, get all pending leaves
    const { data: pendingLeaves, error: fetchError } = await supabase
      .from('learequest')
      .select('*')
      .eq('approval_status', 'P');

    if (fetchError) {
      console.log('Error fetching pending leaves:', fetchError);
      return;
    }

    console.log('Pending leaves found:', pendingLeaves?.length || 0);

    if (pendingLeaves && pendingLeaves.length > 0) {
      console.log('\nPending leaves:');
      for (let i = 0; i < pendingLeaves.length; i++) {
        const leave = pendingLeaves[i];
        console.log((i + 1) + '. ID: ' + leave.learequest_id + ', Staff: ' + leave.staff_id + ', From: ' + leave.fromdate + ', To: ' + leave.todate + ', Type: ' + leave.leavetype);
      }

      // Update all pending to approved
      const { data, error } = await supabase
        .from('learequest')
        .update({ approval_status: 'A' })
        .eq('approval_status', 'P')
        .select();

      if (error) {
        console.log('\nError updating leaves:', error);
      } else {
        console.log('\n[OK] Successfully updated ' + (data?.length || 0) + ' leaves to Approved status');
      }
    } else {
      console.log('No pending leaves to update');
    }
  } catch (err) {
    console.log('Error:', err);
  }
}

updatePendingToApproved();
