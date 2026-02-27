import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/work_diary/domain/usecases/delete_entry_usecase.dart';

import 'get_entries_by_job_usecase_test.mocks.dart';

void main() {
  late DeleteEntryUseCase useCase;
  late MockWorkDiaryRepository mockRepository;

  setUp(() {
    mockRepository = MockWorkDiaryRepository();
    useCase = DeleteEntryUseCase(mockRepository);
  });

  const tWdId = 1;

  group('DeleteEntryUseCase', () {
    test(
      'should delete work diary entry through repository',
      () async {
        // arrange
        when(mockRepository.deleteEntry(any))
            .thenAnswer((_) async => const Right(null));

        // act
        final result = await useCase(tWdId);

        // assert
        expect(result, const Right(null));
        verify(mockRepository.deleteEntry(tWdId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Failed to delete entry');
        when(mockRepository.deleteEntry(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tWdId);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.deleteEntry(tWdId));
        verifyNoMoreInteractions(mockRepository);
      },
    );
  });
}
