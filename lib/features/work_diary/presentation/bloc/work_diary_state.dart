import 'package:equatable/equatable.dart';

import '../../domain/entities/work_diary_entry.dart';

abstract class WorkDiaryState extends Equatable {
  const WorkDiaryState();

  @override
  List<Object?> get props => [];
}

class WorkDiaryInitial extends WorkDiaryState {}

class WorkDiaryLoading extends WorkDiaryState {}

class WorkDiaryLoaded extends WorkDiaryState {
  final List<WorkDiaryEntry> entries;
  final double totalHours;
  final bool hasMore;

  const WorkDiaryLoaded({
    required this.entries,
    required this.totalHours,
    this.hasMore = true,
  });

  @override
  List<Object?> get props => [entries, totalHours, hasMore];

  WorkDiaryLoaded copyWith({
    List<WorkDiaryEntry>? entries,
    double? totalHours,
    bool? hasMore,
  }) {
    return WorkDiaryLoaded(
      entries: entries ?? this.entries,
      totalHours: totalHours ?? this.totalHours,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class WorkDiaryLoadingMore extends WorkDiaryState {
  final List<WorkDiaryEntry> currentEntries;
  final double totalHours;

  const WorkDiaryLoadingMore({
    required this.currentEntries,
    required this.totalHours,
  });

  @override
  List<Object?> get props => [currentEntries, totalHours];
}

class WorkDiaryError extends WorkDiaryState {
  final String message;

  const WorkDiaryError(this.message);

  @override
  List<Object?> get props => [message];
}

class WorkDiaryEntryAdded extends WorkDiaryState {
  final WorkDiaryEntry entry;

  const WorkDiaryEntryAdded(this.entry);

  @override
  List<Object?> get props => [entry];
}

class WorkDiaryEntryUpdated extends WorkDiaryState {
  final WorkDiaryEntry entry;

  const WorkDiaryEntryUpdated(this.entry);

  @override
  List<Object?> get props => [entry];
}

class WorkDiaryEntryDeleted extends WorkDiaryState {
  final int wdId;

  const WorkDiaryEntryDeleted(this.wdId);

  @override
  List<Object?> get props => [wdId];
}
