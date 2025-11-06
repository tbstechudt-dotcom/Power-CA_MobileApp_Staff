# PowerCA Mobile - Bidirectional Sync Strategy

**Document Version**: 1.0
**Last Updated**: 2025-10-28
**Status**: Implementation Ready

---

## Overview

This document explains how data flows in both directions between Desktop Power CA and Mobile App, ensuring changes made on mobile devices are synced back to the desktop PostgreSQL database.

---

## The Challenge

**Your Question:**
> "How will we sync the mobile data with newly added task details to the desktop / local postgres database?"

**Context:**
- Desktop creates jobs, tasks, clients in local PostgreSQL
- Mobile users log time, update tasks, add notes, create reminders
- Desktop needs to see these mobile changes
- Both systems need to stay in sync

---

## Bidirectional Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Complete Data Flow                           │
└─────────────────────────────────────────────────────────────────┘

Desktop PostgreSQL                 Supabase Cloud              Mobile App
  (Source of Truth                  (Central Hub)              (Field Users)
   for Master Data)
        │                                  │                         │
        │   1. Forward Sync (Daily)        │                         │
        │───────────────────────────────→  │                         │
        │   Master data + Transactions     │                         │
        │   (Daily 6:00 PM)                │                         │
        │                                  │                         │
        │                                  │  2. Mobile Usage       │
        │                                  │ ←─────────────────────  │
        │                                  │   (Real-time API)       │
        │                                  │   - Log work time       │
        │                                  │   - Update tasks        │
        │                                  │   - Add notes           │
        │                                  │                         │
        │   3. Reverse Sync (After forward)│                         │
        │ ←─────────────────────────────── │                         │
        │   Mobile-generated data          │                         │
        │   (source='M' records)           │                         │
        │                                  │                         │
```

---

## Two Implementation Approaches

### Approach 1: Hybrid Architecture (Recommended for MVP)

**Concept:** Desktop app also connects to Supabase to read mobile data

**Architecture:**
```
┌──────────────────────────┐         ┌──────────────────────────┐
│   Desktop Application    │         │   Mobile Application     │
│                          │         │                          │
│  ┌────────────────────┐  │         │  ┌────────────────────┐  │
│  │ Local PostgreSQL   │  │         │  │ Supabase Client    │  │
│  │ - Master data      │  │         │  │ - Real-time API    │  │
│  │ - Legacy records   │  │         │  │                    │  │
│  └────────────────────┘  │         │  └────────────────────┘  │
│           ↕              │         │           ↕              │
│  ┌────────────────────┐  │         │           ↕              │
│  │ Supabase Client    │  │         │           ↕              │
│  │ - Read mobile data │  │         │           ↕              │
│  │ - Write new records│  │         │           ↕              │
│  └────────────────────┘  │         │           ↕              │
└───────────┬──────────────┘         └───────────┬──────────────┘
            │                                    │
            │            ┌──────────────────────┐│
            └───────────→│   Supabase Cloud     │←
                         │   (Central Database) │
                         └──────────────────────┘
```

**Data Storage Strategy:**

| Data Type | Stored In | Access Pattern |
|-----------|-----------|----------------|
| **Master Data** (clients, jobs, staff) | Local PostgreSQL → Synced daily to Supabase | Desktop reads local, Mobile reads Supabase |
| **Desktop-Created Transactions** | Local PostgreSQL → Synced daily to Supabase (source='D') | Desktop reads local, Mobile reads Supabase |
| **Mobile-Created Transactions** | Supabase only (source='M') | Desktop reads from Supabase, Mobile reads from Supabase |

**Key Advantage:** No reverse sync needed! Desktop just reads both sources.

---

### Approach 2: Full Bidirectional Sync (Data Sovereignty)

**Concept:** ALL data must exist in local PostgreSQL (what you asked about)

**Architecture:**
```
Desktop PostgreSQL          Supabase Cloud         Mobile App
       ↑                          ↑                    ↓
       │   Forward Sync (Daily)   │   Real-time        │
       │   Desktop → Supabase     │   Mobile → Cloud   │
       │                          │                    │
       └─────←  Reverse Sync  ←───┘
          (Supabase → Desktop)
           Daily after forward sync
```

**Implementation:** Use the reverse sync script I just created!

---

## Approach 2 Implementation (Reverse Sync)

### What Gets Synced Back to Desktop?

**Mobile-Created Records (source='M'):**
1. **Work Diary Entries** - Time logged by mobile users
   - Table: `workdiary`
   - Desktop table: `workdiary`
   - Sync frequency: Daily

2. **Task Checklist Updates** - Checklist items marked complete
   - Table: `taskchecklist`
   - Desktop table: `taskchecklist`
   - Sync frequency: Daily

3. **Reminders** - Reminders created on mobile
   - Table: `reminder` (mobile) → `mbreminder` (desktop)
   - Sync frequency: Daily

4. **Reminder Details** - Reminder responses
   - Table: `remdetail` (mobile) → `mbremdetail` (desktop)
   - Sync frequency: Daily

5. **Leave Requests** - Leave applications from mobile
   - Table: `learequest`
   - Desktop table: `learequest`
   - Sync frequency: Daily

---

### How Reverse Sync Works

**Step-by-Step Process:**

**1. Identification of Mobile Records**
```sql
-- Only sync records created/updated on mobile
SELECT * FROM workdiary
WHERE source = 'M'  -- Mobile-generated
AND updated_at > NOW() - INTERVAL '7 days'  -- Recent changes only
```

**2. Table Name Mapping**
```javascript
// Convert mobile table names back to desktop names
const reverseMapping = {
  'reminder': 'mbreminder',    // Mobile → Desktop
  'remdetail': 'mbremdetail'
};
```

**3. Data Transformation**
```javascript
// Remove Supabase-specific columns
delete record.created_at;  // Not in desktop schema
delete record.updated_at;  // Not in desktop schema
delete record.source;      // Not in desktop schema
```

**4. Upsert to Desktop**
```sql
-- Check if record exists
SELECT 1 FROM workdiary WHERE wd_id = 12345;

-- If exists: UPDATE
UPDATE workdiary
SET fromtime = '09:00', totime = '17:00', ...
WHERE wd_id = 12345;

-- If not exists: INSERT
INSERT INTO workdiary (wd_id, job_id, task_id, ...)
VALUES (12345, 1001, 501, ...);
```

---

### Running Reverse Sync

**Command:**
```bash
# Sync mobile data back to desktop
npm run sync:reverse
```

**Full Bidirectional Sync:**
```bash
# Run both directions in sequence
npm run sync:bidirectional
```

This runs:
1. Desktop → Supabase (incremental)
2. Supabase → Desktop (mobile records only)

---

## Sync Schedule Design

### Recommended Schedule:

**Daily at 6:00 PM** (End of business day):
```
1. Forward Sync (Desktop → Supabase)
   Duration: 50-60 minutes
   ├─ Syncs all desktop changes to cloud
   └─ Mobile users see updated data

2. Reverse Sync (Supabase → Desktop)
   Duration: 1-2 minutes
   ├─ Syncs mobile-generated records back
   └─ Desktop sees work logged today
```

**Windows Task Scheduler Setup:**
```xml
Task: PowerCA Bidirectional Sync
Trigger: Daily at 6:00 PM
Action: npm run sync:bidirectional
Working Directory: d:\PowerCA Mobile
```

---

## Data Flow Examples

### Example 1: Mobile User Logs Work Time

**Scenario:** Staff member logs 4 hours of work on mobile app

```
Time: 3:00 PM (During work day)

Step 1: Mobile user fills work diary entry
   ├─ Job: "Tax Filing - ABC Corp"
   ├─ Task: "Prepare ITR Forms"
   ├─ Time: 9:00 AM - 1:00 PM (4 hours)
   └─ Notes: "Completed all deduction calculations"

Step 2: Mobile app saves to Supabase (IMMEDIATE)
   ├─ INSERT INTO workdiary
   ├─ source = 'M' (Mobile-generated)
   ├─ staff_id = 1001
   └─ ✓ Saved to Supabase Cloud

Step 3: Desktop sees the change (TWO OPTIONS)

   Option A (Hybrid): Desktop queries Supabase directly
   ├─ SELECT * FROM workdiary WHERE source='M'
   └─ ✓ Shows in desktop app immediately

   Option B (Full Sync): Desktop gets it after evening sync
   ├─ 6:00 PM: Reverse sync runs
   ├─ Pulls record from Supabase
   ├─ INSERT INTO local workdiary table
   └─ ✓ Shows in desktop app next morning
```

---

### Example 2: Desktop Creates New Job

**Scenario:** Office admin creates new job on desktop

```
Time: 10:00 AM

Step 1: Desktop user creates new job
   ├─ Client: "XYZ Pvt Ltd"
   ├─ Job: "GST Return Filing"
   ├─ Due Date: November 20
   └─ Assigned To: Staff member using mobile

Step 2: Saved to desktop PostgreSQL (IMMEDIATE)
   ├─ INSERT INTO jobshead
   ├─ source = 'D' (Desktop-generated)
   └─ ✓ Saved locally

Step 3: Mobile user sees the change
   ├─ 6:00 PM: Forward sync runs
   ├─ Desktop → Supabase sync
   ├─ INSERT INTO jobshead (in Supabase)
   └─ ✓ Mobile app shows new job next day
```

---

### Example 3: Task Update from Mobile

**Scenario:** Mobile user marks task as complete

```
Time: 4:00 PM

Step 1: Mobile user marks task complete
   ├─ Job: "Audit - DEF Corp"
   ├─ Task: "Review bank reconciliation"
   └─ Status: Completed ✓

Step 2: Supabase updated (IMMEDIATE)
   ├─ UPDATE jobtasks
   ├─ SET task_status = 'completed'
   ├─ WHERE task_id = 5001
   └─ ✓ Saved to cloud

Step 3: Desktop sees the update
   ├─ 6:00 PM: Reverse sync runs
   ├─ UPDATE jobtasks in local PostgreSQL
   └─ ✓ Desktop shows task completed
```

---

## Conflict Resolution

### What if Desktop and Mobile both modify same record?

**Scenario:** Desktop updates job details, mobile user logs time on same job

**Resolution Strategy:**

1. **Master Data Updates** (clients, jobs, staff)
   - **Desktop wins** - Desktop is source of truth
   - Mobile changes to master data require desktop approval
   - Daily forward sync overwrites any mobile master data changes

2. **Transactional Data** (time entries, task updates)
   - **Last write wins** based on `updated_at` timestamp
   - Conflicts are rare (different users work on different records)

3. **Additive Data** (work diary, reminders)
   - **No conflicts** - These are always new records
   - Mobile creates record with source='M'
   - Desktop creates record with source='D'
   - Both coexist peacefully

**Example:**
```sql
-- Desktop job: Updated at 2:00 PM, target date changed
UPDATE jobshead
SET target_date = '2025-11-15'
WHERE job_id = 1001;
-- source='D', updated_at='2025-10-28 14:00:00'

-- Mobile: Work logged at 3:00 PM
INSERT INTO workdiary
VALUES (wd_id, 1001, task_id, ...);
-- source='M', created_at='2025-10-28 15:00:00'

-- Result after sync:
-- ✓ Job has new target date (from desktop)
-- ✓ Work diary entry exists (from mobile)
-- ✓ No conflict!
```

---

## Source Tracking

### Why the `source` Column Matters

Every record tracks its origin:

```sql
-- Source column values
source = 'D'  -- Created on Desktop
source = 'M'  -- Created on Mobile
source = 'S'  -- Synced (could be either, now in sync)
```

**Usage:**

1. **Reverse Sync Filter:**
   ```sql
   -- Only sync mobile records back
   SELECT * FROM workdiary WHERE source = 'M'
   ```

2. **Audit Trail:**
   ```sql
   -- See where data came from
   SELECT job_id, task_desc, source
   FROM jobtasks
   WHERE source = 'M'  -- Mobile-created tasks
   ```

3. **Conflict Detection:**
   ```sql
   -- Find records modified on both sides
   SELECT * FROM workdiary
   WHERE source = 'M'
   AND wd_id IN (SELECT wd_id FROM local_workdiary WHERE updated_at > last_sync)
   ```

---

## Performance Considerations

### Reverse Sync is Fast!

**Why?**
- Only syncs records with `source='M'`
- Typically just today's work diary entries
- Much smaller dataset than forward sync

**Estimated Volume:**
```
16 staff members × 5 work diary entries/day = 80 records/day
+ 10 task updates
+ 2-3 reminders
= ~100 records total

Sync time: 1-2 minutes (vs 50-60 min for forward sync)
```

---

## Recommended Approach for Your Project

### Phase 1 (MVP - Current): Hybrid Architecture

**Why:**
- ✅ Simplest to implement
- ✅ No reverse sync needed initially
- ✅ Desktop can query Supabase directly
- ✅ Real-time visibility

**Implementation:**
1. Keep current forward sync (Desktop → Supabase)
2. Update desktop app to connect to Supabase
3. Desktop shows combined view:
   - Local data from PostgreSQL
   - Mobile data from Supabase (where source='M')

**Desktop Application Changes:**
```javascript
// In desktop app
const localData = await localDb.query('SELECT * FROM workdiary WHERE source=\'D\'');
const mobileData = await supabase.from('workdiary').select('*').eq('source', 'M');

const combinedData = [...localData, ...mobileData];
// Show in UI
```

---

### Phase 2 (Post-MVP): Full Bidirectional Sync

**When to implement:**
- Desktop application requires all data in local PostgreSQL
- Compliance/audit requirements for local storage
- Offline desktop operation needed

**Implementation:**
1. Continue forward sync (Desktop → Supabase)
2. Add reverse sync (Supabase → Desktop)
3. Schedule both in sequence

**Already Ready!**
- ✅ Reverse sync script created
- ✅ npm commands configured
- ✅ Just needs Windows Task Scheduler setup

---

## Summary

### Quick Answer to Your Question:

**Q: "How will we sync mobile data back to desktop?"**

**A:** Two ways:

**Option 1 (Recommended for MVP):**
Desktop application connects to Supabase and reads mobile data directly. No reverse sync needed!

**Option 2 (Full Control):**
Use the reverse sync script I created:
```bash
npm run sync:reverse
```
This pulls all mobile-generated records (source='M') from Supabase back to desktop PostgreSQL.

---

### Files Created:

1. **[sync/reverse-sync-engine.js](d:\PowerCA Mobile\sync\reverse-sync-engine.js)** - Reverse sync logic
2. **[sync/reverse-sync-runner.js](d:\PowerCA Mobile\sync\reverse-sync-runner.js)** - Command-line runner
3. **[package.json](d:\PowerCA Mobile\package.json)** - Updated with new commands:
   - `npm run sync:reverse` - Supabase → Desktop
   - `npm run sync:bidirectional` - Both directions

---

### Next Steps:

**To enable reverse sync:**

1. **Test reverse sync** (after forward sync completes):
   ```bash
   npm run sync:reverse
   ```

2. **Schedule bidirectional sync:**
   - Windows Task Scheduler
   - Daily at 6:00 PM
   - Command: `npm run sync:bidirectional`

3. **Monitor sync logs:**
   - Check `_sync_metadata` table
   - Review console output
   - Check desktop database for mobile records

---

**Document Version**: 1.0
**Status**: Implementation Ready
**Reverse Sync**: ✅ Code Complete
**Testing**: ⏳ Pending (after forward sync completes)

