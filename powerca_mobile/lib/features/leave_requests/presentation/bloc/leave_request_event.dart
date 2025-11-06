import 'package:equatable/equatable.dart';

import '../../domain/entities/leave_request.dart';

abstract class LeaveRequestEvent extends Equatable {
  const LeaveRequestEvent();

  @override
  List<Object?> get props => [];
}

/// Load leave requests for a staff member
class LoadLeaveRequestsEvent extends LeaveRequestEvent {
  final int staffId;
  final String? statusFilter;

  const LoadLeaveRequestsEvent({
    required this.staffId,
    this.statusFilter,
  });

  @override
  List<Object?> get props => [staffId, statusFilter];
}

/// Refresh leave requests
class RefreshLeaveRequestsEvent extends LeaveRequestEvent {
  final int staffId;
  final String? statusFilter;

  const RefreshLeaveRequestsEvent({
    required this.staffId,
    this.statusFilter,
  });

  @override
  List<Object?> get props => [staffId, statusFilter];
}

/// Load more leave requests (pagination)
class LoadMoreLeaveRequestsEvent extends LeaveRequestEvent {
  final int staffId;
  final String? statusFilter;
  final int offset;

  const LoadMoreLeaveRequestsEvent({
    required this.staffId,
    this.statusFilter,
    required this.offset,
  });

  @override
  List<Object?> get props => [staffId, statusFilter, offset];
}

/// Filter leave requests by status
class FilterLeaveRequestsByStatusEvent extends LeaveRequestEvent {
  final int staffId;
  final String? status;

  const FilterLeaveRequestsByStatusEvent({
    required this.staffId,
    this.status,
  });

  @override
  List<Object?> get props => [staffId, status];
}

/// Create a new leave request
class CreateLeaveRequestEvent extends LeaveRequestEvent {
  final LeaveRequest request;

  const CreateLeaveRequestEvent(this.request);

  @override
  List<Object?> get props => [request];
}

/// Cancel a leave request
class CancelLeaveRequestEvent extends LeaveRequestEvent {
  final int leaId;
  final int staffId;
  final String? currentFilter;

  const CancelLeaveRequestEvent({
    required this.leaId,
    required this.staffId,
    this.currentFilter,
  });

  @override
  List<Object?> get props => [leaId, staffId, currentFilter];
}

/// Load leave balance
class LoadLeaveBalanceEvent extends LeaveRequestEvent {
  final int staffId;

  const LoadLeaveBalanceEvent(this.staffId);

  @override
  List<Object?> get props => [staffId];
}
