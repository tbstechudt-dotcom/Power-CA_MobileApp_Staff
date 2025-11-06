import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/leave_request.dart';
import '../repositories/leave_request_repository.dart';

/// Get Leave Requests Use Case
/// Retrieves leave requests for a staff member with optional filtering
class GetLeaveRequestsUseCase {
  final LeaveRequestRepository repository;

  GetLeaveRequestsUseCase(this.repository);

  Future<Either<Failure, List<LeaveRequest>>> call({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    return await repository.getLeaveRequests(
      staffId: staffId,
      status: status,
      limit: limit,
      offset: offset,
    );
  }
}
