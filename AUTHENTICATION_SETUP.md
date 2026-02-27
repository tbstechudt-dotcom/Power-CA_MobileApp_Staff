# Authentication Setup Guide

## Overview

The PowerCA Mobile app now has complete authentication infrastructure integrated with Supabase. Users authenticate against the `mbstaff` table using username and password.

## Current Implementation Status

✅ **COMPLETED:**
- Clean Architecture implementation (Domain, Data, Presentation layers)
- BLoC state management for authentication
- Supabase integration via `mbstaff` table
- AES-CBC encryption/decryption service
- Local session persistence
- Sign-in UI with validation
- Error handling and user feedback

⚠️ **PENDING:**
- Encryption key configuration (see below)
- Dashboard/home screen (for post-login navigation)
- Forgot password functionality

---

## Architecture

```
lib/features/auth/
├── domain/
│   ├── entities/
│   │   └── staff.dart              # Staff entity
│   ├── repositories/
│   │   └── auth_repository.dart    # Repository interface
│   └── usecases/
│       ├── sign_in_usecase.dart
│       ├── sign_out_usecase.dart
│       └── get_current_staff_usecase.dart
├── data/
│   ├── models/
│   │   └── staff_model.dart        # Data model with JSON serialization
│   ├── datasources/
│   │   ├── auth_remote_datasource.dart  # Supabase queries
│   │   └── auth_local_datasource.dart   # SharedPreferences
│   └── repositories/
│       └── auth_repository_impl.dart
└── presentation/
    ├── bloc/
    │   ├── auth_bloc.dart
    │   ├── auth_event.dart
    │   └── auth_state.dart
    ├── pages/
    │   └── sign_in_page.dart
    └── widgets/
        └── powerca_logo.dart
```

---

## IMPORTANT: Encryption Key Setup

### Background

The desktop PowerBuilder application encrypts passwords in the `mbstaff` table using:
- **Algorithm:** AES (Advanced Encryption Standard)
- **Mode:** CBC (Cipher Block Chaining)
- **Padding:** PKCS7
- **Encoding:** Base64
- **Key Source:** Retrieved from `tbsrencryptpass` field in desktop database

### Current Status

The encryption key is currently set to a **PLACEHOLDER** value in:
```dart
// lib/core/utils/crypto_service.dart
static const String _encryptionKey = 'YOUR_ENCRYPTION_KEY_HERE';
```

### ⚠️ ACTION REQUIRED

You need to replace this placeholder with the actual encryption key from your desktop database.

### How to Get the Encryption Key

**Option 1: Query Desktop Database**

Connect to your desktop PostgreSQL database (port 5433) and run:

```sql
-- Find the table that stores the encryption key
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND (tablename LIKE '%encrypt%' OR tablename LIKE '%code%');

-- Once you find the table, query for the encryption key
-- Example (adjust table/column names based on your schema):
SELECT tbsrencryptpass FROM <encryption_table_name> LIMIT 1;
```

**Option 2: Check Desktop Application Code**

Look for where the PowerBuilder code retrieves the encryption key:
```powerbuilder
lds_code.dataobject='ds_encript_code'
lds_code.settransobject(sqlca)
ll_code=lds_code.retrieve()
ls_encrypt=trim(lds_code.object.tbsrencryptpass[lds_code.getrow()])
```

**Option 3: Test with Sample Data**

1. Get an encrypted password from `mbstaff` table:
   ```sql
   SELECT app_username, app_pw FROM mbstaff LIMIT 1;
   ```

2. Find the plain text version (if you know a user's actual password)

3. Test different keys until decryption works correctly

### How to Set the Encryption Key

**Method 1: Hardcode (Quick Test)**

Edit `lib/core/utils/crypto_service.dart`:

```dart
static const String _encryptionKey = 'your_actual_encryption_key_here';
```

**Method 2: Environment Variable (Recommended for Production)**

1. Add to `.env` file:
   ```env
   ENCRYPTION_KEY=your_actual_encryption_key_here
   ```

2. Update `crypto_service.dart`:
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';

   static String get encryptionKey =>
       dotenv.env['ENCRYPTION_KEY'] ?? 'YOUR_ENCRYPTION_KEY_HERE';
   ```

3. Add `flutter_dotenv` dependency:
   ```yaml
   dependencies:
     flutter_dotenv: ^5.1.0
   ```

**Method 3: Runtime Configuration (Most Flexible)**

Use the existing `setEncryptionKey()` method:

```dart
import 'package:powerca_mobile/core/utils/crypto_service.dart';

// Early in app initialization (main.dart)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set encryption key from secure source
  const encryptionKey = String.fromEnvironment('ENCRYPTION_KEY');
  CryptoService.setEncryptionKey(encryptionKey);

  runApp(MyApp());
}
```

---

## How Authentication Works

### 1. User Flow

```
Splash Screen → Sign In Page → Enter Username/Password →
Authenticate → Store Session → Navigate to Dashboard
```

### 2. Authentication Process

1. **User enters credentials** on sign-in page
2. **Form validation** checks for empty fields and minimum length
3. **BLoC receives SignInRequested event** with username and password
4. **SignInUseCase** validates inputs
5. **Repository** queries Supabase `mbstaff` table:
   ```dart
   SELECT * FROM mbstaff WHERE app_username = 'username'
   ```
6. **Password verification:**
   - Get encrypted password from `app_pw` column
   - Decrypt using AES-CBC with encryption key
   - Compare decrypted password with user input
7. **User status check:**
   - Verify `active_status` is `1` or `0` (active)
8. **Session storage:**
   - Save staff data to `SharedPreferences`
9. **UI update:**
   - BLoC emits `Authenticated` state
   - Navigate to dashboard
   - Show welcome message

### 3. Password Encryption Details

The desktop encryption/decryption logic has been replicated in Dart:

```dart
// Desktop (PowerBuilder):
lblb_key = Blob(ls_encrypt, EncodingANSI!)
lblb_iv = Blob(ls_encrypt, EncodingANSI!)
lblb_encrypt = lnv_CrypterObject.SymmetricEncrypt(
    AES!, lblb_data, lblb_key,
    OperationModeCBC!, lblb_iv, PKCSPadding!
)

// Mobile (Dart):
final keyBytes = _prepareKey(encryptionKey);   // Key from encryption string
final ivBytes = _prepareIV(encryptionKey);     // IV same as key
final key = encrypt.Key(keyBytes);
final iv = encrypt.IV(ivBytes);
final encrypter = encrypt.Encrypter(
    encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7')
);
final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);
```

**Key Details:**
- **Key and IV use the same string** (from `tbsrencryptpass`)
- **Key length:** Padded or truncated to 16/24/32 bytes for AES-128/192/256
- **IV length:** Always 16 bytes (AES block size)
- **Padding:** PKCS7 (standard padding for AES)
- **Encoding:** Base64 for encrypted output

---

## Database Schema

### mbstaff Table Structure

```sql
CREATE TABLE mbstaff (
    staff_id NUMERIC PRIMARY KEY,
    app_username VARCHAR,          -- Username for login
    app_pw VARCHAR,                -- Encrypted password (Base64)
    name VARCHAR,                  -- Full name
    email VARCHAR,
    phonumber VARCHAR,
    org_id NUMERIC,
    loc_id NUMERIC,
    con_id INTEGER,
    active_status NUMERIC,         -- 1 or 0 = active, other = inactive
    stafftype NUMERIC,
    dob DATE,
    -- ... other fields
);
```

### Important Fields for Authentication

| Field | Type | Description |
|-------|------|-------------|
| `app_username` | VARCHAR | Username (case-sensitive) |
| `app_pw` | VARCHAR | AES-CBC encrypted password (Base64 encoded) |
| `active_status` | NUMERIC | User status: 1 or 0 = active, others = inactive |
| `staff_id` | NUMERIC | Unique staff identifier |
| `name` | VARCHAR | Display name for welcome messages |

---

## Testing Authentication

### 1. Test with Known Credentials

Query Supabase to find active users:

```sql
SELECT staff_id, name, app_username, active_status
FROM mbstaff
WHERE app_username IS NOT NULL
  AND app_pw IS NOT NULL
  AND active_status IN (0, 1)
LIMIT 10;
```

### 2. Test Encryption/Decryption

Create a test script to verify the encryption key works:

```dart
import 'package:powerca_mobile/core/utils/crypto_service.dart';

void testEncryption() {
  // Set your encryption key
  CryptoService.setEncryptionKey('your_key_here');

  // Get encrypted password from database
  const encryptedPassword = '&N&M$I A';  // Example from mbstaff

  // Try to decrypt
  final decrypted = CryptoService.decrypt(encryptedPassword);
  print('Decrypted: $decrypted');

  // Verify by encrypting it back
  final reEncrypted = CryptoService.encrypt(decrypted);
  print('Re-encrypted: $reEncrypted');
  print('Match: ${reEncrypted == encryptedPassword}');
}
```

### 3. Test Sign-In Flow

1. Run the app: `flutter run`
2. Navigate to Sign In page
3. Enter username and password
4. Expected behaviors:
   - **Loading indicator** appears on button
   - **Success:** Green snackbar with "Welcome, [Name]!"
   - **Failure:** Red snackbar with error message

### 4. Expected Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "User not found" | Username doesn't exist in `mbstaff` | Check username spelling |
| "Invalid password" | Password doesn't match after decryption | Verify encryption key is correct |
| "User account is inactive" | `active_status` is not 0 or 1 | Update user status in database |
| "Database error: ..." | Supabase connection issue | Check internet and Supabase credentials |

---

## Error Handling

The authentication system handles various failure scenarios:

### 1. Validation Failures

- **Empty username:** "Username is required"
- **Empty password:** "Password is required"
- **Short password:** "Password must be at least 6 characters"

### 2. Authentication Failures

- **UserNotFoundFailure:** Username doesn't exist
- **InvalidCredentialsFailure:** Password mismatch
- **InactiveUserFailure:** User account deactivated
- **NetworkFailure:** No internet connection
- **ServerFailure:** Supabase query error

### 3. Custom Error Handling

All failures extend the base `Failure` class:

```dart
// lib/core/errors/failures.dart
abstract class Failure {
  final String message;
  const Failure(this.message);
}
```

---

## Session Management

### Current Implementation

- **Storage:** `SharedPreferences` (unencrypted)
- **Data Stored:** Full staff object as JSON
- **Persistence:** Until user signs out or clears app data

### Security Considerations

⚠️ **Current Limitation:**

Session data is stored in plain text. For production, consider:

1. **Encrypt session data:**
   ```dart
   // Use flutter_secure_storage instead of SharedPreferences
   final secureStorage = FlutterSecureStorage();
   await secureStorage.write(key: 'staff_session', value: encryptedJson);
   ```

2. **Add session expiration:**
   ```dart
   // Store timestamp with session
   final sessionData = {
     'staff': staffJson,
     'expiresAt': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
   };
   ```

3. **Implement token-based auth:**
   - Generate JWT token on successful login
   - Store only token (not full staff data)
   - Refresh token before expiration

---

## Next Steps

### Required (Before Production)

1. ✅ **Set encryption key** (see "Encryption Key Setup" above)
2. ⚠️ **Create dashboard/home screen** for post-login navigation
3. ⚠️ **Test with real desktop database** credentials
4. ⚠️ **Implement secure session storage** (use `flutter_secure_storage`)
5. ⚠️ **Add session expiration** and auto-logout

### Optional Enhancements

6. Implement "Forgot Password" functionality
7. Add biometric authentication (fingerprint/face ID)
8. Implement "Remember me" checkbox
9. Add rate limiting for login attempts
10. Log authentication events for security audit
11. Support multi-factor authentication (2FA)

---

## Troubleshooting

### Problem: "Invalid password" error even with correct password

**Likely Cause:** Encryption key mismatch

**Solution:**
1. Verify encryption key matches desktop database
2. Test decryption with sample data:
   ```dart
   final decrypted = CryptoService.decrypt(encryptedPasswordFromDB);
   print('Decrypted password: $decrypted');
   ```

### Problem: App crashes on sign-in

**Likely Cause:** Missing dependency or DI not configured

**Solution:**
1. Run `flutter pub get`
2. Verify `configureDependencies()` is called in `main.dart`
3. Check console for error messages

### Problem: "User not found" but user exists in database

**Likely Cause:** Case-sensitive username mismatch

**Solution:**
- Usernames are case-sensitive
- Check exact spelling in database
- Consider adding `.toLowerCase()` to username comparison

### Problem: Navigation doesn't work after login

**Likely Cause:** Dashboard route not implemented

**Solution:**
1. Create dashboard page
2. Add route to `main.dart`:
   ```dart
   routes: {
     '/dashboard': (context) => const DashboardPage(),
   }
   ```
3. Uncomment navigation line in `sign_in_page.dart`:
   ```dart
   Navigator.pushReplacementNamed(context, '/dashboard');
   ```

---

## Security Best Practices

### DO:
✅ Use HTTPS for all Supabase connections
✅ Validate all user inputs
✅ Encrypt sensitive data in local storage
✅ Implement session timeout
✅ Log authentication attempts
✅ Use strong encryption keys (minimum 16 characters)

### DON'T:
❌ Store passwords in plain text
❌ Log sensitive data (passwords, tokens)
❌ Hardcode encryption keys in production builds
❌ Trust client-side validation alone
❌ Use weak encryption keys

---

## Support

For issues or questions:

1. Check error messages in the console
2. Review this documentation
3. Test encryption key with sample data
4. Check Supabase connection and credentials
5. Verify database schema matches expected structure

---

**Last Updated:** 2025-10-31
**Author:** Claude (AI Assistant)
**Status:** Ready for encryption key configuration
