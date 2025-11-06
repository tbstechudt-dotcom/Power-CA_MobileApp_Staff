import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:powerca_mobile/features/jobs/domain/usecases/get_jobs_count_by_status_usecase.dart';

import 'get_jobs_usecase_test.mocks.dart';

@GenerateMocks([JobRepository])
void main() {
  late GetJobsCountByStatusUseCase useCase;
  late MockJobRepository mockRepository;

  setUp(() {
    mockRepository = MockJobRepository();
    useCase = GetJobsCountByStatusUseCase(mockRepository);
  });

  const tStaffId = 1;

  final tStatusCounts = {
    'All': 50,
    'Waiting': 10,
    'Planning': 15,
    'Progress': 12,
    'Work Done': 8,
    'Delivery': 3,
    'Closed': 2,
  };

  group('GetJobsCountByStatusUseCase', () {
    test(
      'should get job counts by status from repository',
      () async {
        // arrange
        when(mockRepository.getJobsCountByStatus(any))
            .thenAnswer((_) async => Right(tStatusCounts));

        // act
        final result = await useCase(tStaffId);

        // assert
        expect(result, Right(tStatusCounts));
        verify(mockRepository.getJobsCountByStatus(tStaffId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Server error');
        when(mockRepository.getJobsCountByStatus(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tStaffId);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.getJobsCountByStatus(tStaffId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return counts for all status categories',
      () async {
        // arrange
        when(mockRepository.getJobsCountByStatus(any))
            .thenAnswer((_) async => Right(tStatusCounts));

        // act
        final result = await useCase(tStaffId);

        // assert
        result.fold(
          (failure) => fail('Should return counts'),
          (counts) {
            expect(counts, isA<Map<String, int>>());
            expect(counts.containsKey('All'), true);
            expect(counts.containsKey('Waiting'), true);
            expect(counts.containsKey('Planning'), true);
            expect(counts.containsKey('Progress'), true);
            expect(counts.containsKey('Work Done'), true);
            expect(counts.containsKey('Delivery'), true);
            expect(counts.containsKey('Closed'), true);
          },
        );
      },
    );
  });
}
