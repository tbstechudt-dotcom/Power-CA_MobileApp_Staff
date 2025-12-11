import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_model.dart';
import '../../../../core/utils/crypto_service.dart';

/// Authentication Remote Data Source
///
/// Handles authentication against mbstaff table using AES-CBC encrypted passwords.
/// Password validation matches the desktop PowerBuilder encryption:
/// - User enters plain text password
/// - App encrypts it using CryptoService (same algorithm as desktop)
/// - App compares encrypted value with stored app_pw in mbstaff
abstract class AuthRemoteDataSource {
  /// Authenticate user with username and password
  ///
  /// [username] - The app_username from mbstaff table
  /// [password] - Plain text password entered by user
  ///
  /// Returns StaffModel if authentication succeeds
  /// Throws Exception if user not found, inactive, or password mismatch
  Future<StaffModel> signIn({
    required String username,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;

  AuthRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<StaffModel> signIn({
    required String username,
    required String password,
  }) async {
    try {
      // Query mbstaff table for user with matching username
      final response = await supabaseClient
          .from('mbstaff')
          .select()
          .eq('app_username', username)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid username or password');
      }

      // Check if user is active
      // active_status: 0 = active, 1 = inactive
      if (response['active_status'] != 0) {
        throw Exception('User account is inactive');
      }

      // Get the stored encrypted password from database
      final storedEncryptedPassword = response['app_pw'] as String?;

      if (storedEncryptedPassword == null || storedEncryptedPassword.isEmpty) {
        throw Exception('Invalid username or password');
      }

      // Password validation strategy:
      // 1. First try: Direct comparison (if password stored as plain text)
      // 2. Second try: Encrypt input and compare with stored (if stored is encrypted)
      // 3. Third try: Decrypt stored and compare with input (alternative encryption check)

      bool isValid = false;

      // Try 1: Direct plain text comparison
      if (password == storedEncryptedPassword) {
        isValid = true;
      }

      // Try 2: Encrypt input and compare (for Base64 encoded AES passwords)
      if (!isValid) {
        try {
          final inputEncryptedPassword = CryptoService.encrypt(password);
          if (inputEncryptedPassword == storedEncryptedPassword) {
            isValid = true;
          }
        } catch (_) {
          // Encryption failed, continue to next try
        }
      }

      // Try 3: Decrypt stored and compare with plain input
      if (!isValid) {
        try {
          final decryptedStored = CryptoService.decrypt(storedEncryptedPassword);
          if (password == decryptedStored) {
            isValid = true;
          }
        } catch (_) {
          // Decryption failed, password doesn't match
        }
      }

      if (!isValid) {
        throw Exception('Invalid username or password');
      }

      // Authentication successful - return staff model
      return StaffModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
