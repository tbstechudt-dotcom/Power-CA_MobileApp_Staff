import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/staff.dart';
import '../repositories/auth_repository.dart';

/// Get Current Staff Use Case
///
/// Retrieves the currently authenticated staff member
class GetCurrentStaffUseCase {
  final AuthRepository repository;

  GetCurrentStaffUseCase(this.repository);

  /// Execute get current staff
  Future<Either<Failure, Staff?>> call() async {
    return await repository.getCurrentStaff();
  }
}
