import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/work_diary/domain/entities/work_diary_entry.dart';
import 'package:powerca_mobile/features/work_diary/domain/repositories/work_diary_repository.dart';
import 'package:powerca_mobile/features/work_diary/domain/usecases/get_entries_by_job_usecase.dart';

import 'get_entries_by_job_usecase_test.mocks.dart';

@GenerateMocks([WorkDiaryRepository])
void main() {
  late GetEntriesByJobUseCase useCase;
  late MockWorkDiaryRepository mockRepository;

  setUp(() {
    mockRepository = MockWorkDiaryRepository();
    useCase = GetEntriesByJobUseCase(mockRepository);
  });

  const tJobId = 1;
  const tLimit = 20;
  const tOffset = 0;

  final tEntries = [
    WorkDiaryEntry(
      wdId: 1,
      jobId: 1,
      jobReference: 'REG53677',
      taskName: 'Audit Planning',
      staffId: 1,
      date: DateTime(2025, 11, 1),
      hoursWorked: 2.0,
      notes: 'Completed audit planning tasks',
    ),
    WorkDiaryEntry(
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

  group('GetEntriesByJobUseCase', () {
    test(
      'should get work diary entries from repository when called',
      () async {
        // arrange
        when(mockRepository.getEntriesByJob(
          jobId: anyNamed('jobId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => Right(tEntries));

        // act
        final result = await useCase(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, Right(tEntries));
        verify(mockRepository.getEntriesByJob(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        ),);
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Server error');
        when(mockRepository.getEntriesByJob(
          jobId: anyNamed('jobId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.getEntriesByJob(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        ),);
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should get all entries when limit and offset are not provided',
      () async {
        // arrange
        when(mockRepository.getEntriesByJob(
          jobId: anyNamed('jobId'),
          limit: null,
          offset: null,
        ),).thenAnswer((_) async => Right(tEntries));

        // act
        final result = await useCase(jobId: tJobId);

        // assert
        expect(result, Right(tEntries));
        verify(mockRepository.getEntriesByJob(
          jobId: tJobId,
          limit: null,
          offset: null,
        ),);
      },
    );

    test(
      'should return empty list when no entries exist',
      () async {
        // arrange
        when(mockRepository.getEntriesByJob(
          jobId: anyNamed('jobId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => const Right([]));

        // act
        final result = await useCase(
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
        verify(mockRepository.getEntriesByJob(
          jobId: tJobId,
          limit: tLimit,
          offset: tOffset,
        ),);
      },
    );
  });
}
