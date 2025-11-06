import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/leave_request.dart';
import '../repositories/leave_request_repository.dart';

/// Create Leave Request Use Case
/// Creates a new leave request for a staff member
class CreateLeaveRequestUseCase {
  final LeaveRequestRepository repository;

  CreateLeaveRequestUseCase(this.repository);

  Future<Either<Failure, LeaveRequest>> call(LeaveRequest request) async {
    return await repository.createLeaveRequest(request);
  }
}
