# PowerCA Mobile

Auditor WorkLog Mobile Application built with Flutter

## 🎯 Project Status

**Scaffold Status**: ✅ Complete
**Architecture**: Clean Architecture + BLoC Pattern
**Backend**: Supabase Cloud (bidirectional sync)
**Design**: Figma design integration ready

---

## 📂 Project Structure

```
powerca_mobile/
├── lib/
│   ├── app/
│   │   └── theme.dart                    # ✅ App theme (Figma design tokens)
│   │
│   ├── core/
│   │   ├── config/
│   │   │   ├── injection.dart             # ✅ Dependency injection
│   │   │   └── supabase_config.dart       # ✅ Supabase configuration
│   │   ├── constants/
│   │   │   ├── api_constants.dart         # ✅ API endpoints & table names
│   │   │   └── app_constants.dart         # ✅ App constants & routes
│   │   ├── errors/
│   │   │   ├── failures.dart              # ✅ Failure classes
│   │   │   └── exceptions.dart            # ✅ Exception classes
│   │   ├── network/
│   │   │   └── network_info.dart          # ✅ Network connectivity check
│   │   └── utils/                         # TODO: Add utilities
│   │
│   ├── features/                          # Feature modules
│   │   ├── auth/                          # TODO: Authentication
│   │   ├── dashboard/                     # TODO: Dashboard
│   │   ├── jobs/                          # TODO: Jobs management
│   │   ├── work_diary/                    # TODO: Time tracking
│   │   ├── clients/                       # TODO: Client management
│   │   ├── reminders/                     # TODO: Reminders & calendar
│   │   ├── staff/                         # TODO: Team management
│   │   ├── leave/                         # TODO: Leave management
│   │   └── sync/                          # TODO: Sync monitoring
│   │
│   ├── shared/                            # Shared widgets & extensions
│   │   ├── widgets/                       # TODO: Reusable widgets
│   │   └── extensions/                    # TODO: Dart extensions
│   │
│   └── main.dart                          # TODO: App entry point
│
├── assets/                                # App assets
│   ├── images/
│   ├── icons/
│   └── fonts/                             # TODO: Add Poppins font files
│
├── test/                                  # Tests
│   ├── unit/
│   ├── widget/
│   └── integration/
│
└── pubspec.yaml                           # ✅ Dependencies configured
```

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   ```bash
   # Check installation
   flutter doctor
   ```

2. **Dart SDK** (comes with Flutter)

3. **Android Studio or VS Code** with Flutter extensions

### Installation Steps

1. **Install Flutter dependencies**
   ```bash
   cd powerca_mobile
   flutter pub get
   ```

2. **Configure Supabase**
   - Open `lib/core/config/supabase_config.dart`
   - Add your Supabase ANON key (get from [Supabase Dashboard](https://supabase.com/dashboard/project/jacqfogzgzvbjeizljqf/settings/api))

   ```dart
   static const String anonKey = 'your-actual-anon-key-here';
   ```

3. **Add Poppins fonts**
   - Download Poppins font from [Google Fonts](https://fonts.google.com/specimen/Poppins)
   - Place in `assets/fonts/`:
     - Poppins-Regular.ttf
     - Poppins-Medium.ttf
     - Poppins-SemiBold.ttf
     - Poppins-Bold.ttf

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 🎨 Design Tokens (from Figma)

The theme has been configured with colors extracted from Figma:

| Token | Value | Usage |
|-------|-------|-------|
| Primary Color | `#2255FC` | Buttons, links, primary actions |
| Surface Color | `#FFFFFF` | Cards, backgrounds |
| Background Color | `#F8F9FC` | Screen backgrounds |
| Accent Color | `#263238` | Text, icons |
| Font Family | Poppins | All text |

**See**: `lib/app/theme.dart` for complete theme configuration

---

## 📱 Features Roadmap

### Phase 1: Authentication & Core (Week 1-2)
- [ ] Splash Screen
- [ ] Login Screen
- [ ] Dashboard/Home
- [ ] Bottom Navigation
- [ ] Basic theme & layout

### Phase 2: Job Management (Week 3-4)
- [ ] Jobs List
- [ ] Job Details
- [ ] Task Management
- [ ] Task Checklist

### Phase 3: Work Diary (Week 5-6)
- [ ] Work Diary List
- [ ] Log Time Entry
- [ ] Calendar View
- [ ] Time Reports

### Phase 4: Additional Features (Week 7-8)
- [ ] Client Management
- [ ] Reminders & Calendar
- [ ] Team/Staff
- [ ] Leave Management
- [ ] Sync Dashboard

### Phase 5: Polish & Testing (Week 9-10)
- [ ] Offline support
- [ ] Push notifications
- [ ] Performance optimization
- [ ] Testing & bug fixes

---

## 🏗️ Architecture

### Clean Architecture Layers

```
┌─────────────────────────────────────┐
│        Presentation Layer           │
│   (Pages, Widgets, BLoC)            │
│   - UI components                   │
│   - State management                │
│   - User interactions               │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│         Domain Layer                │
│   (Entities, Use Cases, Interfaces) │
│   - Business logic                  │
│   - Pure Dart (no Flutter)          │
│   - Repository interfaces           │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│          Data Layer                 │
│   (Models, Repositories, Sources)   │
│   - API calls (Supabase)            │
│   - Local storage (Hive)            │
│   - Data transformations            │
└─────────────────────────────────────┘
```

### State Management: BLoC Pattern

Each feature follows this structure:

```dart
features/
  ├── domain/
  │   ├── entities/      # Business objects
  │   ├── repositories/  # Abstract interfaces
  │   └── usecases/      # Business operations
  │
  ├── data/
  │   ├── models/        # JSON models
  │   ├── repositories/  # Implementations
  │   └── datasources/   # API & local storage
  │
  └── presentation/
      ├── bloc/          # BLoC (events, states, logic)
      ├── pages/         # Screens
      └── widgets/       # UI components
```

---

## 🔧 Development Commands

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

---

## 📦 Key Dependencies

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

**See**: `pubspec.yaml` for complete list

---

## 🔗 Backend Integration

### Supabase Configuration

**Project URL**: https://jacqfogzgzvbjeizljqf.supabase.co
**Database**: PostgreSQL 17.6
**Sync Strategy**: Bidirectional (Desktop ↔ Supabase ↔ Mobile)

### Sync Schedule

- **Morning (9 AM)**: Desktop → Supabase (forward sync)
- **Evening (6 PM)**: Supabase → Desktop (reverse sync)
- **Real-time**: Mobile → Supabase (instant)

### Key Tables

- `mbstaff` - Staff members
- `jobshead` - Jobs
- `jobtasks` - Tasks
- `workdiary` - Time entries
- `climaster` - Clients
- `reminder` - Reminders
- `learequest` - Leave requests

**See**: `docs/ARCHITECTURE-DECISIONS.md` for complete sync strategy

---

## 📝 Next Steps

### Immediate (Today):

1. ✅ Flutter project structure created
2. ✅ Theme configured with Figma tokens
3. ✅ Core configuration completed
4. ⏳ **Get Figma screens** (Login, Dashboard, etc.)
5. ⏳ **Add Supabase ANON key** to config
6. ⏳ **Add Poppins fonts** to assets
7. ⏳ **Create Splash & Login screens**

### Short-term (This Week):

1. Complete authentication feature
2. Implement bottom navigation
3. Create dashboard layout
4. Connect to Supabase for login

### Medium-term (Next 2 Weeks):

1. Jobs module
2. Work diary module
3. Client module
4. Sync monitoring

---

## 🎨 Figma Integration

**Figma File**: PowerCA App Design
**MCP Integration**: ✅ Available

### Screens Needed from Figma:

1. ✅ Splash Screen (Retrieved)
2. ⏳ Login Screen
3. ⏳ Welcome/Onboarding
4. ⏳ Dashboard
5. ⏳ Jobs List
6. ⏳ Job Details
7. ⏳ Work Diary
8. ⏳ Client List

---

## 🐛 Troubleshooting

### Flutter doctor issues

```bash
flutter doctor -v
```

### Clear build cache

```bash
flutter clean
flutter pub get
```

### Supabase connection issues

- Check `SUPABASE_ANON_KEY` in `supabase_config.dart`
- Verify network connectivity
- Check Supabase dashboard status

---

## 📚 Documentation

- [Flutter Documentation](https://docs.flutter.dev)
- [BLoC Pattern](https://bloclibrary.dev)
- [Supabase Flutter](https://supabase.com/docs/guides/with-flutter)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

---

## 📄 License

Proprietary - PowerCA Mobile App

---

**Created**: 2025-10-30
**Status**: Scaffold Complete - Ready for Feature Development
**Version**: 1.0.0
