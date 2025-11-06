import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/staff.dart';
import '../repositories/auth_repository.dart';

/// Sign In Use Case
///
/// Handles the business logic for user authentication
class SignInUseCase {
  final AuthRepository repository;

  SignInUseCase(this.repository);

  /// Execute sign in
  ///
  /// Parameters:
  /// - [username]: Staff username from mbstaff.app_username
  /// - [password]: Plain text password to be encrypted and matched
  ///
  /// Returns [Staff] on success or [Failure] on error
  Future<Either<Failure, Staff>> call({
    required String username,
    required String password,
  }) async {
    // Validate inputs
    if (username.trim().isEmpty) {
      return const Left(ValidationFailure('Username is required'));
    }

    if (password.isEmpty) {
      return const Left(ValidationFailure('Password is required'));
    }

    // Note: No minimum password length for sign-in
    // Users should be able to log in with any existing password
    // Password strength rules only apply when creating new passwords

    // Call repository
    return await repository.signIn(
      username: username.trim(),
      password: password,
    );
  }
}
