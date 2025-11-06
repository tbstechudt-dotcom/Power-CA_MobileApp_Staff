import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/leave_requests/domain/usecases/cancel_leave_request_usecase.dart';

import 'get_leave_requests_usecase_test.mocks.dart';

void main() {
  late CancelLeaveRequestUseCase useCase;
  late MockLeaveRequestRepository mockRepository;

  setUp(() {
    mockRepository = MockLeaveRequestRepository();
    useCase = CancelLeaveRequestUseCase(mockRepository);
  });

  const tLeaId = 1;

  group('CancelLeaveRequestUseCase', () {
    test(
      'should cancel leave request through repository',
      () async {
        // arrange
        when(mockRepository.cancelLeaveRequest(any))
            .thenAnswer((_) async => const Right(null));

        // act
        final result = await useCase(tLeaId);

        // assert
        expect(result, const Right(null));
        verify(mockRepository.cancelLeaveRequest(tLeaId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Failed to cancel leave request');
        when(mockRepository.cancelLeaveRequest(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tLeaId);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.cancelLeaveRequest(tLeaId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when request not found',
      () async {
        // arrange
        const tFailure = ServerFailure('Leave request not found');
        when(mockRepository.cancelLeaveRequest(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(999);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.cancelLeaveRequest(999));
      },
    );

    test(
      'should return failure when request is already approved',
      () async {
        // arrange
        const tFailure = ServerFailure('Cannot cancel approved request');
        when(mockRepository.cancelLeaveRequest(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tLeaId);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.cancelLeaveRequest(tLeaId));
      },
    );

    test(
      'should handle multiple cancellation attempts',
      () async {
        // arrange
        when(mockRepository.cancelLeaveRequest(any))
            .thenAnswer((_) async => const Right(null));

        // act
        final result1 = await useCase(tLeaId);
        final result2 = await useCase(tLeaId);

        // assert
        expect(result1, const Right(null));
        expect(result2, const Right(null));
        verify(mockRepository.cancelLeaveRequest(tLeaId)).called(2);
      },
    );
  });
}
