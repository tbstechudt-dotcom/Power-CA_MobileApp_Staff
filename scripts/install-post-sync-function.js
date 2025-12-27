#!/usr/bin/env node
/**
 * Install sync_mobile_to_parent() Function
 *
 * Creates or replaces the function in the desktop database
 */

const { Pool } = require('pg');
const config = require('../sync/production/config');

const FUNCTION_SQL = `
/**
 * POST-SYNC Function: Sync Mobile Sync Tables to Parent Tables
 *
 * This function syncs mobile-created records from mobile sync tables
 * back to the parent tables in the desktop database.
 *
 * Mobile Sync Tables -> Parent Tables:
 *   workdiary -> daily_work
 *   learequest -> atleaverequest
 *
 * Usage: SELECT sync_mobile_to_parent();
 */

CREATE OR REPLACE FUNCTION sync_mobile_to_parent()
RETURNS TEXT AS $$
DECLARE
  v_workdiary_count INTEGER := 0;
  v_learequest_count INTEGER := 0;
BEGIN
  -- ========================================================================
  -- 1. Sync workdiary (mobile sync) -> daily_work (parent table)
  -- ========================================================================

  -- Insert workdiary records into daily_work parent table
  -- Sync ALL records (desktop workdiary table has no source column)
  -- NOTE: daily_work has NOT NULL constraints, so we provide defaults for missing fields
  INSERT INTO daily_work (
    org_id,
    loc_id,
    work_dt,
    sporgid,     -- staff_id from workdiary
    job_id,
    task_id,     -- Required NOT NULL
    work_det,    -- tasknotes from workdiary (Required NOT NULL)
    manhrs_from, -- timefrom from workdiary
    manhrs_to,   -- timeto from workdiary
    work_man_min, -- minutes from workdiary
    jobdet_slno,  -- Required NOT NULL - use default 0
    year_id,      -- Required NOT NULL - derive from fiscal year
    dw_id         -- Required NOT NULL - use MAX+row_number()
  )
  SELECT
    COALESCE(w.org_id, 1),                         -- Default org_id if NULL
    COALESCE(w.loc_id, 1),                         -- Default loc_id if NULL
    w.date,
    w.staff_id,                                    -- Map to sporgid
    w.job_id,
    COALESCE(w.task_id, 1),                        -- Default task_id if NULL (task_id=1 exists)
    COALESCE(w.tasknotes, 'Mobile Entry'),         -- Default work_det if NULL
    w.timefrom,                                    -- Map to manhrs_from
    w.timeto,                                      -- Map to manhrs_to
    COALESCE(w.minutes, 0),                        -- Map to work_man_min (default 0 if NULL)
    0,                                             -- Default jobdet_slno
    CASE
      WHEN EXTRACT(MONTH FROM w.date) >= 4 THEN   -- Fiscal year: Apr-Mar
        (EXTRACT(YEAR FROM w.date) * 10000 + (EXTRACT(YEAR FROM w.date) + 1))::NUMERIC
      ELSE
        ((EXTRACT(YEAR FROM w.date) - 1) * 10000 + EXTRACT(YEAR FROM w.date))::NUMERIC
    END,                                           -- year_id (fiscal year)
    COALESCE((SELECT MAX(dw_id) FROM daily_work), 0) + ROW_NUMBER() OVER (ORDER BY w.date)
  FROM workdiary w
  WHERE w.job_id IS NOT NULL  -- Only require job_id (org_id/loc_id can be NULL)
    AND NOT EXISTS (
      -- Avoid duplicates: check if record already exists in daily_work
      SELECT 1 FROM daily_work dw
      WHERE dw.sporgid = w.staff_id
        AND dw.job_id = w.job_id
        AND dw.work_dt = w.date
    );

  GET DIAGNOSTICS v_workdiary_count = ROW_COUNT;

  -- ========================================================================
  -- 2. Sync learequest (mobile sync) -> atleaverequest (parent table)
  -- ========================================================================

  -- Insert mobile-created leave requests into atleaverequest parent table
  -- Only sync records where source='M' (mobile-created)
  -- NOTE: attschedule_id is looked up from atschedule table by matching:
  --   - fromdate falls within attschfrom-attschto date range
  --   - If no match, use the schedule that covers the createddate
  INSERT INTO atleaverequest (
    attschedule_id,  -- Required NOT NULL - lookup from atschedule by date range
    org_id,
    loc_id,
    staff_id,        -- Staff who requested leave
    learequest_id,   -- Required NOT NULL - use MAX+ROW_NUMBER()
    leareqdocdate,   -- requestdate from learequest
    leareqfrom,      -- fromdate from learequest
    leareqto,        -- todate from learequest
    leareq_fhvalue,  -- fhvalue from learequest
    leareq_shvalue,  -- shvalue from learequest
    leareqreason     -- leaveremarks from learequest
  )
  SELECT
    -- Lookup attschedule_id from atschedule table by matching date range
    COALESCE(
      -- First: Find schedule where fromdate falls within attschfrom-attschto range
      (SELECT ats.attschedule_id
       FROM atschedule ats
       WHERE lr.fromdate BETWEEN ats.attschfrom AND ats.attschto
       LIMIT 1),
      -- Second: Find schedule where createddate falls within range
      (SELECT ats.attschedule_id
       FROM atschedule ats
       WHERE lr.createddate BETWEEN ats.attschfrom AND ats.attschto
       LIMIT 1),
      -- Last resort: Get the most recent attschedule_id
      (SELECT ats.attschedule_id
       FROM atschedule ats
       ORDER BY ats.attschfrom DESC
       LIMIT 1)
    ) AS attschedule_id,
    lr.org_id,
    lr.loc_id,
    lr.staff_id,     -- Map staff_id from learequest
    COALESCE((SELECT MAX(learequest_id) FROM atleaverequest), 0) + ROW_NUMBER() OVER (ORDER BY lr.fromdate),
    lr.requestdate,  -- Map to leareqdocdate
    lr.fromdate,     -- Map to leareqfrom
    lr.todate,       -- Map to leareqto
    CASE WHEN lr.fhvalue = 'Y' THEN 1 ELSE 0 END, -- Convert Y/N to 1/0
    CASE WHEN lr.shvalue = 'Y' THEN 1 ELSE 0 END, -- Convert Y/N to 1/0
    lr.leaveremarks  -- Map to leareqreason
  FROM learequest lr
  WHERE lr.source = 'M'  -- Only mobile-created records
    AND lr.org_id IS NOT NULL  -- Skip records with missing required fields
    AND lr.loc_id IS NOT NULL
    -- Ensure we can find a valid attschedule_id (at least one schedule exists)
    AND EXISTS (
      SELECT 1 FROM atschedule
    )
    AND NOT EXISTS (
      -- Avoid duplicates: check by staff_id + fromdate + todate (unique leave request)
      SELECT 1 FROM atleaverequest alr
      WHERE alr.staff_id = lr.staff_id
        AND alr.leareqfrom = lr.fromdate
        AND alr.leareqto = lr.todate
    );

  GET DIAGNOSTICS v_learequest_count = ROW_COUNT;

  -- ========================================================================
  -- Return summary
  -- ========================================================================

  RETURN FORMAT(
    'Mobile-to-Parent Sync Complete: %s workdiary records, %s leave requests synced to parent tables',
    v_workdiary_count,
    v_learequest_count
  );

END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION sync_mobile_to_parent() TO PUBLIC;
`;

async function installFunction() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║  Installing sync_mobile_to_parent() Function             ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  const pool = new Pool(config.source);

  try {
    console.log('[...] Connecting to Desktop PostgreSQL...');
    await pool.query('SELECT NOW()');
    console.log('[OK] Connected\n');

    console.log('[...] Creating/Replacing function...');
    await pool.query(FUNCTION_SQL);
    console.log('[OK] Function created successfully\n');

    // Verify function was created
    const functionCheck = await pool.query(`
      SELECT p.proname, pg_get_functiondef(p.oid) as definition
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'sync_mobile_to_parent'
        AND n.nspname = 'public'
    `);

    if (functionCheck.rows.length > 0) {
      console.log('[OK] Function verified:');
      console.log('  - Name: sync_mobile_to_parent()');
      console.log('  - Returns: TEXT');

      const funcDef = functionCheck.rows[0].definition;
      if (funcDef.includes('attschedule_id')) {
        console.log('  - Has attschedule_id column: ✓');
      }
      if (funcDef.includes('workdiary')) {
        console.log('  - Syncs workdiary -> daily_work: ✓');
      }
      if (funcDef.includes('learequest')) {
        console.log('  - Syncs learequest -> atleaverequest: ✓');
      }
    }

    console.log('\n═'.repeat(60));
    console.log('[SUCCESS] Function installed successfully!');
    console.log('═'.repeat(60));
    console.log('\n✓ Next step: Test the post-sync:');
    console.log('  node scripts/test-post-sync.js\n');

    process.exit(0);

  } catch (error) {
    console.error('\n[ERROR]', error.message);
    console.error(error);
    process.exit(1);

  } finally {
    await pool.end();
  }
}

// Run
installFunction();
