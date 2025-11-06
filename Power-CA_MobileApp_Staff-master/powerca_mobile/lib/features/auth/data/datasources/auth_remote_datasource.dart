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
      // Call Supabase Edge Function for server-side authentication
      // Password decryption happens on backend with secure encryption key
      final response = await supabaseClient.functions.invoke(
        'auth-login',
        body: {
          'username': username,
          'password': password,
        },
      );

      // Check for error response
      if (response.status != 200) {
        final error = response.data['error'] ?? 'Authentication failed';
        throw Exception(error);
      }

      // Parse successful response
      final data = response.data;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Authentication failed');
      }

      // Extract staff data from response
      final staffData = data['staff'] as Map<String, dynamic>;

      // Create and return staff model
      return StaffModel.fromJson(staffData);
    } on FunctionException catch (e) {
      throw Exception('Backend error: ${e.details}');
    } catch (e) {
      rethrow;
    }
  }
}
