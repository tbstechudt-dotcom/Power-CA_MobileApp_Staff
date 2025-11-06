import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/leave_request.dart';

/// Leave Request Repository Interface
/// Defines contracts for leave request data operations
abstract class LeaveRequestRepository {
  /// Get all leave requests for a staff member
  Future<Either<Failure, List<LeaveRequest>>> getLeaveRequests({
    required int staffId,
    String? status,  // Filter by approval status (P, A, R, C)
    int? limit,
    int? offset,
  });

  /// Get a single leave request by ID
  Future<Either<Failure, LeaveRequest>> getLeaveRequestById(int leaId);

  /// Create a new leave request
  Future<Either<Failure, LeaveRequest>> createLeaveRequest(
    LeaveRequest request,
  );

  /// Update an existing leave request
  Future<Either<Failure, LeaveRequest>> updateLeaveRequest(
    LeaveRequest request,
  );

  /// Cancel a leave request
  Future<Either<Failure, void>> cancelLeaveRequest(int leaId);

  /// Get leave balance for a staff member
  Future<Either<Failure, Map<String, double>>> getLeaveBalance(int staffId);
}
