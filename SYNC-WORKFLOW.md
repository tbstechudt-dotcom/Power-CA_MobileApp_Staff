# PowerCA Mobile - Complete Sync Workflow

This document explains the complete bidirectional sync workflow between Desktop PostgreSQL and Supabase Cloud.

## 📊 Sync Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Desktop PostgreSQL (enterprise_db)                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────┐      sync_views_to_tables()    ┌────────────┐ │
│  │  Parent Tables   │  ───────────────────────────►  │ Mobile     │ │
│  │  (Original)      │                                 │ Sync       │ │
│  │  - sporg         │  ON CONFLICT DO NOTHING         │ Tables     │ │
│  │  - job           │  (avoids duplicates)            │            │ │
│  │  - jobdet        │                                 │ - mbstaff  │ │
│  │  - climaster_v1  │                                 │ - jobshead │ │
│  │  - etc.          │                                 │ - jobtasks │ │
│  └──────────────────┘                                 │ - etc.     │ │
│                                                        └────────────┘ │
│                                                              │        │
└──────────────────────────────────────────────────────────────┼────────┘
                                                               │
                                                               │ Forward Sync
                                                               ▼
                        ┌────────────────────────────────────────────┐
                        │      Supabase Cloud PostgreSQL             │
                        ├────────────────────────────────────────────┤
                        │  Tables: jobshead, jobtasks, climaster,   │
                        │          mbstaff, workdiary, learequest    │
                        │  Source: 'D' (Desktop) or 'M' (Mobile)     │
                        └────────────────────────────────────────────┘
                                                               │
                                                               │ Reverse Sync
                                                               │ (workdiary,
                                                               │  learequest only)
                                                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Desktop PostgreSQL (enterprise_db)                │
├─────────────────────────────────────────────────────────────────────┤
│  ┌────────────┐                                                      │
│  │ workdiary  │  ◄───── Mobile time tracking entries                │
│  │ learequest │  ◄───── Mobile leave requests                       │
│  └────────────┘                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔄 Sync Workflow Steps

### Step 1: Pre-Sync (Desktop Parent Tables → Mobile Sync Tables)

**What it does:**
- Calls `sync_views_to_tables()` function in desktop database
- Syncs data from parent tables (via views) to mobile sync tables
- Uses `ON CONFLICT DO NOTHING` to avoid duplicates

**When to run:**
- Before every forward sync
- Ensures parent table updates are included in sync

**Command:**
```bash
# Development
node sync/pre-sync-desktop-views.js

# Production
node sync/production/pre-sync-desktop-views.js
```

**Tables synced:**
- orgmaster ← v_orgmaster
- locmaster ← v_locmaster
- conmaster ← v_conmaster
- climaster ← v_climaster
- mbstaff ← v_mbstaff
- jobshead ← v_jobshead
- jobtasks ← v_jobtasks
- taskchecklist ← v_taskchecklist
- mbreminder ← v_mbreminder
- mbremdetail ← v_mbremdetail

---

### Step 2: Forward Sync (Desktop → Supabase)

**What it does:**
- Syncs mobile sync tables from desktop to Supabase
- Marks records with `source='D'` (Desktop-originated)
- Uses staging tables for safety (ACID transactions)

**Modes:**
- **Full**: Sync all records (initial sync or after schema changes)
- **Incremental**: Sync only changed records (daily operation)

**Command:**
```bash
# Development - Full sync
node sync/runner-staging.js --mode=full

# Development - Incremental sync
node sync/runner-staging.js --mode=incremental

# Production - Full sync
node sync/production/runner-staging.js --mode=full

# Production - Incremental sync
node sync/production/runner-staging.js --mode=incremental
```

**Tables synced:**
- orgmaster, locmaster, conmaster
- climaster, mbstaff, taskmaster
- jobshead, jobtasks, taskchecklist
- reminder, remdetail

**Duration:**
- Full sync: ~2-5 minutes
- Incremental sync: ~30-60 seconds

---

### Step 3: Reverse Sync (Supabase → Desktop)

**What it does:**
- Syncs ONLY mobile-created records back to desktop
- **Only syncs 2 tables**: workdiary and learequest
- Uses incremental sync with metadata tracking

**Why only 2 tables?**
- `workdiary`: Mobile time tracking entries
- `learequest`: Mobile leave requests
- All other tables are desktop-originated and should NOT reverse sync

**Command:**
```bash
# Development
node sync/reverse-sync-runner.js

# Production
node sync/production/reverse-sync-runner.js
```

**Duration:** ~2-5 seconds

---

## 🚀 Complete Sync (All 3 Steps)

Run all 3 steps automatically with one command:

```bash
# Development - Full sync
node sync/full-sync.js --mode=full

# Development - Incremental sync
node sync/full-sync.js --mode=incremental

# Production - Full sync
node sync/production/full-sync-staging.js --mode=full

# Production - Incremental sync
node sync/production/full-sync-staging.js --mode=incremental
```

**What it does:**
1. ✅ Pre-sync desktop views to mobile sync tables
2. ✅ Forward sync desktop to Supabase
3. ✅ Reverse sync mobile data back to desktop

**Total duration:**
- Full sync: ~3-6 minutes
- Incremental sync: ~40-70 seconds

---

## 📅 Recommended Sync Schedule

### Daily Sync (Automated)
```bash
# Run every night at 2 AM
node sync/production/full-sync-staging.js --mode=incremental
```

**Why incremental?**
- Only syncs changed records (fast)
- Reduces load on servers
- Sufficient for daily updates

### Weekly Sync (Manual/Automated)
```bash
# Run every Sunday at 3 AM
node sync/production/full-sync-staging.js --mode=full
```

**Why full?**
- Ensures complete data consistency
- Catches any missed incremental updates
- Rebuilds sync metadata

### On-Demand Sync
```bash
# Run when needed (e.g., after major data changes)
node sync/production/full-sync-staging.js --mode=full
```

---

## ⚠️ Important Notes

### 1. Always Run Pre-Sync First
Never skip pre-sync before forward sync! Parent table updates won't be included otherwise.

**Bad (missing parent updates):**
```bash
node sync/runner-staging.js --mode=full  # ❌ Skips parent table updates
```

**Good (includes parent updates):**
```bash
node sync/full-sync.js --mode=full       # ✅ Runs pre-sync first
```

### 2. Reverse Sync Only Syncs 2 Tables
- **workdiary**: Mobile time tracking
- **learequest**: Mobile leave requests

All other tables are desktop-originated and should NOT reverse sync. If you need to sync other tables back to desktop, you're likely doing something wrong!

### 3. Incremental Sync Requires Metadata
First run must be `--mode=full` to initialize `_sync_metadata` table. After that, incremental sync will work.

### 4. Use Production Scripts for Production
Always use scripts in `sync/production/` for production deployments. They have additional safety checks and logging.

---

## 🐛 Troubleshooting

### Pre-Sync Fails with "Function not found"
```
[X] Function sync_views_to_tables() not found in database
```

**Solution:** Create the function in desktop database:
```sql
-- Run this SQL in enterprise_db
-- (Function definition available in database schema)
```

### Forward Sync Fails with "Connection timeout"
**Solution:** Increase timeouts in `sync/config.js`:
```javascript
target: {
  statement_timeout: 1800000,  // 30 minutes
  idle_in_transaction_session_timeout: 900000,  // 15 minutes
}
```

### Reverse Sync Shows "Already existed" for all records
This is normal! It means:
- No new mobile data since last sync
- Desktop database already has all mobile records

### Incremental Sync Not Finding New Records
**Solution:** Check metadata table:
```sql
-- In enterprise_db (desktop)
SELECT * FROM _sync_metadata;

-- Reset metadata to force full sync
DELETE FROM _sync_metadata WHERE table_name = 'jobshead';
```

---

## 📚 Additional Documentation

- [CLAUDE.md](CLAUDE.md) - Complete project guide with all fixes
- [sync/README.md](sync/README.md) - Detailed sync engine documentation
- [sync/SYNC-ENGINE-ETL-GUIDE.md](sync/SYNC-ENGINE-ETL-GUIDE.md) - ETL process guide

---

**Last Updated:** 2025-11-26
**Version:** 1.0
