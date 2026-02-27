import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

/// Sign Out Use Case
///
/// Handles the business logic for user sign out
class SignOutUseCase {
  final AuthRepository repository;

  SignOutUseCase(this.repository);

  /// Execute sign out
  Future<Either<Failure, void>> call() async {
    return await repository.signOut();
  }
}
