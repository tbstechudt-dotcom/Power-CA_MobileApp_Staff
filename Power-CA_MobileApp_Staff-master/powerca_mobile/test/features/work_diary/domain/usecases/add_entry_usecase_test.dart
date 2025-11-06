import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/work_diary/domain/entities/work_diary_entry.dart';
import 'package:powerca_mobile/features/work_diary/domain/usecases/add_entry_usecase.dart';

import 'get_entries_by_job_usecase_test.mocks.dart';

void main() {
  late AddEntryUseCase useCase;
  late MockWorkDiaryRepository mockRepository;

  setUp(() {
    mockRepository = MockWorkDiaryRepository();
    useCase = AddEntryUseCase(mockRepository);
  });

  final tEntry = WorkDiaryEntry(
    jobId: 1,
    jobReference: 'REG53677',
    taskName: 'Audit Planning',
    staffId: 1,
    date: DateTime(2025, 11, 1),
    hoursWorked: 2.0,
    notes: 'Completed audit planning tasks',
  );

  final tAddedEntry = WorkDiaryEntry(
    wdId: 1,
    jobId: 1,
    jobReference: 'REG53677',
    taskName: 'Audit Planning',
    staffId: 1,
    date: DateTime(2025, 11, 1),
    hoursWorked: 2.0,
    notes: 'Completed audit planning tasks',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('AddEntryUseCase', () {
    test(
      'should add work diary entry through repository',
      () async {
        // arrange
        when(mockRepository.addEntry(any))
            .thenAnswer((_) async => Right(tAddedEntry));

        // act
        final result = await useCase(tEntry);

        // assert
        expect(result, Right(tAddedEntry));
        verify(mockRepository.addEntry(tEntry));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Failed to add entry');
        when(mockRepository.addEntry(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tEntry);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.addEntry(tEntry));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return entry with generated ID after adding',
      () async {
        // arrange
        when(mockRepository.addEntry(any))
            .thenAnswer((_) async => Right(tAddedEntry));

        // act
        final result = await useCase(tEntry);

        // assert
        result.fold(
          (failure) => fail('Should return entry'),
          (entry) {
            expect(entry.wdId, isNotNull);
            expect(entry.jobId, tEntry.jobId);
            expect(entry.hoursWorked, tEntry.hoursWorked);
            expect(entry.notes, tEntry.notes);
          },
        );
      },
    );
  });
}
