# PowerCA Mobile - Local to Cloud Data Replication

A comprehensive bidirectional data synchronization system between Desktop PostgreSQL and Supabase Cloud, with a Flutter mobile application for field staff management.

## Project Overview

**PowerCA Mobile** is a complete enterprise solution that enables seamless data replication between a legacy desktop application (PostgreSQL) and a cloud-based mobile platform (Supabase + Flutter). The system allows field staff to access and update job information, work diaries, and leave requests from their mobile devices, with automatic synchronization back to the desktop system.

### Key Features

- **Bidirectional Sync Engine** - Desktop PostgreSQL <-> Supabase Cloud
- **Flutter Mobile App** - Clean Architecture + BLoC pattern
- **Safe Data Replication** - Staging table pattern prevents data loss
- **Incremental Sync** - Only sync changed records for efficiency
- **Automated Scheduling** - Windows Task Scheduler integration
- **Comprehensive Testing** - Validation scripts and test suites
- **Production-Ready** - Battle-tested with 24,000+ job records

---

## Table of Contents

1. [Architecture](#architecture)
2. [Features](#features)
3. [Tech Stack](#tech-stack)
4. [Prerequisites](#prerequisites)
5. [Installation](#installation)
6. [Configuration](#configuration)
7. [Usage](#usage)
8. [Sync Engine](#sync-engine)
9. [Mobile App](#mobile-app)
10. [Troubleshooting](#troubleshooting)
11. [Documentation](#documentation)
12. [Contributing](#contributing)

---

## Architecture

```
Desktop App         Sync Engine          Supabase Cloud
(PostgreSQL)  <-->  (Node.js)     <-->   (PostgreSQL)
Port 5433           Staging Tables       + Auth/Storage
                         ^
                         |
                    Reverse Sync
                    (Mobile->Desktop)
                         ^
                         |
                    Flutter Mobile
                    App (Android/iOS)
```

### Data Flow

1. **Forward Sync (Desktop -> Cloud)**
   - Runs daily/weekly via Windows Task Scheduler
   - Syncs master data (clients, staff, tasks) and transactional data (jobs, work diary)
   - Uses staging tables for safety (transaction rollback on failure)

2. **Mobile Access (Cloud)**
   - Mobile app queries Supabase directly
   - Real-time updates via Supabase Realtime
   - Offline support with local SQLite cache

3. **Reverse Sync (Cloud -> Desktop)**
   - Pulls mobile-created records back to desktop
   - Timestamp-based incremental sync
   - Preserves data source attribution (`source='M'` for mobile)

---

## Features

### Sync Engine

- **Full Sync Mode** - Complete data replication (all records)
- **Incremental Sync Mode** - Only changed records since last sync
- **Staging Tables** - Safe transaction pattern (no data loss on failure)
- **FK Validation** - Pre-validates foreign key relationships
- **Metadata Tracking** - Timestamp-based sync history per table
- **Conflict Resolution** - Source-based conflict handling (`source='D'` vs `source='M'`)
- **Automated Scheduling** - Windows Task Scheduler integration

### Mobile Application

- **Authentication** - Encrypted password login (PowerBuilder-compatible)
- **Dashboard** - Real-time stats (active jobs, hours worked, reminders)
- **Jobs Management** - View, filter, and update job status
- **Work Diary** - Log time entries by job and date
- **Leave Requests** - Submit and track leave applications
- **Offline Support** - Local cache with sync when online

### Safety Features

- **Staging Table Pattern** - Production data never cleared until new data is validated
- **Transaction Rollback** - Automatic rollback on sync failure
- **FK Cache Refresh** - Prevents stale foreign key validation
- **Watermark Tracking** - Race condition prevention in timestamp-based sync
- **Column Validation** - Runtime checks for required columns
- **Graceful Degradation** - Fallback to full sync if timestamps missing

---

## Tech Stack

### Backend Sync Engine
- **Node.js** - Runtime environment
- **PostgreSQL (pg)** - Database driver
- **Supabase** - Cloud PostgreSQL backend
- **dotenv** - Environment configuration

### Mobile Application
- **Flutter** - Cross-platform framework
- **Dart** - Programming language
- **BLoC** - State management
- **Supabase Flutter SDK** - Backend integration
- **GetIt** - Dependency injection
- **Equatable** - Value equality

### Databases
- **Desktop PostgreSQL 16.9** - Legacy system (port 5433)
- **Supabase PostgreSQL 17.6** - Cloud database

---

## Prerequisites

### For Sync Engine

```bash
# Node.js (v14 or higher)
node --version

# PostgreSQL client tools
psql --version

# Git
git --version
```

### For Mobile App

```bash
# Flutter SDK (3.x or higher)
flutter --version

# Android Studio or VS Code with Flutter extensions
```

### System Requirements

- **OS**: Windows (for Task Scheduler automation) or Linux/macOS
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 1GB for sync engine, 2GB for mobile development
- **Network**: Stable internet connection for cloud sync

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/tbstechudt-dotcom/Power-CA_MobileApp_Staff.git
cd Power-CA_MobileApp_Staff
```

### 2. Install Sync Engine Dependencies

```bash
npm install
```

### 3. Configure Environment Variables

Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env`:

```env
# Desktop PostgreSQL
DESKTOP_DB_HOST=localhost
DESKTOP_DB_PORT=5433
DESKTOP_DB_NAME=enterprise_db
DESKTOP_DB_USER=postgres
DESKTOP_DB_PASSWORD=your_desktop_password

# Supabase Cloud
SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_DB_PORT=5432
SUPABASE_DB_NAME=postgres
SUPABASE_DB_USER=postgres
SUPABASE_DB_PASSWORD=your_supabase_password

# Supabase API (for mobile app)
SUPABASE_URL=https://jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
```

### 4. Set Up Flutter Mobile App

```bash
cd powerca_mobile
flutter pub get
flutter run -d chrome  # Test on web
```

---

## Configuration

### Sync Table Mappings

Edit `sync/config.js` to configure which tables to sync:

```javascript
module.exports = {
  tableMapping: {
    // Master tables (reference data)
    'orgmaster': 'orgmaster',
    'locmaster': 'locmaster',
    'conmaster': 'conmaster',
    'climaster': 'climaster',
    'mbstaff': 'mbstaff',
    'taskmaster': 'taskmaster',

    // Transactional tables
    'jobshead': 'jobshead',
    'jobtasks': 'jobtasks',
    'taskchecklist': 'taskchecklist',
    'workdiary': 'workdiary',
    'reminder': 'reminder',
    'remdetail': 'remdetail',
    'learequest': 'learequest',
  },

  columnMapping: {
    // Column transformations and additions
    jobshead: {
      addColumns: {
        source: 'D',  // Desktop source
        created_at: () => new Date(),
        updated_at: () => new Date(),
      }
    },
    // ... more mappings
  }
};
```

---

## Usage

### Running Sync Manually

#### Full Sync (All Records)
```bash
# Safe production sync (uses staging tables)
node sync/production/runner-staging.js --mode=full

# Estimated time: 2-3 minutes for 24,000 jobs
```

#### Incremental Sync (Changed Records Only)
```bash
# Only sync records changed since last sync
node sync/production/runner-staging.js --mode=incremental

# Estimated time: 10-30 seconds
```

#### Reverse Sync (Mobile -> Desktop)
```bash
# Pull mobile-created records back to desktop
node sync/production/reverse-sync-runner.js

# Estimated time: 5-15 seconds
```

### One-Click Sync (Windows)

Use the batch scripts in `batch-scripts/manual/`:

```bash
# Interactive menu
sync-menu.bat

# Direct execution
sync-full.bat          # Full forward sync
sync-incremental.bat   # Incremental forward sync
sync-reverse.bat       # Reverse sync
```

### Automated Scheduling (Windows Task Scheduler)

Set up automated sync jobs:

```bash
# Run PowerShell as Administrator
cd batch-scripts/automated
powershell -ExecutionPolicy Bypass -File setup-windows-scheduler.ps1
```

This creates 3 scheduled tasks:
- **Forward Sync (Full)** - Weekly on Sunday at 2:00 AM
- **Forward Sync (Incremental)** - Daily at 1:00 AM
- **Reverse Sync** - Every 4 hours

---

## Sync Engine

### Architecture

The sync engine uses a **staging table pattern** for safe data replication:

```javascript
// Safe sync process
1. CREATE TEMP TABLE staging
2. INSERT all data -> staging
3. BEGIN TRANSACTION
4.   DELETE FROM production WHERE source='D'
5.   INSERT FROM staging
6. COMMIT  // Atomic operation
```

### Sync Modes

| Mode | Description | Use Case | Speed |
|------|-------------|----------|-------|
| **Full** | Sync all records | Initial sync, monthly refresh | 2-3 min |
| **Incremental** | Sync changed records only | Daily updates | 10-30 sec |
| **Reverse** | Pull mobile data to desktop | After mobile data entry | 5-15 sec |

### Data Source Tracking

Every record includes a `source` column:
- `source='D'` - Desktop-originated record
- `source='M'` - Mobile-originated record
- `source=NULL` - Legacy record (pre-sync)

---

## Mobile App

### Architecture: Clean Architecture + BLoC

```
lib/
├── features/              # Feature modules
│   ├── auth/              # Authentication
│   ├── jobs/              # Jobs management
│   ├── work_diary/        # Time tracking
│   ├── leave/             # Leave management
│   ├── pinboard/          # Pinboard/reminders
│   └── home/              # Dashboard
│
├── core/                  # Core utilities
│   ├── config/            # DI, Supabase config
│   ├── constants/         # API endpoints
│   ├── errors/            # Exception handling
│   └── utils/             # Validators, crypto
│
└── shared/                # Shared widgets
```

### Clean Architecture Layers

```
+-------------------------------------+
|        Presentation Layer           |
|   (Pages, Widgets, BLoC)           |
|   - UI components                   |
|   - State management                |
|   - User interactions               |
+------------------+------------------+
                   |
+------------------v------------------+
|         Domain Layer                |
|   (Entities, Use Cases, Interfaces) |
|   - Business logic                  |
|   - Pure Dart (no Flutter)          |
|   - Repository interfaces           |
+------------------+------------------+
                   |
+------------------v------------------+
|          Data Layer                 |
|   (Models, Repositories, Sources)   |
|   - API calls (Supabase)           |
|   - Local storage (Hive)           |
|   - Data transformations            |
+-------------------------------------+
```

### Running the Mobile App

```bash
cd powerca_mobile

# Run on Chrome (recommended for development)
flutter run -d chrome

# Run on Android emulator
flutter run -d emulator-5554

# Build APK
flutter build apk --release
```

### Development Commands

```bash
# Get dependencies
flutter pub get

# Run app (debug)
flutter run

# Run app (release)
flutter run --release

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Run tests
flutter test

# Format code
flutter format lib/

# Analyze code
flutter analyze

# Clean build
flutter clean
```

### Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_bloc` | State management |
| `supabase_flutter` | Backend & database |
| `get_it` | Dependency injection |
| `dio` | HTTP client |
| `hive` | Local storage |
| `go_router` | Navigation |
| `google_fonts` | Typography |
| `fl_chart` | Charts & graphs |
| `table_calendar` | Calendar widget |

---

## Troubleshooting

### Common Issues

#### 1. "Column does not exist" Error

**Problem:** Database schema mismatch between desktop and cloud.

**Solution:** Check `SCHEMA-COLUMN-MAPPINGS.md` for correct column names:
```bash
# Desktop uses: clientname (one word)
# NOT: client_name (with underscore)
```

#### 2. Foreign Key Constraint Violation

**Problem:** Desktop has orphaned records that violate FK constraints.

**Solution:** Remove problematic FK constraints:
```bash
node scripts/remove-all-problematic-fks.js
```

#### 3. Sync Timeout

**Problem:** Large tables timing out during sync.

**Solution:** Increase timeouts in `sync/config.js`:
```javascript
target: {
  statement_timeout: 1800000,  // 30 minutes
  idle_in_transaction_session_timeout: 900000,  // 15 minutes
}
```

#### 4. Empty Job List in Mobile App

**Problem:** Wrong filtering strategy (staff_id vs org_id).

**Solution:** Use organization-based filtering (already implemented):
```dart
// Get staff's org_id
final orgId = staffData['org_id'];

// Filter jobs by organization
final jobs = await supabase
    .from('jobshead')
    .select()
    .eq('org_id', orgId);
```

#### 5. Flutter build issues

```bash
flutter clean
flutter pub get
```

---

## Documentation

### Essential Reading

1. **[CLAUDE.md](CLAUDE.md)** - Critical learnings and safety rules
2. **[SYNC-ENGINE-ETL-GUIDE.md](docs/SYNC-ENGINE-ETL-GUIDE.md)** - Complete ETL documentation
3. **[SCHEMA-COLUMN-MAPPINGS.md](SCHEMA-COLUMN-MAPPINGS.md)** - Database column reference

### Troubleshooting Guides

- [SYNC_GUIDE.md](docs/SYNC_GUIDE.md) - Sync troubleshooting
- [FIX-FK-CACHE-STALENESS.md](docs/FIX-FK-CACHE-STALENESS.md) - FK validation issues
- [FIX-FORWARD-SYNC-METADATA-RACE-CONDITION.md](docs/FIX-FORWARD-SYNC-METADATA-RACE-CONDITION.md) - Race condition fixes

### Architecture Documentation

- [BIDIRECTIONAL-SYNC-STRATEGY.md](docs/BIDIRECTIONAL-SYNC-STRATEGY.md) - Sync architecture
- [ARCHITECTURE-DECISIONS.md](docs/ARCHITECTURE-DECISIONS.md) - Key design decisions
- [staging-table-sync.md](docs/staging-table-sync.md) - Staging pattern explained

### External Resources

- [Flutter Documentation](https://docs.flutter.dev)
- [BLoC Pattern](https://bloclibrary.dev)
- [Supabase Flutter](https://supabase.com/docs/guides/with-flutter)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

## Security Considerations

### Credentials Management

- **Never commit** `.env` files (use `.env.example` templates)
- **Rotate passwords** after any credential exposure
- **Use environment variables** for all sensitive data
- **Restrict database access** to specific IP addresses

### Data Protection

- **Encrypted passwords** - PowerBuilder-compatible encryption
- **Secure token storage** - flutter_secure_storage
- **HTTPS only** - All Supabase API calls use HTTPS
- **Row-level security** - Supabase RLS policies

---

## Performance Metrics

### Sync Performance (24,000 jobs dataset)

| Operation | Mode | Records | Time | Records/sec |
|-----------|------|---------|------|-------------|
| Forward Sync | Full | 24,568 | 2m 15s | 182/sec |
| Forward Sync | Incremental | 150 | 12s | 12.5/sec |
| Reverse Sync | Incremental | 50 | 8s | 6.25/sec |

---

## Contributing

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly (sync + mobile)
5. Commit with descriptive messages
6. Push to your fork
7. Open a Pull Request

---

## License

This project is proprietary software developed for PowerCA. Unauthorized copying, distribution, or modification is prohibited.

---

**Version:** 1.0.0
**Status:** Production Ready
**Last Updated:** February 2026

**Built by the PowerCA Team**
