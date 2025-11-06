import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/repositories/leave_request_repository.dart';
import '../datasources/leave_request_remote_datasource.dart';
import '../models/leave_request_model.dart';

/// Leave Request Repository Implementation
class LeaveRequestRepositoryImpl implements LeaveRequestRepository {
  final LeaveRequestRemoteDataSource remoteDataSource;

  LeaveRequestRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<LeaveRequest>>> getLeaveRequests({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    try {
      final requests = await remoteDataSource.getLeaveRequests(
        staffId: staffId,
        status: status,
        limit: limit,
        offset: offset,
      );
      return Right(requests.map((model) => model.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeaveRequest>> getLeaveRequestById(int leaId) async {
    try {
      final request = await remoteDataSource.getLeaveRequestById(leaId);
      return Right(request.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeaveRequest>> createLeaveRequest(
    LeaveRequest request,
  ) async {
    try {
      final model = LeaveRequestModel(
        leaId: request.leaId,
        orgId: request.orgId,
        conId: request.conId,
        locId: request.locId,
        staffId: request.staffId,
        requestDate: request.requestDate,
        fromDate: request.fromDate,
        toDate: request.toDate,
        firstHalfValue: request.firstHalfValue,
        secondHalfValue: request.secondHalfValue,
        leaveType: request.leaveType,
        leaveRemarks: request.leaveRemarks,
        createdBy: request.createdBy,
        createdDate: request.createdDate,
        approvalStatus: request.approvalStatus,
        approvedBy: request.approvedBy,
        approvedDate: request.approvedDate,
        source: request.source,
        createdAt: request.createdAt,
        updatedAt: request.updatedAt,
      );

      final result = await remoteDataSource.createLeaveRequest(model);
      return Right(result.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LeaveRequest>> updateLeaveRequest(
    LeaveRequest request,
  ) async {
    try {
      final model = LeaveRequestModel(
        leaId: request.leaId,
        orgId: request.orgId,
        conId: request.conId,
        locId: request.locId,
        staffId: request.staffId,
        requestDate: request.requestDate,
        fromDate: request.fromDate,
        toDate: request.toDate,
        firstHalfValue: request.firstHalfValue,
        secondHalfValue: request.secondHalfValue,
        leaveType: request.leaveType,
        leaveRemarks: request.leaveRemarks,
        createdBy: request.createdBy,
        createdDate: request.createdDate,
        approvalStatus: request.approvalStatus,
        approvedBy: request.approvedBy,
        approvedDate: request.approvedDate,
        source: request.source,
        createdAt: request.createdAt,
        updatedAt: request.updatedAt,
      );

      final result = await remoteDataSource.updateLeaveRequest(model);
      return Right(result.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelLeaveRequest(int leaId) async {
    try {
      await remoteDataSource.cancelLeaveRequest(leaId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getLeaveBalance(
    int staffId,
  ) async {
    try {
      final balance = await remoteDataSource.getLeaveBalance(staffId);
      return Right(balance);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
