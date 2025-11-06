# Power CA Database Schema Analysis

## Overview
This document analyzes the differences between the Desktop (local PostgreSQL) and Mobile (Supabase) schemas to create an effective sync strategy.

---

## Schema Comparison

### Tables in Both Systems

| Desktop Table | Mobile Table | Sync Direction | Notes |
|--------------|--------------|----------------|-------|
| `mbstaff` | `mbstaff` | Desktop → Mobile | Staff/user information |
| `jobshead` | `jobshead` | Desktop → Mobile | Job header information |
| `jobtasks` | `jobtasks` | Desktop → Mobile | Job tasks |
| `taskchecklist` | `taskchecklist` | Desktop → Mobile | Task checklists |
| `workdiary` | `workdiary` | Desktop → Mobile | Work diary entries |
| `taskmaster` | `taskmaster` | Desktop → Mobile | Task master data |
| `climaster` | `climaster` | Desktop → Mobile | Client master |
| `locmaster` | `locmaster` | Desktop → Mobile | Location master |
| `conmaster` | `conmaster` | Desktop → Mobile | Consultant master |
| `cliunimaster` | `cliunimaster` | Desktop → Mobile | Client unit master |
| `mbreminder` | `reminder` | Desktop → Mobile | ⚠️ Name change |
| `mbremdetail` | `remdetail` | Desktop → Mobile | ⚠️ Name change |
| `learequest` | `learequest` | Desktop → Mobile | Leave requests |
| `orgmaster` | `orgmaster` | Desktop → Mobile | Organization master |
| `jobmaster` | `jobmaster` | Desktop → Mobile | Job master |

---

## Key Differences

### 1. Primary Keys & Constraints
- **Desktop**: Most tables lack PRIMARY KEY definitions
- **Mobile**: Proper PRIMARY KEY and FOREIGN KEY constraints
- **Impact**: Mobile has referential integrity, desktop doesn't

### 2. Table Name Changes
| Desktop | Mobile | Reason |
|---------|--------|--------|
| `mbreminder` | `reminder` | Simplified naming |
| `mbremdetail` | `remdetail` | Simplified naming |

### 3. Column Differences

#### `jobshead` Table
**Desktop has additional columns:**
- `job_uid` VARCHAR(25) - Unique job identifier
- `sporg_id` NUMERIC(8) - Special organization ID
- `jctincharge` CHAR(1) - Job charge indicator

**Mobile doesn't have these columns** - will need to handle in sync.

#### `jobtasks` Table
**Desktop has:**
- `jt_id` NUMERIC(10) - Primary identifier
**Mobile doesn't have this** - uses composite key of (job_id, task_id, client_id)

#### `taskchecklist` Table
**Desktop has:**
- `tc_id` NUMERIC(10) - Primary identifier
**Mobile has additional columns:**
- `con_id` - Consultant ID
- `year_id` - Year ID

#### `workdiary` Table
**Desktop:**
- `wd_id` NUMERIC(10) - Just a column
**Mobile:**
- `wd_id` NUMERIC(8) PRIMARY KEY - Actual primary key
- Missing: `client_id`, `cma_id` columns that mobile has

### 4. Source Column
- **All tables have `source CHAR(1)` column**
- Purpose: Track data origin
  - 'D' = Desktop
  - 'M' = Mobile
  - 'S' = Synced

---

## Sync Strategy

### Phase 1: Master Data (One-time)
Sync reference/master tables first:
1. `orgmaster`
2. `conmaster`
3. `locmaster`
4. `climaster`
5. `cliunimaster`
6. `taskmaster`
7. `jobmaster`

### Phase 2: Staff Data
8. `mbstaff`

### Phase 3: Transactional Data (Daily)
9. `jobshead`
10. `jobtasks`
11. `taskchecklist`
12. `workdiary`
13. `mbreminder` → `reminder`
14. `mbremdetail` → `remdetail`
15. `learequest`

---

## Data Transformation Rules

### 1. Table Name Mapping
```javascript
const tableMapping = {
  'mbreminder': 'reminder',
  'mbremdetail': 'remdetail',
  // All others: same name
};
```

### 2. Column Mapping for `jobshead`
```javascript
// Desktop → Mobile
{
  // Standard columns: direct copy
  org_id: org_id,
  con_id: con_id,
  loc_id: loc_id,
  job_id: job_id,
  year_id: year_id,
  client_id: client_id,
  jobdate: jobdate,
  targetdate: targetdate,
  job_nature: job_nature,
  work_desc: work_desc,
  worklocation: worklocation,
  act_man_min: act_man_min,
  drivefolderpath: drivefolderpath,
  drivefolderkey: drivefolderkey,
  job_status: job_status,
  source: source,

  // Desktop-only columns (skip these):
  // job_uid: ignored
  // sporg_id: ignored
  // jctincharge: ignored
}
```

### 3. Column Mapping for `jobtasks`
```javascript
// Desktop → Mobile
{
  // Skip jt_id (desktop only)
  org_id: org_id,
  con_id: con_id,
  loc_id: loc_id,
  job_id: job_id,
  year_id: year_id,
  task_id: task_id,
  taskorder: taskorder,
  task_desc: task_desc,
  jobdet_man_hrs: jobdet_man_hrs,
  actual_man_hrs: actual_man_hrs,
  actual_man_min: actual_man_min,
  checklistlinked: checklistlinked,
  source: source,

  // Mobile requires client_id - need to get from jobshead
  client_id: (lookup from jobshead)
}
```

### 4. Column Mapping for `taskchecklist`
```javascript
// Desktop → Mobile
{
  // Skip tc_id (desktop only)
  org_id: org_id,
  loc_id: loc_id,
  task_id: task_id,
  checklistdesc: checklistdesc,
  applicable: applicable,
  formatdoc: formatdoc,
  completedby: completedby,
  completeddate: completeddate,
  comments: comments,
  checkliststatus: checkliststatus,
  source: source,

  // Mobile requires these - need to add:
  con_id: (add from context),
  job_id: (add from context),
  year_id: (add from context),
  client_id: (add from context)
}
```

### 5. Column Mapping for `workdiary`
```javascript
// Desktop → Mobile
{
  wd_id: wd_id,
  org_id: org_id,
  con_id: con_id,
  loc_id: loc_id,
  staff_id: staff_id,
  job_id: job_id,
  task_id: task_id,
  date: date,
  timefrom: timefrom,
  timeto: timeto,
  minutes: minutes,
  tasknotes: tasknotes,
  attachment: attachment,
  doc_ref: doc_ref,
  source: source,

  // Mobile requires these - need to lookup:
  client_id: (lookup from jobshead),
  cma_id: (need to determine what this is)
}
```

---

## Sync Approach

### Option 1: Full Sync (Simpler)
- Truncate mobile table
- Copy all desktop data
- Good for: Master tables
- **Pros**: Simple, no conflict resolution
- **Cons**: Loses mobile-only data

### Option 2: Incremental Sync (Recommended)
- Track last_sync_timestamp
- Only sync changed records
- Use `source` column to identify origin
- Good for: Transactional tables
- **Pros**: Preserves mobile data, efficient
- **Cons**: More complex logic

### Option 3: Bi-directional Sync (Future)
- Sync desktop → mobile AND mobile → desktop
- Conflict resolution required
- Good for: Future when mobile creates data
- **Pros**: Full two-way sync
- **Cons**: Complex, needs careful design

---

## Recommended Implementation

### Phase 1: Desktop → Mobile (Current Need)
1. Create all tables in Supabase with proper constraints
2. Implement incremental sync for transactional tables
3. Use full sync for master tables
4. Set `source = 'D'` for desktop data

### Phase 2: Mobile-only Features (Future)
1. Mobile app can create new records with `source = 'M'`
2. Sync script skips `source = 'M'` records
3. Preserves mobile-only data

### Phase 3: Bi-directional (If Needed)
1. Implement conflict resolution
2. Track modification timestamps
3. Sync mobile → desktop as well

---

## Missing Dependencies

### Mobile schema references `staff` table
```sql
-- Referenced in workdiary and reminder
REFERENCES staff(staff_id)
```

**Issue**: `staff` table not defined in mobile schema!

**Solutions:**
1. **Option A**: Use `mbstaff` table instead (rename references)
2. **Option B**: Create `staff` table as alias/view of `mbstaff`
3. **Option C**: Remove foreign key constraints (not recommended)

**Recommendation**: Use `mbstaff` for all staff references.

---

## Data Volume Estimates

Based on typical CA office usage:
- **Staff**: ~10-50 records (low volume)
- **Clients**: ~100-500 records (low volume)
- **Jobs**: ~1000-5000 records/year (medium volume)
- **Tasks**: ~5000-25000 records/year (medium volume)
- **Work Diary**: ~10000-50000 records/year (high volume)
- **Reminders**: ~1000-5000 records/year (medium volume)

**Sync Time Estimates:**
- Master data (one-time): < 1 minute
- Daily incremental: 1-5 minutes
- Full re-sync: 5-15 minutes

---

## Next Steps

1. ✅ Create SQL schema in Supabase (with fixes)
2. ✅ Build sync script with table mapping
3. ✅ Test with sample data
4. ✅ Set up scheduled daily sync
5. ✅ Implement RLS policies
6. ✅ Build Flutter app

---

**Created**: 2025-10-28
**Status**: Analysis Complete
