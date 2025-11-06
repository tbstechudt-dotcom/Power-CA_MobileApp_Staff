import 'package:equatable/equatable.dart';

/// Events for the jobs feature
abstract class JobsEvent extends Equatable {
  const JobsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load jobs list
class LoadJobsEvent extends JobsEvent {
  final int staffId;
  final String? status;
  final int? limit;
  final int? offset;

  const LoadJobsEvent({
    required this.staffId,
    this.status,
    this.limit,
    this.offset,
  });

  @override
  List<Object?> get props => [staffId, status, limit, offset];
}

/// Event to refresh jobs list
class RefreshJobsEvent extends JobsEvent {
  final int staffId;
  final String? status;

  const RefreshJobsEvent({
    required this.staffId,
    this.status,
  });

  @override
  List<Object?> get props => [staffId, status];
}

/// Event to change status filter
class ChangeStatusFilterEvent extends JobsEvent {
  final int staffId;
  final String status;

  const ChangeStatusFilterEvent({
    required this.staffId,
    required this.status,
  });

  @override
  List<Object?> get props => [staffId, status];
}

/// Event to load more jobs (pagination)
class LoadMoreJobsEvent extends JobsEvent {
  final int staffId;
  final String? status;
  final int offset;

  const LoadMoreJobsEvent({
    required this.staffId,
    this.status,
    required this.offset,
  });

  @override
  List<Object?> get props => [staffId, status, offset];
}
