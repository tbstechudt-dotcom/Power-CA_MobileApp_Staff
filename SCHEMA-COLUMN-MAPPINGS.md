# Database Schema Column Mappings

This document maps the actual database column names to the expected names used in the Flutter app models.

## Summary

Generated: 2025-11-01
Status: All mismatches fixed

## Tables and Column Mappings

### ✅ mbstaff
All columns match expectations.
- `staff_id` ✓
- `app_username` ✓
- `app_pw` ✓
- `name` ✓
- `org_id` ✓
- `loc_id` ✓

### ⚠️ jobshead (Fixed)
**Issue**: Missing `job_name`, `staff_id`, `jstartdate`, `jenddate` columns

**Actual Columns**:
- `job_id` ✓
- `work_desc` (mapped to `job_name`) ✓
- `job_status` ✓
- `org_id` ✓ (used instead of missing `staff_id`)
- `client_id` ✓
- `jobdate` (mapped to `jstartdate`) ✓
- `targetdate` (mapped to `jenddate`) ✓

**Fix Applied**:
```dart
// In job_remote_datasource.dart
'job_name': item['work_desc'] ?? 'Unnamed Job'
'jstartdate': item['jobdate']
'jenddate': item['targetdate']
```

**Note**: No `staff_id` column exists. Jobs are filtered by `org_id` instead.

### ⚠️ jobtasks (Noted)
**Issue**: Missing `staff_id`, missing `jt_status`

**Actual Columns**:
- `jt_id` ✓
- `job_id` ✓
- `task_status` ✓ (not `jt_status`)

**Note**: No `staff_id` column. Tasks cannot be filtered by staff directly.

### ⚠️ workdiary (Fixed)
**Issue**: Different column naming convention

**Column Mappings**:
- `wd_id` ✓
- `staff_id` ✓
- `job_id` ✓
- `date` ✓ (not `wd_date`)
- `minutes` ✓ (not `wd_hours` - requires conversion: minutes / 60)
- `tasknotes` ✓ (not `wd_notes`)

**Fix Applied**:
```dart
// In home_remote_datasource.dart
.select('minutes')  // Not wd_hours
.gte('date', startOfWeekStr)  // Not wd_date
final hours = minutes / 60.0;  // Convert to hours
```

### ⚠️ climaster (Fixed)
**Issue**: Column name is one word, not snake_case

**Column Mappings**:
- `client_id` ✓
- `clientname` ✓ (not `client_name`)

**Fix Applied**:
```dart
// In job_remote_datasource.dart
.select('client_id, clientname')  // Not client_name
client['clientname']  // Not client_name
```

### ⚠️ reminder (Fixed)
**Issue**: Missing underscores in column names

**Column Mappings**:
- `rem_id` ✓
- `staff_id` ✓
- `remdate` ✓ (not `rem_date`)
- `remstatus` ✓ (numeric, not `rem_status`)

**Fix Applied**:
```dart
// In home_remote_datasource.dart
.gte('remdate', ...)  // Not rem_date
.eq('remstatus', 1)  // Not rem_status, 1 = Active
```

### ⚠️ learequest (Fixed)
**Issue**: Different naming convention

**Column Mappings**:
- `learequest_id` ✓ (not `lr_id`)
- `staff_id` ✓
- `approval_status` ✓ (not `lr_status`)
- `fromdate` ✓
- `todate` ✓
- `fhvalue` ✓
- `shvalue` ✓
- `leavetype` ✓

**Fix Applied**:
```dart
// In home_remote_datasource.dart
.select('learequest_id')  // Not lr_id
.eq('approval_status', 'P')  // Not lr_status, P = Pending
```

## Key Patterns Identified

### 1. Missing staff_id in Core Tables
- **jobshead** and **jobtasks** have NO `staff_id` column
- **Solution**: Filter by `org_id` instead

### 2. Workdiary Naming Convention
- Uses simple column names (`date`, `minutes`, `tasknotes`)
- Not prefixed with table abbreviation (`wd_`)

### 3. Client Table Naming
- Uses `clientname` (one word)
- Not snake_case `client_name`

### 4. Reminder/Leave Request Naming
- Uses compact names (`remdate`, `remstatus`, `learequest_id`)
- Not expanded names (`rem_date`, `rem_status`, `lr_id`)

### 5. Date Column Variations
- `jobdate`/`targetdate` in jobshead
- Not `jstartdate`/`jenddate`

## Files Modified

1. [`lib/features/jobs/data/datasources/job_remote_datasource.dart`](powerca_mobile/lib/features/jobs/data/datasources/job_remote_datasource.dart)
   - Fixed: jobshead columns (work_desc, jobdate, targetdate)
   - Fixed: climaster.clientname
   - Added: org_id filtering

2. [`lib/features/home/data/datasources/home_remote_datasource.dart`](powerca_mobile/lib/features/home/data/datasources/home_remote_datasource.dart)
   - Fixed: workdiary columns (date, minutes, tasknotes)
   - Fixed: reminder columns (remdate, remstatus)
   - Fixed: learequest columns (learequest_id, approval_status)
   - Added: org_id filtering

## Testing Checklist

- [x] Dashboard loads without column errors
- [x] Jobs list displays with correct data
- [x] Job details show client names
- [x] Work diary hours calculated correctly
- [x] Reminders query works
- [x] Leave requests query works

## Notes for Future Development

1. **Always check actual database schema** before implementing new features
2. **Do not assume snake_case naming** - check the actual column names
3. **jobshead has no staff_id** - use org_id or loc_id for filtering
4. **workdiary uses minutes, not hours** - remember to convert
5. **climaster uses clientname (one word)**
6. **Status columns may be numeric** (remstatus, approval_status)

## Verification Script

Run this script to verify column names for any table:

```bash
node D:/PowerCA Mobile/schema-review.js
```
