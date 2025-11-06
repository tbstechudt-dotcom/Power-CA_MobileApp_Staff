# PowerCA Mobile - Technical Debt

This document tracks known technical debt, workarounds, and future architectural improvements for the PowerCA Mobile project.

**Last Updated**: 2025-10-28

---

## Critical Priority

*No critical items at this time.*

---

## High Priority

### 1. Foreign Key Data Integrity Issues ⚠️

**Issue**: Desktop database has orphaned records that violate foreign key constraints

**Affected Tables**:
- `climaster`: 594 out of 729 records have invalid `con_id` references (81% failure rate)
- `jobshead`: ~64% of records have invalid `client_id` references
- `mbstaff`: All 16 records currently failing sync

**Current Impact**:
- Only 18.5% of client data syncing successfully
- Only 36% of job data syncing successfully
- No staff data syncing (mbstaff schema mismatch resolved, pending re-sync)

**Root Cause**:
- Desktop database has no PRIMARY KEY or FOREIGN KEY constraints
- Data integrity not enforced at database level
- Orphaned references accumulated over time

**Workarounds**:
1. Sync script skips records with FK violations (graceful degradation)
2. Valid records still sync successfully
3. Sync metadata logs all failures for review

**Resolution Plan**:
1. **Phase 1** (Immediate): Accept current data loss, sync valid records only
2. **Phase 2** (1-2 weeks): Data cleanup in desktop database
   - Identify all orphaned references
   - Either fix references or mark records as inactive
   - Re-run full sync after cleanup
3. **Phase 3** (Future): Add FK constraints to desktop database

**Priority**: High - Impacts 60%+ of data availability

---

## Medium Priority

### 2. Designation Master Table Missing ⚠️

**Issue**: `mbstaff.desc_id` column exists but no `descmaster` table to reference

**Current Impact**:
- Cannot filter staff by designation in mobile app
- Cannot display designation names (only numeric ID)
- Staff list filtering limited

**Affected Screens**:
- Team List (line 134 in workflow - filter by designation)
- Staff Profile (cannot show designation name)

**Workarounds**:
1. **Option A**: Hide designation filter entirely
2. **Option B**: Show `desc_id` as numeric value only
3. **Option C**: Hardcode common designation mappings in app

**Resolution Plan**:
1. **Short-term**: Implement Option A (hide designation filter)
2. **Phase 2**: Create `descmaster` table schema:
   ```sql
   CREATE TABLE descmaster (
     desc_id     NUMERIC(8)    PRIMARY KEY,
     desc_name   VARCHAR(100)  NOT NULL,
     desc_level  INTEGER,      -- Hierarchy level
     org_id      NUMERIC(3)    REFERENCES orgmaster(org_id),
     active      BOOLEAN       DEFAULT true
   );
   ```
3. **Phase 2**: Populate with actual designation data from desktop
4. **Phase 2**: Update mobile app to use descmaster lookups

**Priority**: Medium - Usability issue, not blocking

**Estimated Effort**: 1-2 days for table creation + data population

---

### 3. Scheduled Sync Latency ⚠️

**Issue**: Daily scheduled sync means mobile data can be up to 24 hours old

**Current Implementation**:
- Desktop → Supabase: Daily sync at 6:00 PM
- Method: JavaScript sync script (outbound connections)
- No real-time replication

**Impact**:
- Mobile users see yesterday's data until evening sync
- Not suitable for real-time collaboration
- New desktop jobs won't appear on mobile until next day

**Workarounds**:
1. Manual sync trigger for admins (in Settings)
2. More frequent sync schedule (e.g., hourly during business hours)
3. Mobile app shows "last sync" timestamp prominently

**Resolution Plan** (Post-MVP):
1. **Phase 1**: Increase sync frequency to hourly (easy win)
2. **Phase 2**: Implement VPN/tunnel for network access
3. **Phase 3**: Switch to PostgreSQL logical replication
   - Real-time changes desktop → Supabase
   - Requires: Static IP or DDNS, secure tunnel, port forwarding
   - Technology: PostgreSQL publications/subscriptions

**Priority**: Medium - Acceptable for MVP, needed for scale

**Estimated Effort**: 2-3 days for VPN setup + replication config

---

## Low Priority

### 4. Empty Template Tables

**Issue**: `taskmaster` and `jobmaster` tables exist but are empty

**Current Impact**:
- No task templates available
- No job templates available
- Users must create tasks/jobs from scratch each time

**Benefit of Resolution**:
- Faster job creation with pre-populated task lists
- Consistency across similar jobs
- Best practices encoding

**Resolution Plan**:
1. **Phase 2**: Define common CA firm job types:
   - Tax Return Filing
   - Audit - Statutory
   - Audit - Internal
   - GST Compliance
   - etc.
2. **Phase 2**: Create task templates for each job type
3. **Phase 2**: Update mobile app to support template selection

**Priority**: Low - Nice to have, not critical

**Estimated Effort**: 3-5 days for template definition + UI

---

### 5. IPv6 Network Dependency

**Issue**: Supabase database requires IPv6 connectivity

**Current Workaround**: Cloudflare WARP installed for IPv6 tunnel

**Impact**:
- Sync requires WARP to be running
- Additional software dependency
- Potential network performance impact

**Alternative Solutions**:
1. Use Supabase connection pooler (IPv4 compatible)
2. Set up IPv6 at ISP level
3. Use IPv4 proxy/tunnel

**Resolution Plan**: Document dependency, consider alternatives if WARP causes issues

**Priority**: Low - Currently working with WARP

---

## Documentation Debt

### 6. Missing API Documentation

**Issue**: No REST API documentation for Flutter developers

**Impact**: Flutter developers will need to reverse-engineer Supabase schema

**Resolution**: Create API documentation with:
- Authentication endpoints
- CRUD operations for all entities
- RLS policies and permissions
- Example requests/responses

**Priority**: Low - Can be generated from Supabase schema

---

## Performance Considerations

### 7. Slow Sync Performance

**Current Performance**: ~300-500 records/minute

**Issue**: Individual insert statements for each record (to handle FK errors)

**Impact**: 24,568 jobshead records take ~50-60 minutes to sync

**Workarounds**:
1. Run sync overnight
2. Only sync changed records (incremental mode)

**Optimization Options**:
1. Batch inserts for records known to be valid
2. Pre-validate records before sync
3. Use COPY command for bulk imports
4. Parallel processing (multiple tables simultaneously)

**Priority**: Low - Acceptable for daily sync

---

## Security Debt

### 8. Row Level Security (RLS) Not Configured

**Issue**: No RLS policies on Supabase tables yet

**Current Impact**: Any authenticated user can access all data

**Risk Level**: High (but mitigated by app logic)

**Resolution Plan**:
1. **Before launch**: Configure RLS policies for all tables
2. **Rules to implement**:
   - Staff can only see data for their `org_id`
   - Staff can only edit their own work diary entries
   - Only admins can modify master data
   - Job access based on assignment

**Priority**: Medium - Must do before production launch

**Estimated Effort**: 1 day for policy creation + testing

---

## Infrastructure Debt

### 9. No Backup Strategy

**Issue**: No automated backups configured for sync metadata or Supabase

**Current State**:
- Supabase Cloud handles database backups (7 days)
- No backup of sync script logs
- No backup of .env files

**Resolution Plan**:
1. **Immediate**: Document backup/restore procedures
2. **Phase 2**: Automated daily export of critical data
3. **Phase 2**: Backup sync logs to external storage

**Priority**: Low - Supabase provides basic backups

---

## Monitoring & Observability

### 10. Limited Sync Monitoring

**Issue**: No alerting when sync fails

**Current State**:
- Sync logs written to console/file
- `_sync_metadata` table tracks status
- No automated notifications

**Resolution Plan**:
1. **Phase 2**: Email notifications on sync failure
2. **Phase 2**: Dashboard showing sync health
3. **Phase 2**: Integration with monitoring service (e.g., Sentry)

**Priority**: Low - Can check manually for now

---

## Summary

**Total Debt Items**: 10

**By Priority**:
- Critical: 0
- High: 1 (Data integrity issues)
- Medium: 3 (Designation table, sync latency, RLS)
- Low: 6

**Estimated Total Effort to Clear**: 2-3 weeks

**Recommended Roadmap**:
1. **MVP Launch**: Accept current data integrity losses, hide designation filter, configure RLS
2. **Phase 2 (Post-MVP)**: Clean up desktop data, create descmaster table, implement hourly sync
3. **Phase 3 (Scale)**: Real-time replication, template system, monitoring/alerting

---

**Next Review Date**: 2025-11-28 (1 month)
