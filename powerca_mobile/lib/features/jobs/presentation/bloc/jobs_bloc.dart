import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/usecases/get_jobs_count_by_status_usecase.dart';
import '../../domain/usecases/get_jobs_usecase.dart';
import 'jobs_event.dart';
import 'jobs_state.dart';

@injectable
class JobsBloc extends Bloc<JobsEvent, JobsState> {
  final GetJobsUseCase getJobs;
  final GetJobsCountByStatusUseCase getJobsCountByStatus;

  static const int _pageSize = 20;

  JobsBloc({
    required this.getJobs,
    required this.getJobsCountByStatus,
  }) : super(JobsInitial()) {
    on<LoadJobsEvent>(_onLoadJobs);
    on<RefreshJobsEvent>(_onRefreshJobs);
    on<ChangeStatusFilterEvent>(_onChangeStatusFilter);
    on<LoadMoreJobsEvent>(_onLoadMoreJobs);
  }

  Future<void> _onLoadJobs(
    LoadJobsEvent event,
    Emitter<JobsState> emit,
  ) async {
    emit(JobsLoading());
    await _loadJobsData(
      staffId: event.staffId,
      status: event.status,
      limit: event.limit ?? _pageSize,
      offset: event.offset ?? 0,
      emit: emit,
    );
  }

  Future<void> _onRefreshJobs(
    RefreshJobsEvent event,
    Emitter<JobsState> emit,
  ) async {
    // Don't show loading indicator for refresh
    await _loadJobsData(
      staffId: event.staffId,
      status: event.status,
      limit: _pageSize,
      offset: 0,
      emit: emit,
    );
  }

  Future<void> _onChangeStatusFilter(
    ChangeStatusFilterEvent event,
    Emitter<JobsState> emit,
  ) async {
    emit(JobsLoading());
    await _loadJobsData(
      staffId: event.staffId,
      status: event.status == 'All' ? null : event.status,
      limit: _pageSize,
      offset: 0,
      emit: emit,
    );
  }

  Future<void> _onLoadMoreJobs(
    LoadMoreJobsEvent event,
    Emitter<JobsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! JobsLoaded) return;

    emit(JobsLoadingMore(
      currentJobs: currentState.jobs,
      currentStatus: currentState.currentStatus,
      statusCounts: currentState.statusCounts,
    ),);

    final jobsResult = await getJobs(
      staffId: event.staffId,
      status: event.status == 'All' ? null : event.status,
      limit: _pageSize,
      offset: event.offset,
    );

    jobsResult.fold(
      (failure) {
        // If load more fails, keep current state
        emit(currentState);
      },
      (newJobs) {
        final allJobs = [...currentState.jobs, ...newJobs];
        emit(currentState.copyWith(
          jobs: allJobs,
          hasMore: newJobs.length >= _pageSize,
        ),);
      },
    );
  }

  Future<void> _loadJobsData({
    required int staffId,
    String? status,
    required int limit,
    required int offset,
    required Emitter<JobsState> emit,
  }) async {
    // Load jobs and counts in parallel
    final jobsResult = await getJobs(
      staffId: staffId,
      status: status,
      limit: limit,
      offset: offset,
    );

    final countsResult = await getJobsCountByStatus(staffId);

    jobsResult.fold(
      (failure) => emit(JobsError(failure.message)),
      (jobs) {
        countsResult.fold(
          (failure) => emit(JobsError(failure.message)),
          (counts) => emit(
            JobsLoaded(
              jobs: jobs,
              currentStatus: status ?? 'All',
              statusCounts: counts,
              hasMore: jobs.length >= limit,
            ),
          ),
        );
      },
    );
  }
}
