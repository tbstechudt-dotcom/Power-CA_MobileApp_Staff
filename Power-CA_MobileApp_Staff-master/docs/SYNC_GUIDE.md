# Power CA Mobile - Sync Guide

Quick reference for syncing data from desktop PostgreSQL to Supabase Cloud.

## Quick Start

### Option 1: SAFE Sync (Recommended for Production)
```bash
# Full sync - all tables
node sync/runner-staging.js --mode=full

# Incremental sync - transactional tables only
node sync/runner-staging.js --mode=incremental
```

**✅ SAFE:** If sync fails, production data remains untouched!

### Option 2: Fast Sync (Use only if you can afford data loss)
```bash
# Full sync - faster but risky
node sync/runner-optimized.js --mode=full

# Incremental sync
node sync/runner-optimized.js --mode=incremental
```

**⚠️ WARNING:** If connection fails midway, tables may be left empty!

## Which Sync Method to Use?

| Scenario | Use This | Why |
|----------|----------|-----|
| **Production sync** | `runner-staging.js` | Data safety is critical |
| **First-time setup** | `runner-staging.js` | Ensure complete sync |
| **After schema changes** | `runner-staging.js` | Avoid partial updates |
| **Regular scheduled sync** | `runner-staging.js` | Peace of mind |
| **Development/testing** | `runner-optimized.js` | Faster, can re-sync if fails |
| **Stable network** | Either | Both work fine |
| **Unstable network** | `runner-staging.js` | Protection from drops |

## Sync Modes

### Full Sync
Replaces **all data** in all tables:
- Master tables: orgmaster, locmaster, conmaster, climaster, mbstaff, etc.
- Transactional tables: jobshead, jobtasks, taskchecklist, reminder, etc.

**When to use:**
- Initial setup
- After data corruption
- Major data cleanup
- Schema changes

### Incremental Sync
Updates only **transactional tables** with changed records:
- jobshead, jobtasks, taskchecklist, workdiary, reminder, remdetail, learequest

**When to use:**
- Daily/hourly updates
- Minimal downtime required
- Only transaction data changed

## Understanding the Output

### Safe Sync (Staging Pattern)
```
🛡️  SAFE SYNC ENGINE - Staging Table Pattern
   Production data protected from failures!

--- Pre-loading Foreign Key References ---
  ✓ Loaded 726 valid client_ids
  ✓ FK cache ready

--- MASTER TABLES (Full Sync) ---

Syncing: climaster → climaster (full)
  - Extracted 729 records from source
  - Transformed 729 records
  - Filtered 3 invalid records (FK violations)
  - Creating staging table climaster_staging...
  - ✓ Staging table created
  - Loading data into staging table...
  - ✓ Loaded 726 records to staging table
  - Beginning atomic swap...
  - ✓ Cleared production table
  - ✓ Copied 726 records to production
  - ✓ Transaction committed (atomic swap complete)
  - ✓ Staging table dropped
  ✓ Loaded 726 records to target
  Duration: 52.31s
```

**Key Points:**
- `Filtered X invalid records` = Records skipped due to FK violations
- `atomic swap complete` = Data safely committed
- `Transaction committed` = Success!

### If Sync Fails
```
  - ✗ Atomic swap failed, rolling back
  - ✓ Production data restored (unchanged)

❌ Sync failed: Connection terminated unexpectedly
🛡️  Your production data is SAFE and unchanged!
```

**What happened:**
- Sync encountered an error
- PostgreSQL rolled back the transaction
- Production data was restored to previous state
- You can re-run sync safely

## Data Filtering

The sync engine filters invalid records **before** inserting:

### Example: Invalid Foreign Keys
```
Syncing: jobshead → jobshead (full)
  - Extracted 24568 records from source
  - Filtered 3942 invalid records (FK violations)
  - Will sync 20626 valid records
    ✗ Skipped: Invalid client_id=500 (no matching climaster)
    ✗ (3941 more filtered records...)
```

**What this means:**
- Desktop database has 24,568 jobs
- 3,942 jobs reference non-existent clients (data quality issue)
- Only 20,626 valid jobs will sync
- **Action:** Fix data quality in desktop database

### Common Filtering Reasons
- `Invalid client_id` - Job references deleted client
- `Invalid loc_id` - Record references non-existent location
- `Invalid staff_id` - Task assigned to deleted staff
- `Invalid job_id` - Task references non-existent job

## Troubleshooting

### Issue: Connection Timeout
```
ERROR: Connection terminated unexpectedly
```

**Solutions:**
1. Use safe sync: `node sync/runner-staging.js --mode=full`
2. Check network connection
3. Increase timeout in `.env`:
   ```
   SUPABASE_TIMEOUT=600000
   ```

### Issue: Many Records Filtered
```
Filtered 3942 invalid records (FK violations)
```

**Solutions:**
1. Identify invalid references:
   ```bash
   node scripts/analyze-invalid-clients.js
   ```
2. Fix data quality in desktop database
3. Remove FK constraints to allow orphaned records:
   ```bash
   node scripts/remove-jobshead-client-fk.js
   node sync/sync-missing-jobs.js
   ```
4. Or accept data loss (filtered records won't sync)

### Issue: Sync Runs Forever
```
Syncing: jobshead → jobshead (full)
  - Extracted 24568 records from source
  (no further output)
```

**Solutions:**
1. Check database connectivity:
   ```bash
   node scripts/test-connection.js
   ```
2. Check Supabase dashboard for errors
3. Kill and restart sync:
   ```bash
   Ctrl+C
   node sync/runner-staging.js --mode=full
   ```

### Issue: Out of Disk Space
```
ERROR: could not extend file: No space left on device
```

**Solutions:**
1. Free up disk space on Supabase
2. Sync tables individually:
   ```javascript
   const engine = new StagingSyncEngine();
   await engine.syncTableSafe('climaster', 'full');
   ```

## Verifying Sync Results

### Check Record Counts
```bash
node scripts/verify-final-sync.js
```

Output:
```
FINAL SYNC VERIFICATION
----------------------------------------------------------------------
  orgmaster                     2 records
  locmaster                     1 records
  conmaster                     4 records
  climaster                   726 records
  jobshead                 20,626 records
  jobtasks                 52,869 records
  taskchecklist             2,894 records
  reminder                    132 records
  remdetail                    37 records
----------------------------------------------------------------------
  TOTAL                    77,291 records
```

### Compare with Source
```bash
node scripts/compare-counts.js
```

Shows differences between local and Supabase counts.

## Scheduled Syncs

### Daily Incremental Sync (Recommended)
```bash
# crontab -e
0 2 * * * cd /path/to/PowerCA-Mobile && node sync/runner-staging.js --mode=incremental >> logs/sync.log 2>&1
```

Runs every day at 2 AM, appends to log file.

### Weekly Full Sync (Optional)
```bash
# crontab -e
0 3 * * 0 cd /path/to/PowerCA-Mobile && node sync/runner-staging.js --mode=full >> logs/sync-full.log 2>&1
```

Runs every Sunday at 3 AM.

## Best Practices

### 1. Always Use Safe Sync for Production
```bash
# ✅ DO
node sync/runner-staging.js --mode=full

# ❌ DON'T (unless you know what you're doing)
node sync/runner-optimized.js --mode=full
```

### 2. Monitor Disk Space
```bash
# Check Supabase database size
SELECT pg_size_pretty(pg_database_size('postgres'));
```

### 3. Keep Logs
```bash
# Log sync output
node sync/runner-staging.js --mode=full > logs/sync-$(date +%Y%m%d).log 2>&1
```

### 4. Validate After Sync
```bash
# Always verify counts after sync
node scripts/verify-final-sync.js
```

### 5. Backup Before Major Changes
```bash
# Backup Supabase data before full sync
pg_dump -h db.supabase.co -U postgres -d postgres > backup-$(date +%Y%m%d).sql
```

## Performance Tips

### 1. Sync During Off-Peak Hours
- Night time (2-4 AM)
- Weekends
- Low user activity periods

### 2. Use Incremental Sync When Possible
```bash
# Faster, less data transferred
node sync/runner-staging.js --mode=incremental
```

### 3. Monitor Network Bandwidth
```bash
# Check network usage during sync
iftop -i eth0
```

### 4. Optimize Batch Size
Edit `sync/config.js`:
```javascript
sync: {
  batchSize: 100,  // Decrease if connection unstable
                   // Increase for faster sync on stable network
}
```

## Summary

**For Production:** Always use `runner-staging.js`
- ✅ Safe from connection failures
- ✅ Atomic operations
- ✅ Production data protected
- ✅ Automatic rollback on errors

**Monitor your syncs:**
- Check logs regularly
- Verify record counts
- Watch for filtered records
- Fix data quality issues

**Questions?** See [staging-table-sync.md](./staging-table-sync.md) for technical details.

---

**Last Updated:** 2025-10-30
