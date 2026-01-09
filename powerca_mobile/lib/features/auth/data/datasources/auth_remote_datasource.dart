import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/staff_model.dart';

/// Authentication Remote Data Source
///
/// Handles authentication against mbstaff table using PGP symmetric encryption.
/// Password validation is done server-side using PostgreSQL's pgp_sym_decrypt():
/// - User enters plain text password
/// - Supabase RPC function decrypts stored password and compares
/// - Passphrase 'tbstech25' is kept secure on server side
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
      // Use Supabase RPC function for secure server-side authentication
      // The function uses PGP_SYM_DECRYPT with passphrase 'tbstech25'
      final response = await supabaseClient
          .rpc(
            'authenticate_staff',
            params: {
              'p_username': username,
              'p_password': password,
            },
          )
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid username or password');
      }

      // Authentication successful - fetch complete staff data including phone number
      // The RPC function may not return all fields, so we fetch from mbstaff directly
      final staffId = response['staff_id'];
      if (staffId != null) {
        final completeStaffData = await supabaseClient
            .from('mbstaff')
            .select('staff_id, name, app_username, org_id, loc_id, con_id, email, phonumber, dob, stafftype, active_status')
            .eq('staff_id', staffId)
            .maybeSingle();

        if (completeStaffData != null) {
          return StaffModel.fromJson(completeStaffData);
        }
      }

      // Fallback to RPC response if direct query fails
      return StaffModel.fromJson(response);
    } on PostgrestException catch (e) {
      // Handle specific database errors
      if (e.message.contains('Wrong key') || e.message.contains('decrypt')) {
        throw Exception('Invalid username or password');
      }
      throw Exception('Authentication failed: ${e.message}');
    } catch (e) {
      if (e.toString().contains('Invalid username')) {
        rethrow;
      }
      throw Exception('Authentication failed. Please try again.');
    }
  }
}
