import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/leave_request_repository.dart';

/// Get Leave Balance Use Case
/// Retrieves leave balance for a staff member
/// Returns a map of leave type codes to remaining days
/// Example: {'AL': 15.0, 'SL': 10.0, 'CL': 5.0}
class GetLeaveBalanceUseCase {
  final LeaveRequestRepository repository;

  GetLeaveBalanceUseCase(this.repository);

  Future<Either<Failure, Map<String, double>>> call(int staffId) async {
    return await repository.getLeaveBalance(staffId);
  }
}
