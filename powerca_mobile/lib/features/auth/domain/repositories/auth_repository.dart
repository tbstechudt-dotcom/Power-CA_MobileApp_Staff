import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/staff.dart';

/// Authentication Repository Interface
///
/// Defines the contract for authentication operations
abstract class AuthRepository {
  /// Sign in with username and password
  ///
  /// Authenticates against mbstaff table in Supabase
  /// Returns [Staff] on success or [Failure] on error
  Future<Either<Failure, Staff>> signIn({
    required String username,
    required String password,
  });

  /// Sign out the current user
  Future<Either<Failure, void>> signOut();

  /// Get currently logged in staff
  Future<Either<Failure, Staff?>> getCurrentStaff();

  /// Check if user is signed in
  Future<bool> isSignedIn();

  /// Save staff session
  Future<Either<Failure, void>> saveStaffSession(Staff staff);

  /// Clear staff session
  Future<Either<Failure, void>> clearStaffSession();

  /// Validate if current session is still active on this device
  /// Returns error message if session was invalidated by another device login
  Future<String?> validateSession();

  /// Check if there's an existing session for a staff on another device
  /// Returns session info if exists, null otherwise
  Future<Map<String, dynamic>?> checkExistingSession(int staffId);

  /// Create a login request for permission-based authentication
  /// Returns the request ID if created
  Future<int?> createLoginRequest(int staffId);

  /// Wait for login request approval from the other device
  /// Returns: 'approved', 'denied', 'expired', or 'error'
  Future<String> waitForLoginApproval(int requestId);

  /// Cancel a pending login request
  Future<void> cancelLoginRequest(int requestId);

  /// Register this device as the active session for the staff
  /// Call this AFTER successful authentication and permission approval (if needed)
  Future<bool> registerDeviceSession(int staffId);
}
