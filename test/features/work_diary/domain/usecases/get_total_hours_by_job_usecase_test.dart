import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/work_diary/domain/usecases/get_total_hours_by_job_usecase.dart';

import 'get_entries_by_job_usecase_test.mocks.dart';

void main() {
  late GetTotalHoursByJobUseCase useCase;
  late MockWorkDiaryRepository mockRepository;

  setUp(() {
    mockRepository = MockWorkDiaryRepository();
    useCase = GetTotalHoursByJobUseCase(mockRepository);
  });

  const tJobId = 1;
  const tTotalHours = 12.5;

  group('GetTotalHoursByJobUseCase', () {
    test(
      'should get total hours from repository',
      () async {
        // arrange
        when(mockRepository.getTotalHoursByJob(any))
            .thenAnswer((_) async => const Right(tTotalHours));

        // act
        final result = await useCase(tJobId);

        // assert
        expect(result, const Right(tTotalHours));
        verify(mockRepository.getTotalHoursByJob(tJobId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Failed to get total hours');
        when(mockRepository.getTotalHoursByJob(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tJobId);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.getTotalHoursByJob(tJobId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return 0.0 when no entries exist',
      () async {
        // arrange
        when(mockRepository.getTotalHoursByJob(any))
            .thenAnswer((_) async => const Right(0.0));

        // act
        final result = await useCase(tJobId);

        // assert
        expect(result, const Right(0.0));
      },
    );
  });
}
