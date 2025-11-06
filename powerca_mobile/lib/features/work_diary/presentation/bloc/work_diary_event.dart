import 'package:equatable/equatable.dart';

import '../../domain/entities/work_diary_entry.dart';

abstract class WorkDiaryEvent extends Equatable {
  const WorkDiaryEvent();

  @override
  List<Object?> get props => [];
}

class LoadEntriesEvent extends WorkDiaryEvent {
  final int jobId;
  final int? staffId;

  const LoadEntriesEvent({
    required this.jobId,
    this.staffId,
  });

  @override
  List<Object?> get props => [jobId, staffId];
}

class RefreshEntriesEvent extends WorkDiaryEvent {
  final int jobId;
  final int? staffId;

  const RefreshEntriesEvent({
    required this.jobId,
    this.staffId,
  });

  @override
  List<Object?> get props => [jobId, staffId];
}

class LoadMoreEntriesEvent extends WorkDiaryEvent {
  final int jobId;
  final int offset;

  const LoadMoreEntriesEvent({
    required this.jobId,
    required this.offset,
  });

  @override
  List<Object?> get props => [jobId, offset];
}

class AddEntryEvent extends WorkDiaryEvent {
  final WorkDiaryEntry entry;

  const AddEntryEvent(this.entry);

  @override
  List<Object?> get props => [entry];
}

class UpdateEntryEvent extends WorkDiaryEvent {
  final WorkDiaryEntry entry;

  const UpdateEntryEvent(this.entry);

  @override
  List<Object?> get props => [entry];
}

class DeleteEntryEvent extends WorkDiaryEvent {
  final int wdId;
  final int jobId;

  const DeleteEntryEvent({
    required this.wdId,
    required this.jobId,
  });

  @override
  List<Object?> get props => [wdId, jobId];
}

class LoadTotalHoursEvent extends WorkDiaryEvent {
  final int jobId;

  const LoadTotalHoursEvent(this.jobId);

  @override
  List<Object?> get props => [jobId];
}
