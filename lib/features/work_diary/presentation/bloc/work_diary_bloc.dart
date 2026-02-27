import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/add_entry_usecase.dart';
import '../../domain/usecases/delete_entry_usecase.dart';
import '../../domain/usecases/get_entries_by_job_usecase.dart';
import '../../domain/usecases/get_total_hours_by_job_usecase.dart';
import '../../domain/usecases/update_entry_usecase.dart';
import 'work_diary_event.dart';
import 'work_diary_state.dart';

class WorkDiaryBloc extends Bloc<WorkDiaryEvent, WorkDiaryState> {
  final GetEntriesByJobUseCase getEntriesByJob;
  final AddEntryUseCase addEntry;
  final UpdateEntryUseCase updateEntry;
  final DeleteEntryUseCase deleteEntry;
  final GetTotalHoursByJobUseCase getTotalHoursByJob;

  WorkDiaryBloc({
    required this.getEntriesByJob,
    required this.addEntry,
    required this.updateEntry,
    required this.deleteEntry,
    required this.getTotalHoursByJob,
  }) : super(WorkDiaryInitial()) {
    on<LoadEntriesEvent>(_onLoadEntries);
    on<RefreshEntriesEvent>(_onRefreshEntries);
    on<LoadMoreEntriesEvent>(_onLoadMoreEntries);
    on<AddEntryEvent>(_onAddEntry);
    on<UpdateEntryEvent>(_onUpdateEntry);
    on<DeleteEntryEvent>(_onDeleteEntry);
    on<LoadTotalHoursEvent>(_onLoadTotalHours);
  }

  Future<void> _onLoadEntries(
    LoadEntriesEvent event,
    Emitter<WorkDiaryState> emit,
  ) async {
    emit(WorkDiaryLoading());

    // Load entries
    final entriesResult = await getEntriesByJob(
      jobId: event.jobId,
      limit: 20,
      offset: 0,
    );

    // Load total hours
    final totalHoursResult = await getTotalHoursByJob(event.jobId);

    await entriesResult.fold(
      (failure) async {
        emit(WorkDiaryError(failure.message));
      },
      (entries) async {
        final totalHours = totalHoursResult.fold(
          (failure) => 0.0,
          (hours) => hours,
        );

        emit(WorkDiaryLoaded(
          entries: entries,
          totalHours: totalHours,
          hasMore: entries.length >= 20,
        ),);
      },
    );
  }

  Future<void> _onRefreshEntries(
    RefreshEntriesEvent event,
    Emitter<WorkDiaryState> emit,
  ) async {
    // Load entries
    final entriesResult = await getEntriesByJob(
      jobId: event.jobId,
      limit: 20,
      offset: 0,
    );

    // Load total hours
    final totalHoursResult = await getTotalHoursByJob(event.jobId);

    await entriesResult.fold(
      (failure) async {
        emit(WorkDiaryError(failure.message));
      },
      (entries) async {
        final totalHours = totalHoursResult.fold(
          (failure) => 0.0,
          (hours) => hours,
        );

        emit(WorkDiaryLoaded(
          entries: entries,
          totalHours: totalHours,
          hasMore: entries.length >= 20,
        ),);
      },
    );
  }

  Future<void> _onLoadMoreEntries(
    LoadMoreEntriesEvent event,
    Emitter<WorkDiaryState> emit,
  ) async {
    if (state is! WorkDiaryLoaded) return;

    final currentState = state as WorkDiaryLoaded;
    emit(WorkDiaryLoadingMore(
      currentEntries: currentState.entries,
      totalHours: currentState.totalHours,
    ),);

    final result = await getEntriesByJob(
      jobId: event.jobId,
      limit: 20,
      offset: event.offset,
    );

    await result.fold(
      (failure) async {
        emit(currentState);
      },
      (newEntries) async {
        emit(WorkDiaryLoaded(
          entries: [...currentState.entries, ...newEntries],
          totalHours: currentState.totalHours,
          hasMore: newEntries.length >= 20,
        ),);
      },
    );
  }

  Future<void> _onAddEntry(
    AddEntryEvent event,
    Emitter<WorkDiaryState> emit,
  ) async {
    final result = await addEntry(event.entry);

    await result.fold(
      (failure) async {
        emit(WorkDiaryError(failure.message));
      },
      (entry) async {
        emit(WorkDiaryEntryAdded(entry));
        // Reload entries
        add(LoadEntriesEvent(jobId: entry.jobId));
      },
    );
  }

  Future<void> _onUpdateEntry(
    UpdateEntryEvent event,
    Emitter<WorkDiaryState> emit,
  ) async {
    final result = await updateEntry(event.entry);

    await result.fold(
      (failure) async {
        emit(WorkDiaryError(failure.message));
      },
      (entry) async {
        emit(WorkDiaryEntryUpdated(entry));
        // Reload entries
        add(LoadEntriesEvent(jobId: entry.jobId));
      },
    );
  }

  Future<void> _onDeleteEntry(
    DeleteEntryEvent event,
    Emitter<WorkDiaryState> emit,
  ) async {
    final result = await deleteEntry(event.wdId);

    await result.fold(
      (failure) async {
        emit(WorkDiaryError(failure.message));
      },
      (_) async {
        emit(WorkDiaryEntryDeleted(event.wdId));
        // Reload entries
        add(LoadEntriesEvent(jobId: event.jobId));
      },
    );
  }

  Future<void> _onLoadTotalHours(
    LoadTotalHoursEvent event,
    Emitter<WorkDiaryState> emit,
  ) async {
    final result = await getTotalHoursByJob(event.jobId);

    await result.fold(
      (failure) async {
        emit(WorkDiaryError(failure.message));
      },
      (totalHours) async {
        if (state is WorkDiaryLoaded) {
          final currentState = state as WorkDiaryLoaded;
          emit(currentState.copyWith(totalHours: totalHours));
        }
      },
    );
  }
}
