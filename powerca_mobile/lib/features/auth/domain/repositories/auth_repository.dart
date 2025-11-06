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
}
