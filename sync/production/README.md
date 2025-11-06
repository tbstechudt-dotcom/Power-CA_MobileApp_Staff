# Production Sync Scripts

**[OK] SAFE FOR PRODUCTION USE**

These scripts use **staging tables** to protect production data. If the sync fails at any point, your production data remains intact.

---

## Scripts in This Folder

### 1. Desktop -> Supabase Sync (Forward Sync)

#### `runner-staging.js` - Main Sync Orchestrator
**Purpose:** Orchestrates full or incremental sync from Desktop PostgreSQL to Supabase Cloud

**Usage:**
```bash
# Full sync (all tables)
node sync/production/runner-staging.js --mode=full

# Incremental sync (transactional tables only)
node sync/production/runner-staging.js --mode=incremental

# Run in background (recommended for production)
nohup node sync/production/runner-staging.js --mode=full > sync.log 2>&1 &

# Monitor progress
tail -f sync.log
```

**What it does:**
- Uses staging tables for atomic operations
- Syncs master tables (orgmaster, locmaster, climaster, mbstaff)
- Syncs transactional tables (jobshead, jobtasks, workdiary, etc.)
- Safe interruption handling (production data protected)

---

#### `engine-staging.js` - Core Sync Engine
**Purpose:** Core sync engine with staging table implementation

**Features:**
- Creates temporary staging tables
- Loads data safely to staging
- Atomic swap with production tables
- Automatic rollback on errors
- FK constraint handling
- Auto-increment column skipping

**Usage:**
```javascript
const StagingSyncEngine = require('./sync/production/engine-staging');

const engine = new StagingSyncEngine();

// Full sync
await engine.syncAll('full');

// Incremental sync
await engine.syncAll('incremental');

// Single table sync
await engine.syncTableSafe('climaster', 'full');
```

**Safety guarantees:**
- [OK] All-or-nothing sync (atomic)
- [OK] Production data never lost
- [OK] Automatic rollback on failure
- [OK] Connection drop protection

---

### 2. Supabase -> Desktop Sync (Reverse Sync)

#### `reverse-sync-engine.js` - Reverse Sync Engine
**Purpose:** Syncs mobile-created data from Supabase back to Desktop PostgreSQL

**Usage:**
```bash
# Run reverse sync
node sync/production/reverse-sync-engine.js

# Run in background
nohup node sync/production/reverse-sync-engine.js > reverse-sync.log 2>&1 &
```

**What it syncs:**
- Records created on mobile (source='M')
- Updated records (based on updated_at timestamp)
- New jobs, tasks, clients, reminders, work diary entries

**How it works:**
1. Queries Supabase for records with `source='M'` or recent `updated_at`
2. Identifies records not in Desktop DB (by comparing IDs)
3. Inserts new records into Desktop PostgreSQL
4. No FK constraints to worry about (Desktop has none)

---

#### `reverse-sync-runner.js` - Reverse Sync Orchestrator
**Purpose:** Scheduled runner for reverse sync operations

**Usage:**
```bash
# Run once
node sync/production/reverse-sync-runner.js

# Schedule with cron (every hour)
0 * * * * cd /path/to/PowerCA\ Mobile && node sync/production/reverse-sync-runner.js

# Schedule with Windows Task Scheduler
# Action: Start a program
# Program: node
# Arguments: sync/production/reverse-sync-runner.js
# Start in: D:\PowerCA Mobile
```

---

### 3. Configuration

#### `config.js` - Database Configuration
**Purpose:** Database connection settings for both source and target

**Configuration:**
```javascript
module.exports = {
  source: {
    // Desktop PostgreSQL (source of truth)
    host: 'localhost',
    port: 5433,
    database: 'enterprise_db',
    user: 'postgres',
    password: process.env.DESKTOP_DB_PASSWORD,
  },
  target: {
    // Supabase Cloud (mobile backend)
    host: process.env.SUPABASE_DB_HOST,
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: process.env.SUPABASE_DB_PASSWORD,
    ssl: { rejectUnauthorized: false }
  }
};
```

**Environment variables required:**
- `DESKTOP_DB_PASSWORD` - Desktop PostgreSQL password
- `SUPABASE_DB_HOST` - Supabase host (db.jacqfogzgzvbjeizljqf.supabase.co)
- `SUPABASE_DB_PASSWORD` - Supabase PostgreSQL password

---

## Quick Start Guide

### First Time Setup

1. **Install dependencies:**
```bash
npm install pg dotenv
```

2. **Configure environment:**
```bash
# Create .env file
cat > .env << EOF
DESKTOP_DB_PASSWORD=your_desktop_password
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PASSWORD=your_supabase_password
EOF
```

3. **Test connection:**
```bash
# Test Desktop connection
psql -h localhost -p 5433 -U postgres -d enterprise_db -c "\dt"

# Test Supabase connection
psql "postgresql://postgres:[password]@db.jacqfogzgzvbjeizljqf.supabase.co:5432/postgres" -c "\dt"
```

---

### Running Production Sync

**Initial full sync:**
```bash
# Run in background (takes 1-2 hours for large datasets)
nohup node sync/production/runner-staging.js --mode=full > sync-$(date +%Y%m%d).log 2>&1 &

# Monitor progress
tail -f sync-*.log

# Check process
ps aux | grep "runner-staging"
```

**Daily incremental sync:**
```bash
# Quick sync of changed records only
node sync/production/runner-staging.js --mode=incremental
```

**Scheduled reverse sync:**
```bash
# Sync mobile-created data back to desktop (hourly)
# Add to crontab:
0 * * * * cd /path/to/PowerCA\ Mobile && node sync/production/reverse-sync-runner.js >> reverse-sync.log 2>&1
```

---

## Monitoring and Troubleshooting

### Check Sync Status

**View running syncs:**
```bash
# List sync processes
ps aux | grep "node sync"

# Check PostgreSQL connections
psql "postgresql://..." -c "SELECT pid, state, query FROM pg_stat_activity WHERE state = 'active';"
```

**Monitor record counts:**
```bash
# Compare Desktop vs Supabase
node scripts/verify-all-tables.js

# Or manually:
# Desktop
psql -h localhost -p 5433 -d enterprise_db -c "SELECT COUNT(*) FROM jobshead;"

# Supabase
psql "postgresql://..." -c "SELECT COUNT(*) FROM jobshead;"
```

---

### Common Issues

**Issue: Sync times out**
```bash
# Solution: Increase timeout in config.js
target: {
  statement_timeout: 1800000,  // 30 minutes
  idle_in_transaction_session_timeout: 900000,  // 15 minutes
}
```

**Issue: FK constraint violations**
```bash
# Check logs for specific violations
grep "foreign key constraint" sync.log

# If needed, remove problematic FK constraints
# See scripts/remove-jobshead-client-fk.js for example
```

**Issue: Disk space exhausted**
```bash
# Staging tables need 2x table size temporarily
# Check available space
df -h

# Free up space or sync tables individually
node -e "
const engine = require('./sync/production/engine-staging');
await engine.syncTableSafe('climaster', 'full');
"
```

---

## Safety Features

### What Makes These Scripts Safe?

1. **Staging Tables:**
   - Data loaded to temporary staging table first
   - Production table only modified in atomic transaction
   - If sync fails, staging dropped and production untouched

2. **Transactions:**
   - All critical operations wrapped in BEGIN/COMMIT
   - Automatic ROLLBACK on errors
   - Connection drops trigger automatic rollback

3. **FK Handling:**
   - Pre-validates foreign key references
   - Filters invalid records before insert
   - FK constraints removed where desktop data violates them

4. **Auto-Increment Columns:**
   - Automatically skips SERIAL/BIGSERIAL columns
   - Lets PostgreSQL generate IDs via sequences
   - Prevents NULL constraint violations

---

## Performance Tips

**Optimize for large tables:**
```javascript
// Use batch inserts
const BATCH_SIZE = 1000;
for (let i = 0; i < records.length; i += BATCH_SIZE) {
  const batch = records.slice(i, i + BATCH_SIZE);
  await insertBatch(batch);
}
```

**Run syncs during off-hours:**
```bash
# Schedule for 2 AM daily
0 2 * * * node sync/production/runner-staging.js --mode=full
```

**Monitor resource usage:**
```bash
# CPU and memory during sync
top -p $(pgrep -f runner-staging)

# Network bandwidth
iftop -i eth0
```

---

## Pre-Deployment Checklist

Before running production sync:

- [ ] Environment variables configured (.env file)
- [ ] Database connections tested (Desktop and Supabase)
- [ ] Disk space checked (staging needs 2x table size)
- [ ] Timeouts configured appropriately (based on network)
- [ ] Backup created (Supabase dashboard -> Database -> Backups)
- [ ] Test sync run completed on copy of production data
- [ ] Monitoring tools in place (logs, alerts)

---

## Support and Documentation

- **Full Guide:** See [`../../CLAUDE.md`](../../CLAUDE.md)
- **AI Guide:** See [`../../AGENTS.md`](../../AGENTS.md)
- **Sync Strategy:** See [`../../docs/BIDIRECTIONAL-SYNC-STRATEGY.md`](../../docs/BIDIRECTIONAL-SYNC-STRATEGY.md)
- **Staging Pattern:** See [`../../docs/staging-table-sync.md`](../../docs/staging-table-sync.md)
- **Troubleshooting:** See [`../../docs/SYNC_GUIDE.md`](../../docs/SYNC_GUIDE.md)

---

**Remember:** These scripts are production-safe. They use staging tables and transactions to ensure your production data is never lost, even if the sync fails midway.

**Use ONLY these scripts for production syncs!** [OK]
