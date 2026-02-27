import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/work_diary_entry.dart';

abstract class WorkDiaryRepository {
  /// Get all work diary entries for a specific job
  Future<Either<Failure, List<WorkDiaryEntry>>> getEntriesByJob({
    required int jobId,
    int? limit,
    int? offset,
  });

  /// Get all work diary entries for a specific staff member
  Future<Either<Failure, List<WorkDiaryEntry>>> getEntriesByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  });

  /// Get a single work diary entry by ID
  Future<Either<Failure, WorkDiaryEntry>> getEntryById(int wdId);

  /// Add a new work diary entry
  Future<Either<Failure, WorkDiaryEntry>> addEntry(WorkDiaryEntry entry);

  /// Update an existing work diary entry
  Future<Either<Failure, WorkDiaryEntry>> updateEntry(WorkDiaryEntry entry);

  /// Delete a work diary entry
  Future<Either<Failure, void>> deleteEntry(int wdId);

  /// Get total hours worked for a job
  Future<Either<Failure, double>> getTotalHoursByJob(int jobId);

  /// Get total hours worked by staff in a date range
  Future<Either<Failure, double>> getTotalHoursByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
  });
}
