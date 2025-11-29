import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_model.dart';

/// Authentication Remote Data Source
///
/// Handles authentication via Supabase Edge Function (server-side)
/// Encryption key never leaves the backend!
abstract class AuthRemoteDataSource {
  /// Authenticate user with username and password
  ///
  /// Calls backend Edge Function which handles password decryption securely
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
      // TEMPORARY: Direct database authentication for testing
      // TODO: Replace with Edge Function call when deployed

      // Query mbstaff table for user with matching username
      final response = await supabaseClient
          .from('mbstaff')
          .select()
          .eq('app_username', username)
          .maybeSingle();

      if (response == null) {
        throw Exception('User not found');
      }

      // Check if user is active
      // active_status: 0 = active, 1 = inactive
      if (response['active_status'] != 0) {
        throw Exception('User account is inactive');
      }

      // TEMPORARY: For testing, accept any password
      // In production, this should validate encrypted password via Edge Function

      // Create and return staff model
      return StaffModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
