import 'package:equatable/equatable.dart';

import '../../domain/entities/job.dart';

/// States for the jobs feature
abstract class JobsState extends Equatable {
  const JobsState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class JobsInitial extends JobsState {}

/// Loading jobs
class JobsLoading extends JobsState {}

/// Jobs loaded successfully
class JobsLoaded extends JobsState {
  final List<Job> jobs;
  final String currentStatus;
  final Map<String, int> statusCounts;
  final bool hasMore;

  const JobsLoaded({
    required this.jobs,
    required this.currentStatus,
    required this.statusCounts,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [jobs, currentStatus, statusCounts, hasMore];

  JobsLoaded copyWith({
    List<Job>? jobs,
    String? currentStatus,
    Map<String, int>? statusCounts,
    bool? hasMore,
  }) {
    return JobsLoaded(
      jobs: jobs ?? this.jobs,
      currentStatus: currentStatus ?? this.currentStatus,
      statusCounts: statusCounts ?? this.statusCounts,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Loading more jobs (pagination)
class JobsLoadingMore extends JobsState {
  final List<Job> currentJobs;
  final String currentStatus;
  final Map<String, int> statusCounts;

  const JobsLoadingMore({
    required this.currentJobs,
    required this.currentStatus,
    required this.statusCounts,
  });

  @override
  List<Object?> get props => [currentJobs, currentStatus, statusCounts];
}

/// Error loading jobs
class JobsError extends JobsState {
  final String message;

  const JobsError(this.message);

  @override
  List<Object?> get props => [message];
}
