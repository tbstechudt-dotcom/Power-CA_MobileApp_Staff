import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/cancel_leave_request_usecase.dart';
import '../../domain/usecases/create_leave_request_usecase.dart';
import '../../domain/usecases/get_leave_balance_usecase.dart';
import '../../domain/usecases/get_leave_requests_usecase.dart';
import 'leave_request_event.dart';
import 'leave_request_state.dart';

class LeaveRequestBloc extends Bloc<LeaveRequestEvent, LeaveRequestState> {
  final GetLeaveRequestsUseCase getLeaveRequests;
  final CreateLeaveRequestUseCase createLeaveRequest;
  final CancelLeaveRequestUseCase cancelLeaveRequest;
  final GetLeaveBalanceUseCase getLeaveBalance;

  static const int _pageSize = 20;

  LeaveRequestBloc({
    required this.getLeaveRequests,
    required this.createLeaveRequest,
    required this.cancelLeaveRequest,
    required this.getLeaveBalance,
  }) : super(LeaveRequestInitial()) {
    on<LoadLeaveRequestsEvent>(_onLoadLeaveRequests);
    on<RefreshLeaveRequestsEvent>(_onRefreshLeaveRequests);
    on<LoadMoreLeaveRequestsEvent>(_onLoadMoreLeaveRequests);
    on<FilterLeaveRequestsByStatusEvent>(_onFilterByStatus);
    on<CreateLeaveRequestEvent>(_onCreateLeaveRequest);
    on<CancelLeaveRequestEvent>(_onCancelLeaveRequest);
    on<LoadLeaveBalanceEvent>(_onLoadLeaveBalance);
  }

  Future<void> _onLoadLeaveRequests(
    LoadLeaveRequestsEvent event,
    Emitter<LeaveRequestState> emit,
  ) async {
    emit(LeaveRequestLoading());

    final result = await getLeaveRequests(
      staffId: event.staffId,
      status: event.statusFilter,
      limit: _pageSize,
      offset: 0,
    );

    result.fold(
      (failure) => emit(LeaveRequestError(failure.message)),
      (requests) {
        // Calculate status counts
        final statusCounts = _calculateStatusCounts(requests, event.statusFilter);

        emit(LeaveRequestLoaded(
          requests: requests,
          currentFilter: event.statusFilter,
          hasMore: requests.length >= _pageSize,
          statusCounts: statusCounts,
        ),);
      },
    );
  }

  Future<void> _onRefreshLeaveRequests(
    RefreshLeaveRequestsEvent event,
    Emitter<LeaveRequestState> emit,
  ) async {
    // Don't show loading spinner on refresh
    final result = await getLeaveRequests(
      staffId: event.staffId,
      status: event.statusFilter,
      limit: _pageSize,
      offset: 0,
    );

    result.fold(
      (failure) => emit(LeaveRequestError(failure.message)),
      (requests) {
        final statusCounts = _calculateStatusCounts(requests, event.statusFilter);

        emit(LeaveRequestLoaded(
          requests: requests,
          currentFilter: event.statusFilter,
          hasMore: requests.length >= _pageSize,
          statusCounts: statusCounts,
        ),);
      },
    );
  }

  Future<void> _onLoadMoreLeaveRequests(
    LoadMoreLeaveRequestsEvent event,
    Emitter<LeaveRequestState> emit,
  ) async {
    if (state is! LeaveRequestLoaded) return;

    final currentState = state as LeaveRequestLoaded;
    emit(LeaveRequestLoadingMore(
      currentRequests: currentState.requests,
      currentFilter: event.statusFilter,
    ),);

    final result = await getLeaveRequests(
      staffId: event.staffId,
      status: event.statusFilter,
      limit: _pageSize,
      offset: event.offset,
    );

    result.fold(
      (failure) => emit(LeaveRequestError(failure.message)),
      (newRequests) {
        final allRequests = [...currentState.requests, ...newRequests];
        final statusCounts = _calculateStatusCounts(allRequests, event.statusFilter);

        emit(LeaveRequestLoaded(
          requests: allRequests,
          currentFilter: event.statusFilter,
          hasMore: newRequests.length >= _pageSize,
          statusCounts: statusCounts,
          leaveBalance: currentState.leaveBalance,
        ),);
      },
    );
  }

  Future<void> _onFilterByStatus(
    FilterLeaveRequestsByStatusEvent event,
    Emitter<LeaveRequestState> emit,
  ) async {
    emit(LeaveRequestLoading());

    final result = await getLeaveRequests(
      staffId: event.staffId,
      status: event.status,
      limit: _pageSize,
      offset: 0,
    );

    result.fold(
      (failure) => emit(LeaveRequestError(failure.message)),
      (requests) {
        final statusCounts = _calculateStatusCounts(requests, event.status);

        emit(LeaveRequestLoaded(
          requests: requests,
          currentFilter: event.status,
          hasMore: requests.length >= _pageSize,
          statusCounts: statusCounts,
        ),);
      },
    );
  }

  Future<void> _onCreateLeaveRequest(
    CreateLeaveRequestEvent event,
    Emitter<LeaveRequestState> emit,
  ) async {
    emit(LeaveRequestCreating());

    final result = await createLeaveRequest(event.request);

    result.fold(
      (failure) => emit(LeaveRequestError(failure.message)),
      (createdRequest) => emit(LeaveRequestCreated(createdRequest)),
    );
  }

  Future<void> _onCancelLeaveRequest(
    CancelLeaveRequestEvent event,
    Emitter<LeaveRequestState> emit,
  ) async {
    emit(LeaveRequestCancelling());

    final result = await cancelLeaveRequest(event.leaId);

    result.fold(
      (failure) => emit(LeaveRequestError(failure.message)),
      (_) {
        emit(LeaveRequestCancelled());
        // Reload leave requests
        add(LoadLeaveRequestsEvent(
          staffId: event.staffId,
          statusFilter: event.currentFilter,
        ),);
      },
    );
  }

  Future<void> _onLoadLeaveBalance(
    LoadLeaveBalanceEvent event,
    Emitter<LeaveRequestState> emit,
  ) async {
    final result = await getLeaveBalance(event.staffId);

    result.fold(
      (failure) => emit(LeaveRequestError(failure.message)),
      (balance) {
        if (state is LeaveRequestLoaded) {
          final currentState = state as LeaveRequestLoaded;
          emit(currentState.copyWith(leaveBalance: balance));
        } else {
          emit(LeaveBalanceLoaded(balance));
        }
      },
    );
  }

  Map<String, int> _calculateStatusCounts(
    List requests,
    String? currentFilter,
  ) {
    // Return simple counts - in real app, would query DB for accurate counts
    return {
      'All': requests.length,
      'P': requests.where((r) => r.approvalStatus == 'P').length,
      'A': requests.where((r) => r.approvalStatus == 'A').length,
      'R': requests.where((r) => r.approvalStatus == 'R').length,
      'C': requests.where((r) => r.approvalStatus == 'C').length,
    };
  }
}
