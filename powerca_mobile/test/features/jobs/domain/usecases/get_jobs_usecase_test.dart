import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/jobs/domain/entities/job.dart';
import 'package:powerca_mobile/features/jobs/domain/repositories/job_repository.dart';
import 'package:powerca_mobile/features/jobs/domain/usecases/get_jobs_usecase.dart';

import 'get_jobs_usecase_test.mocks.dart';

@GenerateMocks([JobRepository])
void main() {
  late GetJobsUseCase useCase;
  late MockJobRepository mockRepository;

  setUp(() {
    mockRepository = MockJobRepository();
    useCase = GetJobsUseCase(mockRepository);
  });

  const tStaffId = 1;
  const tStatus = 'Waiting';
  const tLimit = 20;
  const tOffset = 0;

  final tJobs = [
    const Job(
      jobId: 1,
      jobReference: 'REG53677',
      clientName: 'Umbrella Corporation Private Limited',
      jobName: 'Audit Planning',
      status: 'Waiting',
      staffId: 1,
      clientId: 100,
    ),
    const Job(
      jobId: 2,
      jobReference: 'REG23659',
      clientName: 'Umbrella Corporation Private Limited',
      jobName: 'Audit Planning',
      status: 'Planning',
      staffId: 1,
      clientId: 100,
    ),
  ];

  group('GetJobsUseCase', () {
    test(
      'should get jobs from repository when called',
      () async {
        // arrange
        when(mockRepository.getJobs(
          staffId: anyNamed('staffId'),
          status: anyNamed('status'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => Right(tJobs));

        // act
        final result = await useCase(
          staffId: tStaffId,
          status: tStatus,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, Right(tJobs));
        verify(mockRepository.getJobs(
          staffId: tStaffId,
          status: tStatus,
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
        when(mockRepository.getJobs(
          staffId: anyNamed('staffId'),
          status: anyNamed('status'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(
          staffId: tStaffId,
          status: tStatus,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.getJobs(
          staffId: tStaffId,
          status: tStatus,
          limit: tLimit,
          offset: tOffset,
        ),);
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should get all jobs when status is not provided',
      () async {
        // arrange
        when(mockRepository.getJobs(
          staffId: anyNamed('staffId'),
          status: null,
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => Right(tJobs));

        // act
        final result = await useCase(
          staffId: tStaffId,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, Right(tJobs));
        verify(mockRepository.getJobs(
          staffId: tStaffId,
          status: null,
          limit: tLimit,
          offset: tOffset,
        ),);
      },
    );

    test(
      'should use default pagination when not provided',
      () async {
        // arrange
        when(mockRepository.getJobs(
          staffId: anyNamed('staffId'),
          status: anyNamed('status'),
          limit: null,
          offset: null,
        ),).thenAnswer((_) async => Right(tJobs));

        // act
        final result = await useCase(
          staffId: tStaffId,
          status: tStatus,
        );

        // assert
        expect(result, Right(tJobs));
        verify(mockRepository.getJobs(
          staffId: tStaffId,
          status: tStatus,
          limit: null,
          offset: null,
        ),);
      },
    );
  });
}
