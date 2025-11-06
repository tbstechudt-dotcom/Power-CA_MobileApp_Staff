import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/leave_request_repository.dart';

/// Cancel Leave Request Use Case
/// Cancels a pending leave request
class CancelLeaveRequestUseCase {
  final LeaveRequestRepository repository;

  CancelLeaveRequestUseCase(this.repository);

  Future<Either<Failure, void>> call(int leaId) async {
    return await repository.cancelLeaveRequest(leaId);
  }
}
