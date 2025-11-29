# PowerCA Mobile Sync Scripts

This folder contains scripts for bidirectional data synchronization between Desktop PostgreSQL and Supabase Cloud.

---

## [FOLDER] Folder Organization

### [OK] [`production/`](production/) - Production-Safe Scripts
**USE THESE FOR PRODUCTION!**

Contains safe sync scripts that use **staging tables** to protect your production data. If a sync fails, your data remains intact.

```bash
# Example: Safe full sync
node sync/production/runner-staging.js --mode=full
```

**Scripts:**
- `runner-staging.js` - Main sync orchestrator (staging pattern)
- `engine-staging.js` - Core sync engine (atomic operations)
- `reverse-sync-engine.js` - Mobile -> Desktop sync
- `reverse-sync-runner.js` - Reverse sync orchestrator
- `config.js` - Database configuration

**[[DOCS] Read the production README](production/README.md)** <- **START HERE FOR PRODUCTION USE**

---

### [WARN] [`development/`](development/) - Development/Testing Only
**DO NOT USE IN PRODUCTION!**

Contains unsafe scripts that clear data FIRST, then insert. If sync fails midway, **your data will be LOST!**

Use these ONLY for:
- Local development databases
- Testing environments
- Learning and reference

**Scripts:**
- `runner-optimized.js` [ERROR] - Unsafe sync runner
- `engine-optimized.js` [ERROR] - Unsafe sync engine
- `sync-missing-jobs.js` [ERROR] - Clears jobshead/jobtasks first
- `sync-taskchecklist.js` [OK] - Safe for taskchecklist (handles auto-increment)
- Legacy scripts (runner.js, engine.js, etc.)

**[[DOCS] Read the development README](development/README.md)**

---

## [>>] Quick Start

### For Production Use

```bash
# Full sync (all tables) - SAFE [OK]
node sync/production/runner-staging.js --mode=full

# Incremental sync (changed records) - SAFE [OK] with AUTO-FULL for some tables
# Note: Mobile-PK tables (jobshead, jobtasks, taskchecklist, workdiary)
#       automatically run in FULL mode to prevent data loss
node sync/production/runner-staging.js --mode=incremental

# Reverse sync (mobile -> desktop) - SAFE [OK]
node sync/production/reverse-sync-engine.js

# Run in background (recommended)
nohup node sync/production/runner-staging.js --mode=full > sync.log 2>&1 &
```

### For Development/Testing

```bash
# [WARN] ONLY use on dev/test databases!
# These scripts clear data first
node sync/development/runner-optimized.js --mode=full
```

---

## [STATS] Sync Architecture

```
+------------------+         +-------------------+         +------------------+
|  Desktop         |         |   Sync Engine     |         |  Supabase Cloud  |
|  PostgreSQL      |-------->|  (Staging Tables) |-------->|  PostgreSQL      |
|  Port 5433       |         |                   |         |  + Auth/Storage  |
|  enterprise_db   |         |  Safe Atomicity   |         |                  |
\------------------+         \-------------------+         \------------------+
       ^                                                              |
       |                      +-------------------+                  |
       |                      |  Reverse Sync     |                  |
       \----------------------|  (Mobile->Desktop) |<-----------------+
                              \-------------------+
                                       ^
                                       |
                              +--------+--------+
                              |  Flutter Mobile |
                              |  App (iOS/      |
                              |  Android)       |
                              \-----------------+
```

**Forward Sync (Desktop -> Supabase):**
- Runs daily or on-demand
- Uses staging tables for safety
- Syncs master + transactional tables

**Reverse Sync (Supabase -> Desktop):**
- Runs hourly (scheduled)
- Syncs mobile-created records (`source='M'`)
- No FK constraints to worry about

---

## [KEY] Key Features

### Production Scripts (Safe)

[OK] **Staging Table Pattern**
- Creates temporary staging table
- Loads all data to staging
- Atomic swap with production (5-second risk window)
- Automatic rollback on failure

[OK] **Transaction Safety**
- All operations wrapped in BEGIN/COMMIT
- Automatic ROLLBACK on errors
- Connection drop protection

[OK] **FK Handling**
- Pre-validates foreign key references
- Filters invalid records
- Removed problematic FK constraints

[OK] **Auto-Increment Support**
- Automatically skips SERIAL/BIGSERIAL columns
- Lets PostgreSQL generate IDs

---

## [INFO] Configuration

### Environment Variables

Create a `.env` file in the project root:

```bash
# Desktop PostgreSQL
DESKTOP_DB_PASSWORD=your_desktop_password

# Supabase Cloud
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PASSWORD=your_supabase_password

# Optional: Sync settings
BATCH_SIZE=1000
STATEMENT_TIMEOUT=600000
```

### Database Connections

**Desktop (Source):**
- Host: `localhost`
- Port: `5433`
- Database: `enterprise_db`
- User: `postgres`

**Supabase (Target):**
- Host: `db.jacqfogzgzvbjeizljqf.supabase.co`
- Port: `5432`
- Database: `postgres`
- User: `postgres`
- SSL: Required

---

## [STATS] Tables Synced

### Master Tables (Full Sync)
- `orgmaster` (2 records)
- `locmaster` (1 record)
- `conmaster` (4 records)
- `climaster` (726 records)
- `mbstaff` (16 records)

### Transactional Tables (Incremental Sync*)
- `jobshead` (24,568 records) **(AUTO-FULL mode - mobile PK)**
- `jobtasks` (64,711 records) **(AUTO-FULL mode - mobile PK)**
- `taskchecklist` (2,894 records) **(AUTO-FULL mode - mobile PK)**
- `workdiary` **(AUTO-FULL mode - mobile PK)**
- `reminder` (132 records) *(true incremental)*
- `remdetail` (39 records) *(true incremental)*
- `learequest` *(true incremental)*

**Note:** Tables with mobile-generated primary keys (jobshead, jobtasks, taskchecklist, workdiary)
automatically run in FULL mode even when `--mode=incremental` is specified. This prevents data loss
from the DELETE+INSERT pattern used for these tables. See [CRITICAL-FIX-INCREMENTAL-DATA-LOSS.md](../docs/CRITICAL-FIX-INCREMENTAL-DATA-LOSS.md) for details.

---

## [TOOLS] Monitoring

### Check Sync Status

```bash
# List running syncs
ps aux | grep "node sync"

# Check PostgreSQL connections
psql "postgresql://..." -c "SELECT pid, state, query FROM pg_stat_activity WHERE state = 'active';"

# Monitor log files
tail -f sync.log
tail -f reverse-sync.log
```

### Verify Record Counts

```bash
# Compare Desktop vs Supabase
node scripts/verify-all-tables.js

# Or manually:
psql -h localhost -p 5433 -d enterprise_db -c "SELECT COUNT(*) FROM jobshead;"
psql "postgresql://..." -c "SELECT COUNT(*) FROM jobshead;"
```

---

## [ALERT] Troubleshooting

### Common Issues

**Issue: FK constraint violations**
```bash
# Check logs
grep "foreign key constraint" sync.log

# Solution: Remove problematic FK constraints
# See: scripts/remove-jobshead-client-fk.js
```

**Issue: Sync timeout**
```bash
# Solution: Increase timeout in config.js
target: {
  statement_timeout: 1800000,  // 30 minutes
}
```

**Issue: Disk space exhausted**
```bash
# Staging tables need 2x space
df -h

# Solution: Free up space or sync tables individually
```

---

## [LIBRARY] Documentation

- **[CLAUDE.md](../CLAUDE.md)** - Comprehensive project guide (for Claude AI)
- **[AGENTS.md](../AGENTS.md)** - Quick reference guide (for GitHub Copilot, Codex, etc.)
- **[Production Scripts README](production/README.md)** - Detailed production guide [*]
- **[Sync Scheduling Guide](../docs/SYNC-SCHEDULING-GUIDE.md)** - Automated scheduling setup [*]
- **[Development Scripts README](development/README.md)** - Development scripts guide
- **[Staging Pattern Explained](../docs/staging-table-sync.md)** - Deep dive into staging tables
- **[Sync Strategy](../docs/BIDIRECTIONAL-SYNC-STRATEGY.md)** - Architecture overview
- **[Troubleshooting Guide](../docs/SYNC_GUIDE.md)** - Common issues and solutions

---

## [OK] Pre-Deployment Checklist

Before running production sync:

- [ ] Review [production/README.md](production/README.md)
- [ ] Configure environment variables (.env)
- [ ] Test database connections
- [ ] Check disk space (staging needs 2x table size)
- [ ] Create backup (Supabase dashboard)
- [ ] Set appropriate timeouts
- [ ] Monitor tools in place

---

## [GOAL] Decision Tree

```
Need to sync data?
+- Production environment?
|  +- YES -> Use sync/production/ scripts [OK]
|  \- NO -> Can use sync/development/ scripts [WARN]
|
+- Desktop -> Supabase?
|  \- Use sync/production/runner-staging.js [OK]
|
+- Supabase -> Desktop?
|  \- Use sync/production/reverse-sync-engine.js [OK]
|
\- Specific table with auto-increment PK?
   \- Use sync/development/sync-taskchecklist.js [OK]
```

---

## [LOCK] Safety Rules

### ALWAYS:
[OK] Use staging table scripts for production
[OK] Run syncs in background (nohup)
[OK] Create backups before major syncs
[OK] Monitor sync logs for errors
[OK] Test on dev/test database first

### NEVER:
[ERROR] Use development scripts on production
[ERROR] Run unsafe scripts without backup
[ERROR] Assume sync succeeded without verification
[ERROR] Schedule unsafe scripts as cron jobs
[ERROR] Skip pre-deployment checklist

---

## [CONTACT] Support

For issues or questions:

1. Check the appropriate README:
   - **Production:** [production/README.md](production/README.md) [*]
   - **Development:** [development/README.md](development/README.md)

2. Review documentation:
   - [CLAUDE.md](../CLAUDE.md) - Full project guide
   - [AGENTS.md](../AGENTS.md) - Quick reference

3. Check sync logs:
   ```bash
   tail -f sync.log
   grep "Error" sync.log
   ```

4. Verify database connections:
   ```bash
   psql -h localhost -p 5433 -d enterprise_db -c "\dt"
   psql "postgresql://..." -c "\dt"
   ```

---

**Remember:** When in doubt, use `sync/production/` scripts with staging tables! [>>]

**Document Version:** 2.0
**Last Updated:** 2025-10-30
**Purpose:** Organized sync script directory with clear separation between safe and unsafe scripts
