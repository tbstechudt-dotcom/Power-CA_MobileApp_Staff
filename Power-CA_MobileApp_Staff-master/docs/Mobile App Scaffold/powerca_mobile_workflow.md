# PowerCA Mobile App - Workflow & Screen Documentation

## Overview
PowerCA is a practice management mobile application for CA firms to manage clients, jobs, tasks, time tracking, and team collaboration.

## User Roles
1. **Admin/Partners** - Full access
2. **Senior Staff** - Manage jobs, clients, team
3. **Junior Staff** - View assigned jobs, log time, complete tasks
4. **Clients** (Future scope) - View job status, documents

## Core Modules

### 1. Authentication & Onboarding
- **Splash Screen**
- **Login Screen** (app_username, app_pw from mbstaff)
- **Forgot Password**
- **Biometric/PIN Setup** (optional)

### 2. Dashboard/Home
- **Overview Cards**
  - Pending tasks count
  - Today's reminders
  - Active jobs count
  - Hours logged today
- **Quick Actions**
  - Start work diary
  - Add reminder
  - View today's tasks
- **Recent Activity Feed**
- **Sync Status Indicator**
  - Last desktop sync time
  - Next scheduled sync

### 3. Jobs Module
#### Screens:
- **Jobs List** (jobshead)
  - Filter by status (active/completed)
  - Search by client name
  - Sort by target date
  - Filter by location (locmaster)
  - Filter by organization (orgmaster)

- **Job Details** (jobshead + jobtasks + climaster + locmaster)
  - Job information
  - Client details
  - Task list with estimated vs actual hours
  - Progress indicator (tasks completed/total)
  - Drive folder link
  - Drive type & ID (drive_type, drive_id)
  - Location: Office/Branch name

- **Create Job**
  - Select organization (orgmaster)
  - Select client (climaster)
  - Job nature (compliance/audit/advisory)
  - Work description
  - Target date
  - Select location (locmaster)

- **Task Management** (jobtasks)
  - Add/Edit tasks
  - Assign estimated hours (est_time_hours)
  - View actual hours (actual_time_hours)
  - Variance: estimated vs actual
  - Reorder tasks
  - Mark complete (task_status)

- **Task Checklist** (taskchecklist)
  - Checklist items per task
  - Mark applicable/not applicable
  - Upload format documents
  - Add comments

### 4. Work Diary/Time Tracking
#### Screens:
- **Work Diary List** (workdiary)
  - Calendar view
  - Day/Week/Month toggle
  - Total hours summary

- **Log Time Entry**
  - Select job & task
  - Date & time range picker (fromtime, totime)
  - Auto-calculate minutes
  - Task notes
  - Task status indicator
  - Attach documents

- **Time Reports**
  - Staff-wise report
  - Job-wise report
  - Client-wise report
  - Export options

### 5. Clients Module
#### Screens:
- **Clients List** (climaster)
  - Search & filter
  - Filter by organization (org_id)
  - Quick contact options

- **Client Details** (climaster + cliunimaster + conmaster)
  - Contact information
  - Primary Contact (from conmaster)
    - Contact name, phone, email
  - Multiple units/branches (cliunimaster)
  - Active jobs
  - History

- **Add/Edit Client**
  - Select organization (orgmaster)
  - Basic details
  - Primary contact (conmaster)
  - Contact information

- **Client Units** (cliunimaster)
  - Multiple addresses
  - Unit-specific contacts
  - Geolocation

- **Client Contacts** (conmaster)
  - List all contacts for client
  - View contact details
  - Quick call/email

### 6. Reminders & Calendar
#### Screens:
- **Calendar View** (reminder)
  - Monthly calendar
  - Day/Week/Month views
  - Color-coded reminders

- **Reminder List**
  - Upcoming reminders
  - Overdue items
  - Filter by type

- **Create Reminder**
  - Date & time
  - Reminder type (compliance/follow-up/meeting)
  - Assign to staff
  - Set notifications

- **Reminder Details** (reminder + remdetail)
  - Reminder info
  - Staff responses
  - Mark complete
  - Snooze options

### 7. Staff/Team Module
#### Screens:
- **Team List** (mbstaff)
  - Active staff
  - Filter by organization (org_id)
  - Filter by location (loc_id)
  - ~~Filter by designation~~ (See Technical Debt)
  - Quick call/email

- **Staff Profile** (mbstaff + orgmaster + locmaster)
  - Personal details
  - Organization (orgmaster.orgname)
  - Location (locmaster.locname)
  - CA membership info (whetherca, ca_mem_no)
  - Assigned jobs
  - **Performance metrics** (calculated from workdiary)
    - Total hours logged
    - Jobs completed
    - Average hours per task

- **Leave Management** (learequest)
  - Apply leave
  - View leave balance
  - Leave calendar
  - Approval (for managers)

### 8. Profile & Settings
#### Screens:
- **My Profile** (mbstaff + orgmaster + locmaster)
  - Personal details
  - Organization: Display orgname
  - Location: Display locname
  - Change password
  - Notification preferences

- **Settings**
  - App preferences
  - **Sync Dashboard** (CRITICAL)
    - **Sync Status Overview**
      - Last sync: timestamp and direction (↓ Desktop→Remote or ↑ Remote→Desktop)
      - Next scheduled sync: Auto-display based on time
      - Sync health indicator (✓ Healthy, ⚠ Warning, ✗ Error)
    - **Sync Schedule Display**
      - Morning sync: 9:00 AM (Desktop → Supabase)
      - Evening sync: 6:00 PM (Supabase → Desktop)
    - **Sync Logs** (_sync_metadata + _sync_log)
      - Recent sync operations (last 30 days)
      - Per-table sync status
      - Records synced count
      - Error messages (if any)
      - Filter by: table, date, status
    - **Sync Alerts**
      - Show warning if last sync > 24 hours
      - Show error if sync failed
      - Push notification on sync errors
    - **Data Freshness Indicator**
      - Show how old the data is
      - Warning if data > 12 hours old
  - Language
  - About

### 9. Reports (Dashboard style)
- **Performance Dashboard**
  - Hours logged
  - Tasks completed
  - Jobs delivered

- **Client Reports**
  - Revenue per client
  - Active vs completed jobs

## Navigation Structure

```
┌─────────────────────────────────────┐
│         Bottom Navigation           │
├─────────┬─────────┬─────────┬───────┤
│  Home   │  Jobs   │  Diary  │  More │
└─────────┴─────────┴─────────┴───────┘

Home:
  ├── Dashboard
  ├── Quick Actions
  ├── Activity Feed
  └── Sync Status

Jobs:
  ├── Active Jobs
  ├── Completed Jobs
  ├── Job Details
  │   ├── Tasks
  │   ├── Checklist
  │   └── Time Logs
  └── Create Job

Diary:
  ├── Today's Entries
  ├── Calendar View
  ├── Log Time
  └── Reports

More:
  ├── Clients
  ├── Reminders
  ├── Team
  ├── Leave
  ├── Profile
  └── Settings
      └── Sync Dashboard
```

## Screen Flow Examples

### Flow 1: Logging Work Time
1. Dashboard → Quick Action: "Log Time"
2. Select Job (from active jobs)
3. Select Task (from job tasks)
4. Set Time Range (from/to)
5. Add Notes
6. Submit → Success Message

### Flow 2: Managing a Job
1. Jobs Tab → Job List
2. Select Job → Job Details
3. View Tasks with hours (estimated vs actual)
4. Click Task → View Checklist
5. Mark items complete
6. Add comments/documents
7. Update task status

### Flow 3: Creating Reminder
1. Dashboard/Reminders
2. Create New Reminder
3. Select Client (optional)
4. Set Date/Time
5. Assign Staff Members
6. Set Reminder Type
7. Save → Notification scheduled

### Flow 4: Creating a Job
1. Jobs Tab → Create New Job
2. Select Organization (if multi-org)
3. Select Client
4. Enter job details
5. Select Location (branch/office)
6. Save → Job created

## Data Sync Strategy - CRITICAL COMPONENT

### Bi-Directional Sync Architecture

#### Morning Sync (9:00 AM): Desktop → Supabase
**Purpose**: Push latest desktop data to cloud (source of truth)

- **Method**: JavaScript ETL script via Node.js cron job
- **Trigger**: Automated at 9:00 AM when desktop database opens
- **Direction**: PostgreSQL (Desktop) → Supabase (Cloud)
- **Process**:
  1. Connect to local PostgreSQL database
  2. Query changed records since last sync (using updated_at timestamps)
  3. Transform data (handle column mappings, type conversions)
  4. Batch upsert to Supabase via REST API
  5. Update _sync_metadata with timestamp, record count, status
  6. Log all operations to _sync_log table
  7. Send notification if errors occur

- **Tables Synced** (in order):
  - **Master data**: orgmaster, locmaster, conmaster, climaster, cliunimaster, mbstaff, taskmaster, jobmaster
  - **Transactional**: jobshead, jobtasks, taskchecklist, workdiary, reminder, remdetail, learequest

#### Evening Sync (6:00 PM): Supabase → Desktop
**Purpose**: Pull mobile-created data back to desktop

- **Method**: JavaScript ETL script via Node.js cron job
- **Trigger**: Automated at 6:00 PM end of business day
- **Direction**: Supabase (Cloud) → PostgreSQL (Desktop)
- **Process**:
  1. Connect to Supabase via API
  2. Query records with source='M' (mobile-created) since last sync
  3. Transform data for desktop schema compatibility
  4. Insert/Update into local PostgreSQL
  5. Mark synced records with source='S' (synced)
  6. Update _sync_metadata
  7. Log all operations
  8. Send notification summary

- **Tables Synced**:
  - **Mobile-created data**: workdiary (source='M'), taskchecklist updates, reminder responses
  - **Note**: Master data is NOT synced back (desktop is source of truth)

### Mobile → Supabase Sync (Real-time)
- **Method**: Direct API calls via Supabase client
- **Direction**: Immediate (as user makes changes)
- **Operations**:
  - INSERT: New work diary entries, task updates, reminder responses
  - UPDATE: Task status, checklist completion
  - All marked with source='M'
- **Real-time Updates**: Supabase Realtime for live notifications to other users

### Sync Monitoring & Error Handling (CRITICAL)

#### Sync Metadata Tracking
```sql
_sync_metadata table tracks:
- table_name: Which table was synced
- last_sync_timestamp: When sync completed
- sync_direction: 'D→S' or 'S→D'
- sync_status: 'success', 'partial', 'failed'
- records_synced: Count of records
- error_message: Detailed error if failed
- updated_at: Timestamp
```

#### Error Handling Strategy

1. **Pre-Sync Validation**
   - Check database connectivity (both local and Supabase)
   - Verify credentials and permissions
   - Check disk space and memory
   - Validate last sync status (don't sync if previous failed)

2. **During Sync Error Handling**
   - Transaction-based sync per table (rollback on error)
   - Retry mechanism: 3 attempts with exponential backoff
   - Detailed logging of each operation
   - Continue to next table if one fails (don't halt entire sync)
   - Track partial success (how many records succeeded)

3. **Post-Sync Validation**
   - Verify record counts match (source vs destination)
   - Checksum validation for critical tables
   - Data integrity checks (foreign key violations)
   - Compare before/after snapshots

4. **Error Notification System**
   - **Email alerts** to admin on sync failure
   - **Push notification** to mobile app (sync status badge)
   - **Desktop notification** on sync completion/failure
   - **Slack/webhook** integration for critical errors

5. **Data Integrity Protection**
   - **Conflict detection**: Check for concurrent modifications
   - **Duplicate prevention**: Use upsert with unique constraints
   - **Orphan record handling**: Ensure foreign keys exist before insert
   - **Data validation**: Type checking, range validation
   - **Backup before sync**: Create snapshot of both databases

6. **Recovery Mechanisms**
   - **Auto-recovery**: Retry failed sync after 30 minutes
   - **Manual sync trigger**: Admin can force sync from dashboard
   - **Rollback capability**: Restore from pre-sync backup
   - **Sync queue**: Failed records queued for next sync

#### Sync Dashboard Metrics (Mobile & Desktop)

**Display on mobile app:**
- Last successful sync timestamp
- Sync health status (✓ green, ⚠ yellow, ✗ red)
- Data freshness indicator (how old is data)
- Recent sync logs (last 7 days)
- Error messages and resolution steps

**Alerts:**
- Warning if no sync in 24 hours
- Critical alert if sync failed 2+ times
- Data staleness warning (>12 hours old)

### Conflict Resolution Rules

1. **Master Data**: Desktop always wins (source of truth)
2. **Mobile-created Records**: Never overwritten by desktop sync
3. **Concurrent Modifications**: Last write wins + notification to admin
4. **Deleted Records**: Soft delete (set status=0) instead of hard delete

### Offline Capability (Phase 2)
- Cache job details locally (Hive database)
- Queue work diary entries when offline
- Auto-sync when connection restored
- Conflict detection and resolution UI

## Key Features for Mobile
1. **Push Notifications** - Reminders, sync status, job updates
2. **Sync Monitoring** - Real-time sync status, error alerts, data freshness
3. **Quick Actions** - Home screen widgets
4. **Biometric Auth** - Fingerprint/Face ID
5. **Offline Mode** - View cached data, queue updates (Phase 2)
6. **Document Management** - Camera capture, file upload, preview (Phase 2)
7. **Voice Notes** - For work diary entries (Future)
8. **Geolocation** - Track work location (Future)

## API Requirements
All operations will need REST/GraphQL APIs via Supabase:
- **Authentication** (Login, Logout, Token Refresh)
- **CRUD operations** for all entities
- **Sync API endpoints**
  - Query sync metadata
  - Get sync logs with filtering
- **Reports generation**
- **Real-time subscriptions** (Supabase Realtime)
- **Row Level Security** (RLS) policies for data access

## Database Tables Reference

### Master Tables (Full sync daily)
- `orgmaster` - Organizations
- `locmaster` - Office locations
- `conmaster` - Contacts
- `climaster` - Clients
- `cliunimaster` - Client units/branches
- `taskmaster` - Task templates (empty, future use)
- `jobmaster` - Job templates (empty, future use)
- `mbstaff` - Staff members

### Transactional Tables (Incremental sync)
- `jobshead` - Job headers with assignment tracking
- `jobtasks` - Job tasks
- `taskchecklist` - Task checklists
- `workdiary` - Time tracking entries
- `reminder` - Reminders
- `remdetail` - Reminder details/responses
- `learequest` - Leave requests

### System Tables
- `_sync_metadata` - Tracks last sync status per table with direction
- `_sync_log` - Detailed sync operation log with error tracking

## Technical Debt & Future Enhancements

### Known Technical Debt:
1. **Designation Master Table** ⚠️
   - **Issue**: mbstaff.desc_id exists but no descmaster table
   - **Impact**: Cannot filter staff by designation, cannot display designation names
   - **Workaround**: Show desc_id as number, or hide designation filter
   - **Resolution**: Create descmaster table in Phase 2 via desktop, sync to mobile
   - **Priority**: Medium

2. **Task/Job Templates** ⚠️
   - **Issue**: taskmaster and jobmaster tables exist but empty
   - **Impact**: No template functionality available
   - **Resolution**: Populate templates in future phase via desktop
   - **Priority**: Low

3. **Sync Frequency Limitations** ⚠️
   - **Issue**: Twice-daily sync means data can be up to 12 hours stale
   - **Impact**: Not suitable for real-time collaboration
   - **Workaround**: Mobile writes directly to Supabase (real-time), desktop syncs periodically
   - **Resolution**: Increase sync frequency or implement real-time replication
   - **Priority**: Low (acceptable for MVP)

### Future Enhancements (Phase 2+):

**Document Management System** (High Priority - Phase 2)
- Document attachment table and Supabase Storage integration
- Camera capture for receipts and site photos
- File picker for document upload
- PDF and image viewer
- Link documents to jobs, tasks, work diary, clients
- Document search and filtering
- Offline document caching

**Other Enhancements:**
- Client portal (view job status, upload documents)
- Advanced analytics dashboard
- Integration with accounting software
- Enhanced document OCR and auto-categorization
- Automated compliance reminders
- AI-powered task estimation
- Voice notes for work diary
- Geolocation tracking for site visits

---

**Document Version**: 3.0
**Last Updated**: 2025-10-30
**Status**: Ready for Development
**Schema Alignment**: ✅ Verified against Supabase schema

**Changes in v3.0:**
- ✅ Removed job assignment tracking (desktop-only feature)
- ✅ Removed master data management features (handled via reverse sync from desktop)
- ✅ Enhanced bi-directional sync strategy with detailed error handling
- ✅ Added sync monitoring dashboard with health metrics
- ✅ Clarified sync schedule: Morning (Desktop→Supabase), Evening (Supabase→Desktop)
- ✅ Moved document management to Phase 2 (not in MVP)
