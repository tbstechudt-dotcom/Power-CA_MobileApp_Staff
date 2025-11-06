# PowerCA Mobile - Deployment Guide

**Complete guide for deploying PowerCA Mobile to Google Play Store and Apple App Store**

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Environment Configuration](#environment-configuration)
3. [Android Deployment](#android-deployment)
4. [iOS Deployment](#ios-deployment)
5. [Version Management](#version-management)
6. [Testing Before Release](#testing-before-release)
7. [App Store Submission](#app-store-submission)
8. [Post-Deployment](#post-deployment)
9. [Troubleshooting](#troubleshooting)

---

## Pre-Deployment Checklist

### General Requirements

- [ ] App fully functional and tested on both Android and iOS
- [ ] All features working with Supabase backend
- [ ] Authentication flow tested (login, logout, password reset)
- [ ] Offline mode working correctly
- [ ] Push notifications configured and tested
- [ ] App icon and splash screen designed and implemented
- [ ] Privacy policy and terms of service documents ready
- [ ] App store listing content prepared (screenshots, descriptions, keywords)
- [ ] All API keys and secrets secured (not hardcoded)
- [ ] Analytics and crash reporting configured
- [ ] All third-party dependencies reviewed and licenses checked

### Technical Requirements

- [ ] Flutter SDK updated to stable version
- [ ] All dependencies updated to latest stable versions
- [ ] No debug code or console logs in production
- [ ] Error handling implemented for all critical flows
- [ ] Network timeout and retry logic implemented
- [ ] Loading states and error messages user-friendly
- [ ] App performance tested (no memory leaks, smooth scrolling)
- [ ] Security audit completed (API keys, data storage, network calls)

### Store-Specific Requirements

**Android:**
- [ ] Google Play Developer account created ($25 one-time fee)
- [ ] App signing key generated and backed up securely
- [ ] Target SDK version meets Google Play requirements (currently API 34+)

**iOS:**
- [ ] Apple Developer account created ($99/year)
- [ ] Development and distribution certificates generated
- [ ] App ID registered in Apple Developer Portal
- [ ] Provisioning profiles created

---

## Environment Configuration

### 1. Environment Variables Setup

Create environment-specific configuration files:

```dart
// lib/core/config/env_config.dart
class EnvConfig {
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'production',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jacqfogzgzvbjeizljqf.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '', // Set via build argument
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
}
```

### 2. Flavor Configuration (Optional)

For managing multiple environments (dev, staging, production):

```yaml
# Add to pubspec.yaml
flutter:
  flavors:
    development:
      app_name: "PowerCA Dev"
      bundle_id: "com.powerca.mobile.dev"
    staging:
      app_name: "PowerCA Staging"
      bundle_id: "com.powerca.mobile.staging"
    production:
      app_name: "PowerCA Mobile"
      bundle_id: "com.powerca.mobile"
```

### 3. Secure Secrets Management

**DO NOT commit secrets to Git!**

Create `.env` file (add to `.gitignore`):

```bash
# .env (NOT committed to Git)
SUPABASE_URL=https://jacqfogzgzvbjeizljqf.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
ANDROID_KEYSTORE_PASSWORD=your-keystore-password
ANDROID_KEY_PASSWORD=your-key-password
```

Use `flutter_dotenv` package to load secrets:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}
```

---

## Android Deployment

### Step 1: Configure App Signing

#### 1.1 Generate Upload Key

```bash
# Navigate to project root
cd d:\PowerCA Mobile

# Generate keystore (run once, keep secure!)
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# Follow prompts:
# - Enter keystore password (save securely!)
# - Enter key password (save securely!)
# - Enter your details (name, organization, etc.)
```

**CRITICAL:** Backup `upload-keystore.jks` securely! If lost, you cannot update your app!

#### 1.2 Configure Signing in Gradle

Create `android/key.properties`:

```properties
# android/key.properties (add to .gitignore!)
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=upload-keystore.jks
```

Update `android/app/build.gradle`:

```gradle
// Load keystore properties
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config

    defaultConfig {
        applicationId "com.powerca.mobile"
        minSdkVersion 21
        targetSdkVersion 34  // Update to latest
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### Step 2: Configure App Permissions

Update `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Required permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <!-- Optional permissions (only if needed) -->
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>

    <application
        android:label="PowerCA Mobile"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false">
        <!-- ... -->
    </application>
</manifest>
```

### Step 3: Build Release APK/AAB

#### Build APK (for testing)

```bash
flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SUPABASE_URL=https://jacqfogzgzvbjeizljqf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### Build App Bundle (for Play Store)

```bash
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SUPABASE_URL=https://jacqfogzgzvbjeizljqf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Step 4: Test Release Build

```bash
# Install APK on connected device
flutter install --release

# Or manually install
adb install build/app/outputs/flutter-apk/app-release.apk

# Test all critical flows:
# - Login/logout
# - Data sync
# - Offline mode
# - Push notifications
# - Camera/file upload (if applicable)
```

### Step 5: Google Play Console Setup

1. **Create Application:**
   - Go to https://play.google.com/console
   - Click "Create app"
   - Fill in app details (name, language, type, category)

2. **App Content:**
   - Privacy policy URL
   - App access (login credentials if required)
   - Ads declaration
   - Content ratings questionnaire
   - Target audience
   - Data safety form

3. **Store Listing:**
   - App name: "PowerCA Mobile"
   - Short description (80 chars)
   - Full description (4000 chars)
   - Screenshots (minimum 2 per device type)
   - Feature graphic (1024x500)
   - App icon (512x512)

4. **Upload Release:**
   - Go to "Production" or "Internal testing"
   - Create new release
   - Upload `app-release.aab`
   - Add release notes
   - Review and rollout

### Step 6: Configure App Signing by Google Play (Recommended)

1. In Play Console, go to "Setup" > "App signing"
2. Opt in to "App signing by Google Play"
3. Upload your upload key certificate:

```bash
keytool -export -rfc \
  -keystore upload-keystore.jks \
  -alias upload \
  -file upload_certificate.pem
```

4. Upload `upload_certificate.pem` to Play Console

---

## iOS Deployment

### Step 1: Apple Developer Account Setup

1. **Enroll in Apple Developer Program:**
   - Go to https://developer.apple.com/programs/
   - Pay $99/year enrollment fee
   - Wait for approval (1-2 days)

2. **Install Xcode:**
   - Download from Mac App Store
   - Open Xcode and accept license agreement
   - Install additional components

### Step 2: Configure App in Xcode

```bash
# Open iOS project in Xcode
open ios/Runner.xcworkspace
```

#### 2.1 Bundle Identifier

1. Select "Runner" in project navigator
2. Select "Runner" target
3. General tab > Identity
4. Set Bundle Identifier: `com.powerca.mobile`

#### 2.2 Signing & Capabilities

1. General tab > Signing
2. Check "Automatically manage signing"
3. Select your development team
4. Xcode will generate provisioning profiles

#### 2.3 App Capabilities (if needed)

1. Signing & Capabilities tab
2. Click "+ Capability"
3. Add required capabilities:
   - Push Notifications
   - Background Modes (if syncing in background)
   - Camera (if using camera)
   - Location (if using GPS)

### Step 3: Update Info.plist

Edit `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- App name -->
    <key>CFBundleName</key>
    <string>PowerCA Mobile</string>

    <!-- Display name -->
    <key>CFBundleDisplayName</key>
    <string>PowerCA</string>

    <!-- Version -->
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>

    <!-- Privacy permissions (customize as needed) -->
    <key>NSCameraUsageDescription</key>
    <string>PowerCA needs camera access to capture job photos</string>

    <key>NSPhotoLibraryUsageDescription</key>
    <string>PowerCA needs photo library access to attach images</string>

    <key>NSLocationWhenInUseUsageDescription</key>
    <string>PowerCA needs location access to track work sites</string>

    <!-- Supabase URL scheme (for deep linking) -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>com.powerca.mobile</string>
            </array>
        </dict>
    </array>
</dict>
```

### Step 4: App Icons and Launch Screen

#### 4.1 App Icon

1. Create app icons using https://appicon.co/
2. Upload 1024x1024 PNG
3. Download iOS asset catalog
4. Replace `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

#### 4.2 Launch Screen

Edit `ios/Runner/Base.lproj/LaunchScreen.storyboard` in Xcode or use Flutter's `flutter_native_splash` package:

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_native_splash: ^2.3.5

flutter_native_splash:
  color: "#FFFFFF"
  image: assets/images/splash.png
  ios: true
  android: true
```

```bash
flutter pub run flutter_native_splash:create
```

### Step 5: Build Release IPA

```bash
# Clean build
flutter clean

# Build iOS release
flutter build ios --release \
  --dart-define=ENVIRONMENT=production \
  --dart-define=SUPABASE_URL=https://jacqfogzgzvbjeizljqf.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

# This builds to: build/ios/iphoneos/Runner.app
```

### Step 6: Create Archive in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device (arm64)" as destination
3. Product > Archive
4. Wait for archive to complete (~5-10 minutes)
5. Xcode Organizer will open with your archive

### Step 7: Upload to App Store Connect

#### 7.1 Create App in App Store Connect

1. Go to https://appstoreconnect.apple.com/
2. Click "My Apps" > "+"
3. Fill in:
   - Platform: iOS
   - Name: PowerCA Mobile
   - Primary language: English
   - Bundle ID: com.powerca.mobile
   - SKU: powerca-mobile-001

#### 7.2 App Information

1. **Privacy Policy URL:** Your privacy policy URL
2. **Category:** Business or Productivity
3. **Content Rights:** Own or have licensed rights

#### 7.3 Prepare for Submission

1. **Screenshots** (required for each device size):
   - 6.7" Display (iPhone 14 Pro Max): 1290x2796
   - 6.5" Display (iPhone 11 Pro Max): 1284x2778
   - 5.5" Display (iPhone 8 Plus): 1242x2208
   - iPad Pro (6th gen): 2048x2732

2. **App Preview Video** (optional but recommended)

3. **Description:**
   - Promotional text (170 chars)
   - Description (4000 chars)
   - Keywords (100 chars, comma-separated)
   - Support URL
   - Marketing URL (optional)

#### 7.4 Upload Build

1. In Xcode Organizer, select your archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Select "Upload"
5. Follow prompts (signing, provisioning)
6. Wait for upload (5-30 minutes)

#### 7.5 TestFlight (Recommended)

1. In App Store Connect, go to "TestFlight" tab
2. Your uploaded build will appear (processing takes ~10-60 minutes)
3. Add internal testers (up to 100)
4. Add external testers (up to 10,000, requires beta review)
5. Send invites and gather feedback

### Step 8: Submit for Review

1. Go to "App Store" tab in App Store Connect
2. Click on your version (1.0.0)
3. Fill in all required fields:
   - Screenshots
   - Description
   - Keywords
   - Support URL
   - Build selection
4. **Rating Questionnaire:** Complete content rating
5. **App Review Information:**
   - Contact information
   - Demo account (if app requires login)
   - Notes for reviewer (any special instructions)
6. **Version Release:** Choose automatic or manual release
7. Click "Submit for Review"

**Review Timeline:** Typically 24-48 hours, can be up to 7 days.

---

## Version Management

### Semantic Versioning

Use semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes (e.g., 1.0.0 → 2.0.0)
- **MINOR:** New features, backward-compatible (e.g., 1.0.0 → 1.1.0)
- **PATCH:** Bug fixes (e.g., 1.0.0 → 1.0.1)

### Update Version Numbers

**pubspec.yaml:**
```yaml
version: 1.0.0+1
#         │  │ │  └─ Build number (Android: versionCode, iOS: CFBundleVersion)
#         │  │ └──── Patch version
#         │  └─────── Minor version
#         └────────── Major version
```

**Rules:**
- Increment build number (+1) for every release
- Update version string for user-facing changes
- Android versionCode must always increase
- iOS CFBundleVersion must be higher than previous

**Example progression:**
```
1.0.0+1  → Initial release
1.0.1+2  → Bug fix
1.1.0+3  → New feature
2.0.0+4  → Breaking change
```

### Automated Version Bumping

Create script: `scripts/bump-version.sh`

```bash
#!/bin/bash
# Usage: ./scripts/bump-version.sh [major|minor|patch]

TYPE=${1:-patch}
CURRENT=$(grep -E "^version:" pubspec.yaml | cut -d ' ' -f 2)
VERSION=$(echo $CURRENT | cut -d '+' -f 1)
BUILD=$(echo $CURRENT | cut -d '+' -f 2)

MAJOR=$(echo $VERSION | cut -d '.' -f 1)
MINOR=$(echo $VERSION | cut -d '.' -f 2)
PATCH=$(echo $VERSION | cut -d '.' -f 3)

case $TYPE in
  major)
    NEW_VERSION="$((MAJOR + 1)).0.0"
    ;;
  minor)
    NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
    ;;
  patch)
    NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
    ;;
esac

NEW_BUILD=$((BUILD + 1))
NEW_FULL="$NEW_VERSION+$NEW_BUILD"

sed -i "s/^version:.*/version: $NEW_FULL/" pubspec.yaml

echo "Version bumped: $CURRENT → $NEW_FULL"
```

```bash
# Make executable
chmod +x scripts/bump-version.sh

# Usage
./scripts/bump-version.sh patch   # 1.0.0+1 → 1.0.1+2
./scripts/bump-version.sh minor   # 1.0.0+1 → 1.1.0+2
./scripts/bump-version.sh major   # 1.0.0+1 → 2.0.0+2
```

---

## Testing Before Release

### 1. Automated Testing

```bash
# Run all unit tests
flutter test

# Run integration tests
flutter test integration_test

# Run with coverage
flutter test --coverage
```

### 2. Manual Testing Checklist

**Authentication:**
- [ ] Login with valid credentials
- [ ] Login with invalid credentials (error handling)
- [ ] Logout functionality
- [ ] Password reset flow
- [ ] Session persistence (reopen app, still logged in)

**Core Features:**
- [ ] Job list loads correctly
- [ ] Job details display properly
- [ ] Create new job
- [ ] Update existing job
- [ ] Delete job
- [ ] Work diary time tracking
- [ ] Client management
- [ ] Staff management
- [ ] Reminders and notifications

**Offline Mode:**
- [ ] Enable airplane mode
- [ ] App functions with cached data
- [ ] Create/update records offline
- [ ] Re-enable network
- [ ] Verify sync to Supabase

**Performance:**
- [ ] App launches in <3 seconds
- [ ] Lists scroll smoothly (60fps)
- [ ] No memory leaks (use DevTools)
- [ ] Images load efficiently
- [ ] Background sync doesn't drain battery

**Error Handling:**
- [ ] Network timeout displays user-friendly error
- [ ] Invalid input validation works
- [ ] API errors handled gracefully
- [ ] App doesn't crash on bad data

**Permissions:**
- [ ] Camera permission requested correctly
- [ ] Location permission requested correctly
- [ ] File storage permission requested correctly

### 3. Device Testing

Test on multiple devices:

**Android:**
- [ ] Low-end device (Android 7, 2GB RAM)
- [ ] Mid-range device (Android 10, 4GB RAM)
- [ ] High-end device (Android 13+, 8GB RAM)
- [ ] Tablet (10" screen)

**iOS:**
- [ ] iPhone SE (small screen)
- [ ] iPhone 13/14 (standard screen)
- [ ] iPhone 14 Pro Max (large screen)
- [ ] iPad

### 4. Beta Testing

**Android (Google Play Internal Testing):**
1. Upload AAB to "Internal testing" track
2. Add testers (up to 100 email addresses)
3. Share opt-in URL: https://play.google.com/apps/internaltest/...
4. Gather feedback (1-2 weeks)

**iOS (TestFlight):**
1. Upload build to TestFlight
2. Add internal testers (25 team members)
3. Add external testers (up to 10,000)
4. Share invite links
5. Gather feedback (1-2 weeks)

**Feedback Collection:**
- Use in-app feedback form
- Monitor crash reports (Firebase Crashlytics)
- Track analytics (user flows, drop-offs)
- Create Google Form/Survey for structured feedback

---

## App Store Submission

### Required Assets

#### Screenshots

**Android (Google Play):**
- Phone: 1080x1920 minimum (PNG or JPG)
- 7" Tablet: 1920x1200 minimum
- 10" Tablet: 2560x1600 minimum
- Minimum 2 screenshots per device type

**iOS (App Store):**
- 6.7" Display: 1290x2796 (iPhone 14 Pro Max)
- 6.5" Display: 1284x2778 (iPhone 11 Pro Max)
- 5.5" Display: 1242x2208 (iPhone 8 Plus)
- iPad Pro: 2048x2732
- Minimum 1 screenshot per device size

**Tips:**
- Use tools like https://www.appstorescreenshot.com/
- Add text overlay explaining features
- Show actual app content (no fake data)
- Keep screenshots current with app design

#### App Icon

- **Android:** 512x512 PNG (Play Console)
- **iOS:** 1024x1024 PNG (App Store Connect)
- **Guidelines:**
  - No transparency
  - No rounded corners (system adds them)
  - Recognizable at small sizes
  - Consistent with brand

#### Feature Graphic (Android Only)

- **Size:** 1024x500 PNG or JPG
- **Usage:** Displayed at top of store listing
- **Tips:** Include app name, tagline, key features

### App Descriptions

#### Short Description (Android: 80 chars)

```
Manage jobs, track time, and sync work data on the go with PowerCA Mobile.
```

#### Full Description (4000 chars)

```
PowerCA Mobile - Professional Job Management & Time Tracking

Streamline your workflow with PowerCA Mobile, the comprehensive mobile solution for job management, time tracking, and client coordination.

KEY FEATURES:

Job Management
• View and manage all your assigned jobs in one place
• Create new jobs with client details and specifications
• Update job status and track progress in real-time
• Attach photos and documents to jobs

Time Tracking
• Log work hours with built-in work diary
• Track time spent on each job and task
• Automatic sync with desktop system
• Export timesheets for payroll processing

Task Management
• Break down jobs into manageable tasks
• Assign tasks to team members
• Track task completion with checklists
• Set priorities and deadlines

Client Management
• Access complete client information on the go
• View job history per client
• Quick contact via phone or email
• Notes and special instructions

Reminders & Notifications
• Set reminders for important tasks and deadlines
• Receive push notifications for updates
• Calendar integration for scheduling
• Never miss a critical deadline

Offline Mode
• Work without internet connection
• All data cached locally for quick access
• Automatic sync when connection restored
• No data loss with reliable sync engine

Team Collaboration
• View staff schedules and availability
• Coordinate tasks with team members
• Share job updates in real-time
• Leave requests and approvals

BENEFITS:

✓ Increase productivity with mobile access to all job data
✓ Reduce paperwork with digital job management
✓ Improve accuracy with real-time updates
✓ Save time with automated sync to desktop system
✓ Enhance customer service with instant access to client info
✓ Track billable hours accurately for precise invoicing

SECURE & RELIABLE:

• Enterprise-grade security with encrypted data transmission
• Regular automatic backups
• Role-based access control
• Compliant with data protection regulations

SEAMLESS INTEGRATION:

PowerCA Mobile seamlessly integrates with your existing PowerCA desktop system, ensuring all data is synchronized and up-to-date across all platforms.

SUPPORT:

Our dedicated support team is here to help. Contact us at support@powerca.com or visit our website for documentation and tutorials.

Download PowerCA Mobile today and take your job management to the next level!
```

#### Keywords (iOS: 100 chars, comma-separated)

```
job management,time tracking,work diary,task manager,field service,workforce,productivity,CRM
```

### Privacy Policy & Terms

**Required URLs:**
- Privacy Policy: Host at your domain (e.g., https://powerca.com/mobile-privacy-policy)
- Terms of Service: https://powerca.com/mobile-terms

**Must Include:**
- Data collection practices
- How data is used
- Third-party services (Supabase, analytics)
- User rights (access, deletion)
- Contact information

**Template:** Use https://www.privacypolicies.com/privacy-policy-generator/

### App Review Information

**Demo Account (if required):**
```
Username: demo@powerca.com
Password: DemoAccount2024!
```

**Notes for Reviewers:**
```
PowerCA Mobile is a job management and time tracking app for field service teams.

To test the app:
1. Login with demo account (credentials above)
2. Navigate to "Jobs" tab to view assigned jobs
3. Click on a job to see details, tasks, and time tracking
4. Use "Work Diary" to log time (requires camera permission for job photos)
5. Check "Clients" tab for customer information
6. Test offline mode by enabling airplane mode - app continues to function

Required Permissions:
- Camera: For capturing job site photos
- Location: For tracking work site locations (optional feature)
- Notifications: For reminders and job updates

All data syncs with secure Supabase backend when online.
```

---

## Post-Deployment

### 1. Monitor App Performance

**Firebase Crashlytics:**
```dart
// Initialize in main.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const MyApp());
}
```

**Monitor:**
- Crash rate (target: <0.5%)
- ANR rate (Application Not Responding)
- API error rates
- Slow rendering frames

### 2. Analytics Tracking

**Firebase Analytics:**
```dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// Track screen views
analytics.logScreenView(screenName: 'JobListScreen');

// Track user actions
analytics.logEvent(
  name: 'job_created',
  parameters: {'job_type': 'installation'},
);

// Track performance
analytics.logEvent(
  name: 'sync_completed',
  parameters: {
    'duration_ms': 1234,
    'records_synced': 150,
  },
);
```

**Key Metrics to Track:**
- Daily/Monthly Active Users (DAU/MAU)
- Session duration
- Screen views and navigation flows
- Feature usage (which features are most used?)
- Sync success/failure rates
- User retention (Day 1, Day 7, Day 30)

### 3. User Feedback

**In-App Feedback:**
```dart
// Add feedback button in settings
FloatingActionButton(
  child: Icon(Icons.feedback),
  onPressed: () {
    // Open feedback form or email
    launchUrl(Uri.parse('mailto:support@powerca.com?subject=PowerCA Mobile Feedback'));
  },
);
```

**Review Prompts:**
```dart
// Use in_app_review package
import 'package:in_app_review/in_app_review.dart';

final InAppReview inAppReview = InAppReview.instance;

// Prompt after successful actions (e.g., 5 jobs completed)
if (await inAppReview.isAvailable()) {
  inAppReview.requestReview();
}
```

### 4. Release Notes Template

**Version 1.0.0:**
```
Initial release of PowerCA Mobile!

Features:
• Job management and tracking
• Work diary time logging
• Client and staff management
• Offline mode with automatic sync
• Reminders and notifications
• Photo attachments for jobs

We're excited to bring PowerCA to mobile! Please send feedback to support@powerca.com.
```

**Version 1.1.0:**
```
New features:
• Dark mode support
• Improved sync performance
• Bulk job updates
• Enhanced search and filters

Bug fixes:
• Fixed crash when uploading large images
• Improved offline mode reliability
• Fixed sync conflicts with concurrent edits

Performance improvements:
• 30% faster job list loading
• Reduced battery consumption
```

### 5. Hotfix Process

If critical bug found after release:

**Quick Hotfix:**
```bash
# 1. Create hotfix branch
git checkout -b hotfix/1.0.1 v1.0.0

# 2. Fix the bug
# ... make changes ...

# 3. Bump version
./scripts/bump-version.sh patch  # 1.0.0+1 → 1.0.1+2

# 4. Build release
flutter build appbundle --release  # Android
flutter build ios --release        # iOS

# 5. Upload to stores (mark as urgent/expedited if critical)

# 6. Merge back to main
git checkout main
git merge hotfix/1.0.1
git tag v1.0.1
git push --tags
```

**Expedited Review:**
- Google Play: Use "Managed publishing" to release immediately after approval
- Apple: Request expedited review (only for critical bugs, limited to 2/year)

### 6. Update Rollout Strategy

**Google Play (Staged Rollout):**
1. Release to 5% of users first
2. Monitor crash rate and reviews
3. Increase to 20%, then 50%, then 100% over 1 week
4. Pause rollout if issues detected

**iOS (Phased Release):**
1. Enable "Release over 7 days" in App Store Connect
2. Apple automatically rolls out gradually
3. Can pause and resume at any time

---

## Troubleshooting

### Common Android Issues

#### Issue: Build fails with "Execution failed for task ':app:lintVitalRelease'"

**Solution:**
```gradle
// android/app/build.gradle
android {
    lintOptions {
        checkReleaseBuilds false
        // Or just disable specific checks
        disable 'InvalidPackage'
    }
}
```

#### Issue: "INSTALL_FAILED_UPDATE_INCOMPATIBLE" when installing APK

**Solution:**
```bash
# Uninstall old version first
adb uninstall com.powerca.mobile

# Then install new version
flutter install --release
```

#### Issue: ProGuard/R8 obfuscation breaks app

**Solution:**
```proguard
# android/app/proguard-rules.pro

# Keep model classes (prevent JSON serialization issues)
-keep class com.powerca.mobile.data.models.** { *; }

# Keep Supabase classes
-keep class io.supabase.** { *; }

# Keep Dio classes
-keep class dio.** { *; }
```

### Common iOS Issues

#### Issue: "No suitable application records were found"

**Solution:**
1. Ensure Bundle ID matches in Xcode and App Store Connect
2. Verify provisioning profile is valid
3. Clean build: `flutter clean && flutter build ios`

#### Issue: Archive upload fails with authentication error

**Solution:**
```bash
# Re-authenticate with App Store Connect
xcrun altool --list-providers -u "your-apple-id@email.com" -p "@keychain:AC_PASSWORD"

# Or use app-specific password
# Generate at: appleid.apple.com > Security > App-Specific Passwords
```

#### Issue: App crashes on launch (iOS)

**Solution:**
1. Check Xcode crash logs
2. Verify Info.plist permissions are declared
3. Test on real device, not just simulator
4. Check for missing entitlements

### Build Size Optimization

**Android:**
```gradle
// android/app/build.gradle
android {
    buildTypes {
        release {
            // Split APKs by ABI (reduces size by ~40%)
            ndk {
                abiFilters 'armeabi-v7a', 'arm64-v8a'
            }
        }
    }
}
```

**iOS:**
```bash
# Build with bitcode (allows Apple to optimize)
flutter build ios --release --obfuscate --split-debug-info=build/ios/symbols
```

**Flutter:**
```yaml
# pubspec.yaml - Remove unused assets
flutter:
  assets:
    # Only include assets actually used
    - assets/images/logo.png
    # NOT: - assets/images/  (this includes everything)
```

**Bundle Size Targets:**
- Android AAB: <50MB (Google Play limit: 150MB)
- iOS IPA: <100MB (App Store limit: 4GB, but keep under 200MB for cellular downloads)

### Store Rejection Reasons

**Common Android Rejections:**
1. **Privacy Policy missing/invalid:** Ensure URL is accessible and comprehensive
2. **Permissions not explained:** Add usage descriptions in manifest
3. **Misleading content:** Screenshots must match actual app
4. **Malware/security:** Avoid obfuscation of malicious code patterns

**Common iOS Rejections:**
1. **Guideline 2.1 - App Completeness:** App crashes or has broken features
2. **Guideline 4.0 - Design:** Poor UI/UX, placeholders, or "Lorem ipsum" text
3. **Guideline 5.1.1 - Privacy:** Missing privacy policy or data usage descriptions
4. **Guideline 2.3.10 - Accurate Metadata:** Screenshots don't match app functionality

**How to Respond:**
1. Read rejection message carefully
2. Fix all mentioned issues
3. Test thoroughly
4. Resubmit with detailed "Resolution Center" message explaining fixes
5. Be polite and professional (reviewers are human!)

---

## Checklists

### Android Release Checklist

- [ ] Version bumped in `pubspec.yaml`
- [ ] `versionCode` and `versionName` updated in `build.gradle`
- [ ] Keystore file backed up securely
- [ ] `key.properties` configured (not committed!)
- [ ] Release build tested: `flutter build appbundle --release`
- [ ] APK installed and tested on real device
- [ ] ProGuard rules verified (no crashes)
- [ ] All permissions justified and declared
- [ ] Privacy policy URL updated
- [ ] Screenshots captured (phone + tablet)
- [ ] Feature graphic created (1024x500)
- [ ] Store listing reviewed (descriptions, keywords)
- [ ] Release notes written
- [ ] AAB uploaded to Play Console
- [ ] Internal testing completed (optional but recommended)
- [ ] Staged rollout configured (5% → 100%)
- [ ] Crash reporting enabled (Firebase Crashlytics)

### iOS Release Checklist

- [ ] Version bumped in `pubspec.yaml`
- [ ] `CFBundleShortVersionString` and `CFBundleVersion` updated in `Info.plist`
- [ ] Bundle ID matches App Store Connect
- [ ] Provisioning profiles valid and up-to-date
- [ ] App icon added (1024x1024, no transparency)
- [ ] Launch screen configured
- [ ] Release build tested: `flutter build ios --release`
- [ ] Archive created in Xcode
- [ ] IPA uploaded to App Store Connect
- [ ] TestFlight tested by internal team
- [ ] Privacy permission descriptions added to `Info.plist`
- [ ] Privacy policy URL updated
- [ ] Screenshots captured (all required device sizes)
- [ ] App preview video created (optional)
- [ ] Store listing reviewed (descriptions, keywords, category)
- [ ] Release notes written
- [ ] Demo account provided for reviewers (if needed)
- [ ] App submitted for review
- [ ] Crash reporting enabled (Firebase Crashlytics)

---

## Resources

### Official Documentation

- **Flutter Deployment:** https://docs.flutter.dev/deployment
- **Google Play Console:** https://play.google.com/console
- **App Store Connect:** https://appstoreconnect.apple.com/
- **Supabase Docs:** https://supabase.com/docs

### Tools

- **App Icon Generator:** https://appicon.co/
- **Screenshot Generator:** https://www.appstorescreenshot.com/
- **ASO (App Store Optimization):** https://www.apptweak.com/
- **Privacy Policy Generator:** https://www.privacypolicies.com/
- **Fastlane (CI/CD):** https://fastlane.tools/

### Learning Resources

- **Flutter Codelabs:** https://docs.flutter.dev/codelabs
- **Google Play Academy:** https://playacademy.exceedlms.com/
- **Apple Developer Videos:** https://developer.apple.com/videos/
- **Supabase YouTube:** https://www.youtube.com/c/Supabase

---

## Next Steps

After successful deployment:

1. **Monitor first 48 hours closely:**
   - Watch crash rate
   - Monitor user reviews
   - Check analytics for unusual patterns

2. **Gather user feedback:**
   - Send survey to early users
   - Monitor support emails
   - Track feature requests

3. **Plan next release:**
   - Prioritize bug fixes
   - Schedule feature development
   - Set release cadence (e.g., bi-weekly, monthly)

4. **Marketing:**
   - Announce on social media
   - Email existing customers
   - Create demo videos
   - Write blog post

5. **Support:**
   - Setup support email/chat
   - Create FAQ documentation
   - Record video tutorials
   - Monitor app store reviews and respond

---

**Document Version:** 1.0
**Last Updated:** 2025-11-01
**Maintained By:** PowerCA Development Team

**Remember:** Test thoroughly, deploy confidently, and iterate based on user feedback!
