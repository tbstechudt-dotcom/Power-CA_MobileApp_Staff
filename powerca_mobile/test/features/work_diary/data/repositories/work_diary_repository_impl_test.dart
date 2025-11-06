import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/work_diary/data/datasources/work_diary_remote_datasource.dart';
import 'package:powerca_mobile/features/work_diary/data/models/work_diary_entry_model.dart';
import 'package:powerca_mobile/features/work_diary/data/repositories/work_diary_repository_impl.dart';
import 'package:powerca_mobile/features/work_diary/domain/entities/work_diary_entry.dart';

import 'work_diary_repository_impl_test.mocks.dart';

@GenerateMocks([WorkDiaryRemoteDataSource])
void main() {
  late WorkDiaryRepositoryImpl repository;
  late MockWorkDiaryRemoteDataSource mockRemoteDataSource;

  setUp(() {
    mockRemoteDataSource = MockWorkDiaryRemoteDataSource();
    repository = WorkDiaryRepositoryImpl(remoteDataSource: mockRemoteDataSource);
  });

  group('getEntriesByJob', () {
    const tJobId = 1;
    const tLimit = 20;
    const tOffset = 0;

    final tModels = [
      WorkDiaryEntryModel(
        wdId: 1,
        jobId: 1,
        jobReference: 'REG53677',
        taskName: 'Audit Planning',
        staffId: 1,
        date: DateTime(2025, 11, 1),
        hoursWorked: 2.0,
        notes: 'Completed audit planning tasks',
      ),
      WorkDiaryEntryModel(
        wdId: 2,
        jobId: 1,
        jobReference: 'REG53677',
        taskName: 'Review',
        staffId: 1,
        date: DateTime(2025, 10, 31),
        hoursWorked: 1.5,
        notes: 'Reviewed documentation',
      ),
    ];

    test(
      'should return list of entries when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.getEntriesByJob(
          jobId: anyNamed('jobId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => tModels);

        // act
        final result = await repository.getEntriesByJob(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, isA<Right<Failure, List<WorkDiaryEntry>>>());
        result.fold(
          (failure) => fail('Should return entries'),
          (entries) {
            expect(entries.length, tModels.length);
            expect(entries[0].wdId, tModels[0].wdId);
            expect(entries[0].jobId, tModels[0].jobId);
          },
        );
        verify(mockRemoteDataSource.getEntriesByJob(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        ),);
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.getEntriesByJob(
          jobId: anyNamed('jobId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenThrow(Exception('Network error'));

        // act
        final result = await repository.getEntriesByJob(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, isA<Left<Failure, List<WorkDiaryEntry>>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('Network error'));
          },
          (entries) => fail('Should return failure'),
        );
      },
    );

    test(
      'should return empty list when no entries exist',
      () async {
        // arrange
        when(mockRemoteDataSource.getEntriesByJob(
          jobId: anyNamed('jobId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => []);

        // act
        final result = await repository.getEntriesByJob(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        result.fold(
          (failure) => fail('Should return empty list'),
          (entries) {
            expect(entries, isEmpty);
            expect(entries, isA<List<WorkDiaryEntry>>());
          },
        );
      },
    );
  });

  group('getEntriesByStaff', () {
    const tStaffId = 1;
    final tStartDate = DateTime(2025, 11, 1);
    final tEndDate = DateTime(2025, 11, 30);

    final tModels = [
      WorkDiaryEntryModel(
        wdId: 1,
        jobId: 1,
        jobReference: 'REG53677',
        taskName: 'Audit Planning',
        staffId: 1,
        date: DateTime(2025, 11, 15),
        hoursWorked: 3.5,
        notes: 'Planning session',
      ),
    ];

    test(
      'should return list of entries when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.getEntriesByStaff(
          staffId: anyNamed('staffId'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => tModels);

        // act
        final result = await repository.getEntriesByStaff(
          staffId: tStaffId,
          startDate: tStartDate,
          endDate: tEndDate,
        );

        // assert
        expect(result, isA<Right<Failure, List<WorkDiaryEntry>>>());
        result.fold(
          (failure) => fail('Should return entries'),
          (entries) {
            expect(entries.length, tModels.length);
            expect(entries[0].staffId, tStaffId);
          },
        );
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.getEntriesByStaff(
          staffId: anyNamed('staffId'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenThrow(Exception('Database error'));

        // act
        final result = await repository.getEntriesByStaff(
          staffId: tStaffId,
          startDate: tStartDate,
          endDate: tEndDate,
        );

        // assert
        expect(result, isA<Left<Failure, List<WorkDiaryEntry>>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (entries) => fail('Should return failure'),
        );
      },
    );
  });

  group('getEntryById', () {
    const tWdId = 1;

    final tModel = WorkDiaryEntryModel(
      wdId: tWdId,
      jobId: 1,
      jobReference: 'REG53677',
      taskName: 'Audit Planning',
      staffId: 1,
      date: DateTime(2025, 11, 1),
      hoursWorked: 2.5,
      notes: 'Test entry',
    );

    test(
      'should return single entry when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.getEntryById(any))
            .thenAnswer((_) async => tModel);

        // act
        final result = await repository.getEntryById(tWdId);

        // assert
        expect(result, isA<Right<Failure, WorkDiaryEntry>>());
        result.fold(
          (failure) => fail('Should return entry'),
          (entry) {
            expect(entry.wdId, tWdId);
            expect(entry.jobId, tModel.jobId);
            expect(entry.hoursWorked, tModel.hoursWorked);
          },
        );
        verify(mockRemoteDataSource.getEntryById(tWdId));
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.getEntryById(any))
            .thenThrow(Exception('Entry not found'));

        // act
        final result = await repository.getEntryById(tWdId);

        // assert
        expect(result, isA<Left<Failure, WorkDiaryEntry>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, contains('Entry not found'));
          },
          (entry) => fail('Should return failure'),
        );
      },
    );
  });

  group('addEntry', () {
    final tEntry = WorkDiaryEntry(
      jobId: 1,
      staffId: 1,
      date: DateTime(2025, 11, 1),
      hoursWorked: 3.0,
      notes: 'New entry',
    );

    final tModel = WorkDiaryEntryModel(
      wdId: 100,
      jobId: tEntry.jobId,
      jobReference: 'REG53677',
      taskName: 'Planning',
      staffId: tEntry.staffId,
      date: tEntry.date,
      hoursWorked: tEntry.hoursWorked,
      notes: tEntry.notes,
    );

    test(
      'should return created entry with ID when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.addEntry(any))
            .thenAnswer((_) async => tModel);

        // act
        final result = await repository.addEntry(tEntry);

        // assert
        expect(result, isA<Right<Failure, WorkDiaryEntry>>());
        result.fold(
          (failure) => fail('Should return entry'),
          (entry) {
            expect(entry.wdId, 100);
            expect(entry.jobId, tEntry.jobId);
            expect(entry.hoursWorked, tEntry.hoursWorked);
          },
        );
        verify(mockRemoteDataSource.addEntry(any));
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.addEntry(any))
            .thenThrow(Exception('Insert failed'));

        // act
        final result = await repository.addEntry(tEntry);

        // assert
        expect(result, isA<Left<Failure, WorkDiaryEntry>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (entry) => fail('Should return failure'),
        );
      },
    );
  });

  group('updateEntry', () {
    final tEntry = WorkDiaryEntry(
      wdId: 50,
      jobId: 1,
      staffId: 1,
      date: DateTime(2025, 11, 1),
      hoursWorked: 4.5,
      notes: 'Updated entry',
    );

    final tModel = WorkDiaryEntryModel(
      wdId: tEntry.wdId,
      jobId: tEntry.jobId,
      jobReference: 'REG53677',
      taskName: 'Planning',
      staffId: tEntry.staffId,
      date: tEntry.date,
      hoursWorked: tEntry.hoursWorked,
      notes: tEntry.notes,
    );

    test(
      'should return updated entry when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.updateEntry(any))
            .thenAnswer((_) async => tModel);

        // act
        final result = await repository.updateEntry(tEntry);

        // assert
        expect(result, isA<Right<Failure, WorkDiaryEntry>>());
        result.fold(
          (failure) => fail('Should return entry'),
          (entry) {
            expect(entry.wdId, tEntry.wdId);
            expect(entry.hoursWorked, 4.5);
            expect(entry.notes, 'Updated entry');
          },
        );
        verify(mockRemoteDataSource.updateEntry(any));
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.updateEntry(any))
            .thenThrow(Exception('Update failed'));

        // act
        final result = await repository.updateEntry(tEntry);

        // assert
        expect(result, isA<Left<Failure, WorkDiaryEntry>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (entry) => fail('Should return failure'),
        );
      },
    );
  });

  group('deleteEntry', () {
    const tWdId = 75;

    test(
      'should return Right(null) when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.deleteEntry(any))
            .thenAnswer((_) async => Future.value());

        // act
        final result = await repository.deleteEntry(tWdId);

        // assert
        expect(result, const Right(null));
        verify(mockRemoteDataSource.deleteEntry(tWdId));
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.deleteEntry(any))
            .thenThrow(Exception('Delete failed'));

        // act
        final result = await repository.deleteEntry(tWdId);

        // assert
        expect(result, isA<Left<Failure, void>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Should return failure'),
        );
      },
    );
  });

  group('getTotalHoursByJob', () {
    const tJobId = 1;
    const tTotalHours = 15.5;

    test(
      'should return total hours when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.getTotalHoursByJob(any))
            .thenAnswer((_) async => tTotalHours);

        // act
        final result = await repository.getTotalHoursByJob(tJobId);

        // assert
        expect(result, const Right(tTotalHours));
        verify(mockRemoteDataSource.getTotalHoursByJob(tJobId));
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return 0.0 when no entries exist',
      () async {
        // arrange
        when(mockRemoteDataSource.getTotalHoursByJob(any))
            .thenAnswer((_) async => 0.0);

        // act
        final result = await repository.getTotalHoursByJob(tJobId);

        // assert
        expect(result, const Right(0.0));
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.getTotalHoursByJob(any))
            .thenThrow(Exception('Query failed'));

        // act
        final result = await repository.getTotalHoursByJob(tJobId);

        // assert
        expect(result, isA<Left<Failure, double>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Should return failure'),
        );
      },
    );
  });

  group('getTotalHoursByStaff', () {
    const tStaffId = 1;
    final tStartDate = DateTime(2025, 11, 1);
    final tEndDate = DateTime(2025, 11, 30);
    const tTotalHours = 42.0;

    test(
      'should return total hours when remote datasource call succeeds',
      () async {
        // arrange
        when(mockRemoteDataSource.getTotalHoursByStaff(
          staffId: anyNamed('staffId'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),).thenAnswer((_) async => tTotalHours);

        // act
        final result = await repository.getTotalHoursByStaff(
          staffId: tStaffId,
          startDate: tStartDate,
          endDate: tEndDate,
        );

        // assert
        expect(result, const Right(tTotalHours));
        verify(mockRemoteDataSource.getTotalHoursByStaff(
          staffId: tStaffId,
          startDate: tStartDate,
          endDate: tEndDate,
        ),);
        verifyNoMoreInteractions(mockRemoteDataSource);
      },
    );

    test(
      'should return ServerFailure when remote datasource throws exception',
      () async {
        // arrange
        when(mockRemoteDataSource.getTotalHoursByStaff(
          staffId: anyNamed('staffId'),
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
        ),).thenThrow(Exception('Calculation failed'));

        // act
        final result = await repository.getTotalHoursByStaff(
          staffId: tStaffId,
          startDate: tStartDate,
          endDate: tEndDate,
        );

        // assert
        expect(result, isA<Left<Failure, double>>());
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Should return failure'),
        );
      },
    );
  });
}
