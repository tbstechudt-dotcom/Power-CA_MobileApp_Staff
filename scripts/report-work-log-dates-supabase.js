/**
 * Report: Work Log Entry Dates (using Supabase JS client)
 * Shows which dates have work diary entries
 */

const { createClient } = require('@supabase/supabase-js');

// Supabase configuration (from Flutter app)
const supabaseUrl = 'https://jacqfogzgzvbjeizljqf.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphY3Fmb2d6Z3p2YmplaXpsanFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NzA3NDIsImV4cCI6MjA3NzE0Njc0Mn0.MncHuyRmIvZCbHKcIkzq_qYwcqM0bXzWE71gTHPCFCo';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function generateWorkLogReport() {
  try {
    console.log('\n=== WORK LOG ENTRY DATES REPORT ===\n');

    // Get total count
    const { count: totalCount, error: countError } = await supabase
      .from('workdiary')
      .select('*', { count: 'exact', head: true });

    if (countError) throw countError;

    console.log(`[INFO] Total work log entries: ${totalCount}\n`);

    // Get all work diary entries with date grouping
    const { data: entries, error: entriesError } = await supabase
      .from('workdiary')
      .select('date, staff_id, minutes, job_id, client_id, tasknotes')
      .order('date', { ascending: false })
      .limit(1000);

    if (entriesError) throw entriesError;

    // Group by date
    const dateMap = new Map();

    entries.forEach(entry => {
      if (!entry.date) return;

      const date = entry.date.split('T')[0]; // Get date part only

      if (!dateMap.has(date)) {
        dateMap.set(date, {
          entryCount: 0,
          staffSet: new Set(),
          totalHours: 0
        });
      }

      const dateData = dateMap.get(date);
      dateData.entryCount++;
      if (entry.staff_id) dateData.staffSet.add(entry.staff_id);
      if (entry.minutes) dateData.totalHours += parseFloat(entry.minutes) / 60;  // Convert minutes to hours
    });

    // Convert to array and sort
    const sortedDates = Array.from(dateMap.entries())
      .map(([date, data]) => ({
        date,
        entryCount: data.entryCount,
        staffCount: data.staffSet.size,
        totalHours: data.totalHours
      }))
      .sort((a, b) => b.date.localeCompare(a.date));

    console.log('=== DATES WITH WORK LOG ENTRIES (Latest 100) ===\n');
    console.log('Date         | Entries | Staff | Total Hours');
    console.log('-------------|---------|-------|-------------');

    sortedDates.slice(0, 100).forEach(row => {
      const date = row.date;
      const entries = String(row.entryCount).padStart(7, ' ');
      const staff = String(row.staffCount).padStart(5, ' ');
      const hours = row.totalHours ? row.totalHours.toFixed(2).padStart(11, ' ') : '          -';
      console.log(`${date} | ${entries} | ${staff} | ${hours}`);
    });

    // Monthly summary
    const monthMap = new Map();

    sortedDates.forEach(row => {
      const month = row.date.substring(0, 7); // YYYY-MM

      if (!monthMap.has(month)) {
        monthMap.set(month, {
          entryCount: 0,
          staffSet: new Set(),
          totalHours: 0
        });
      }

      const monthData = monthMap.get(month);
      monthData.entryCount += row.entryCount;
      monthData.totalHours += row.totalHours;
    });

    // Need to get staff per month from original data
    entries.forEach(entry => {
      if (!entry.date) return;
      const month = entry.date.substring(0, 7);
      if (monthMap.has(month) && entry.staff_id) {
        monthMap.get(month).staffSet.add(entry.staff_id);
      }
    });

    const sortedMonths = Array.from(monthMap.entries())
      .map(([month, data]) => ({
        month,
        entryCount: data.entryCount,
        staffCount: data.staffSet.size,
        totalHours: data.totalHours
      }))
      .sort((a, b) => b.month.localeCompare(a.month));

    console.log('\n\n=== MONTHLY SUMMARY (Last 12 Months) ===\n');
    console.log('Month   | Entries | Staff | Total Hours');
    console.log('--------|---------|-------|-------------');

    sortedMonths.slice(0, 12).forEach(row => {
      const month = row.month;
      const entries = String(row.entryCount).padStart(7, ' ');
      const staff = String(row.staffCount).padStart(5, ' ');
      const hours = row.totalHours ? row.totalHours.toFixed(2).padStart(11, ' ') : '          -';
      console.log(`${month} | ${entries} | ${staff} | ${hours}`);
    });

    // Get staff summary
    const { data: staffData, error: staffError } = await supabase
      .from('workdiary')
      .select('staff_id, date, minutes');

    if (staffError) throw staffError;

    const staffMap = new Map();

    staffData.forEach(entry => {
      if (!entry.staff_id) return;

      if (!staffMap.has(entry.staff_id)) {
        staffMap.set(entry.staff_id, {
          entryCount: 0,
          daysSet: new Set(),
          totalHours: 0
        });
      }

      const staffInfo = staffMap.get(entry.staff_id);
      staffInfo.entryCount++;
      if (entry.date) staffInfo.daysSet.add(entry.date.split('T')[0]);
      if (entry.minutes) staffInfo.totalHours += parseFloat(entry.minutes) / 60;  // Convert minutes to hours
    });

    // Get staff names
    const staffIds = Array.from(staffMap.keys());
    const { data: staffNames, error: staffNamesError } = await supabase
      .from('mbstaff')
      .select('staff_id, name')
      .in('staff_id', staffIds);

    if (staffNamesError) throw staffNamesError;

    const staffNameMap = new Map(staffNames.map(s => [s.staff_id, s.name]));

    const sortedStaff = Array.from(staffMap.entries())
      .map(([staffId, data]) => ({
        staffId,
        name: staffNameMap.get(staffId) || 'Unknown',
        entryCount: data.entryCount,
        daysLogged: data.daysSet.size,
        totalHours: data.totalHours
      }))
      .sort((a, b) => b.entryCount - a.entryCount);

    console.log('\n\n=== TOP 20 STAFF BY WORK LOG ENTRIES ===\n');
    console.log('Staff Name                    | Entries | Days | Total Hours');
    console.log('------------------------------|---------|------|-------------');

    sortedStaff.slice(0, 20).forEach(row => {
      const name = row.name.substring(0, 29).padEnd(29, ' ');
      const entries = String(row.entryCount).padStart(7, ' ');
      const days = String(row.daysLogged).padStart(4, ' ');
      const hours = row.totalHours ? row.totalHours.toFixed(2).padStart(11, ' ') : '          -';
      console.log(`${name} | ${entries} | ${days} | ${hours}`);
    });

    console.log('\n[SUCCESS] Report generated successfully!\n');

  } catch (error) {
    console.error('[ERROR] Failed to generate report:', error.message);
    throw error;
  }
}

// Run report
generateWorkLogReport()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('[FATAL]', error);
    process.exit(1);
  });
