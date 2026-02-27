import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/work_diary_entry.dart';
import '../../domain/repositories/work_diary_repository.dart';
import '../datasources/work_diary_remote_datasource.dart';
import '../models/work_diary_entry_model.dart';

class WorkDiaryRepositoryImpl implements WorkDiaryRepository {
  final WorkDiaryRemoteDataSource remoteDataSource;

  WorkDiaryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<WorkDiaryEntry>>> getEntriesByJob({
    required int jobId,
    int? limit,
    int? offset,
  }) async {
    try {
      final entries = await remoteDataSource.getEntriesByJob(
        jobId: jobId,
        limit: limit,
        offset: offset,
      );
      return Right(entries.map((e) => e.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<WorkDiaryEntry>>> getEntriesByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
  }) async {
    try {
      final entries = await remoteDataSource.getEntriesByStaff(
        staffId: staffId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
        offset: offset,
      );
      return Right(entries.map((e) => e.toEntity()).toList());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WorkDiaryEntry>> getEntryById(int wdId) async {
    try {
      final entry = await remoteDataSource.getEntryById(wdId);
      return Right(entry.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WorkDiaryEntry>> addEntry(WorkDiaryEntry entry) async {
    try {
      final model = WorkDiaryEntryModel(
        wdId: entry.wdId,
        jobId: entry.jobId,
        jobReference: entry.jobReference,
        taskName: entry.taskName,
        staffId: entry.staffId,
        date: entry.date,
        hoursWorked: entry.hoursWorked,
        notes: entry.notes,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );

      final result = await remoteDataSource.addEntry(model);
      return Right(result.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WorkDiaryEntry>> updateEntry(
    WorkDiaryEntry entry,
  ) async {
    try {
      final model = WorkDiaryEntryModel(
        wdId: entry.wdId,
        jobId: entry.jobId,
        jobReference: entry.jobReference,
        taskName: entry.taskName,
        staffId: entry.staffId,
        date: entry.date,
        hoursWorked: entry.hoursWorked,
        notes: entry.notes,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );

      final result = await remoteDataSource.updateEntry(model);
      return Right(result.toEntity());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEntry(int wdId) async {
    try {
      await remoteDataSource.deleteEntry(wdId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalHoursByJob(int jobId) async {
    try {
      final total = await remoteDataSource.getTotalHoursByJob(jobId);
      return Right(total);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalHoursByStaff({
    required int staffId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final total = await remoteDataSource.getTotalHoursByStaff(
        staffId: staffId,
        startDate: startDate,
        endDate: endDate,
      );
      return Right(total);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
