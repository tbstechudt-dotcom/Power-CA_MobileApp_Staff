import 'package:equatable/equatable.dart';

import '../../domain/entities/leave_request.dart';

abstract class LeaveRequestState extends Equatable {
  const LeaveRequestState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class LeaveRequestInitial extends LeaveRequestState {}

/// Loading state
class LeaveRequestLoading extends LeaveRequestState {}

/// Loaded state with leave requests
class LeaveRequestLoaded extends LeaveRequestState {
  final List<LeaveRequest> requests;
  final String? currentFilter;
  final bool hasMore;
  final Map<String, int> statusCounts;
  final Map<String, double>? leaveBalance;

  const LeaveRequestLoaded({
    required this.requests,
    this.currentFilter,
    this.hasMore = true,
    required this.statusCounts,
    this.leaveBalance,
  });

  @override
  List<Object?> get props => [
        requests,
        currentFilter,
        hasMore,
        statusCounts,
        leaveBalance,
      ];

  LeaveRequestLoaded copyWith({
    List<LeaveRequest>? requests,
    String? currentFilter,
    bool? hasMore,
    Map<String, int>? statusCounts,
    Map<String, double>? leaveBalance,
  }) {
    return LeaveRequestLoaded(
      requests: requests ?? this.requests,
      currentFilter: currentFilter ?? this.currentFilter,
      hasMore: hasMore ?? this.hasMore,
      statusCounts: statusCounts ?? this.statusCounts,
      leaveBalance: leaveBalance ?? this.leaveBalance,
    );
  }
}

/// Loading more state (pagination)
class LeaveRequestLoadingMore extends LeaveRequestState {
  final List<LeaveRequest> currentRequests;
  final String? currentFilter;

  const LeaveRequestLoadingMore({
    required this.currentRequests,
    this.currentFilter,
  });

  @override
  List<Object?> get props => [currentRequests, currentFilter];
}

/// Creating leave request
class LeaveRequestCreating extends LeaveRequestState {}

/// Leave request created successfully
class LeaveRequestCreated extends LeaveRequestState {
  final LeaveRequest request;

  const LeaveRequestCreated(this.request);

  @override
  List<Object?> get props => [request];
}

/// Cancelling leave request
class LeaveRequestCancelling extends LeaveRequestState {}

/// Leave request cancelled successfully
class LeaveRequestCancelled extends LeaveRequestState {}

/// Error state
class LeaveRequestError extends LeaveRequestState {
  final String message;

  const LeaveRequestError(this.message);

  @override
  List<Object> get props => [message];
}

/// Leave balance loaded
class LeaveBalanceLoaded extends LeaveRequestState {
  final Map<String, double> balance;

  const LeaveBalanceLoaded(this.balance);

  @override
  List<Object> get props => [balance];
}
