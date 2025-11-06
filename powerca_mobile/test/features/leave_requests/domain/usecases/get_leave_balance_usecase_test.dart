import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/leave_requests/domain/usecases/get_leave_balance_usecase.dart';

import 'get_leave_requests_usecase_test.mocks.dart';

void main() {
  late GetLeaveBalanceUseCase useCase;
  late MockLeaveRequestRepository mockRepository;

  setUp(() {
    mockRepository = MockLeaveRequestRepository();
    useCase = GetLeaveBalanceUseCase(mockRepository);
  });

  const tStaffId = 1;

  final tBalance = {
    'AL': 15.0,
    'SL': 10.0,
    'CL': 5.0,
    'ML': 0.0,
    'PL': 0.0,
    'UL': 0.0,
  };

  group('GetLeaveBalanceUseCase', () {
    test(
      'should get leave balance from repository',
      () async {
        // arrange
        when(mockRepository.getLeaveBalance(any))
            .thenAnswer((_) async => Right(tBalance));

        // act
        final result = await useCase(tStaffId);

        // assert
        expect(result, Right(tBalance));
        verify(mockRepository.getLeaveBalance(tStaffId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Failed to get leave balance');
        when(mockRepository.getLeaveBalance(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tStaffId);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.getLeaveBalance(tStaffId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return empty balance for new staff',
      () async {
        // arrange
        final emptyBalance = {
          'AL': 0.0,
          'SL': 0.0,
          'CL': 0.0,
          'ML': 0.0,
          'PL': 0.0,
          'UL': 0.0,
        };
        when(mockRepository.getLeaveBalance(any))
            .thenAnswer((_) async => Right(emptyBalance));

        // act
        final result = await useCase(999);

        // assert
        result.fold(
          (failure) => fail('Should return empty balance'),
          (balance) {
            expect(balance['AL'], 0.0);
            expect(balance['SL'], 0.0);
            expect(balance['CL'], 0.0);
          },
        );
      },
    );

    test(
      'should return partial leave balance',
      () async {
        // arrange
        final partialBalance = {
          'AL': 7.5,
          'SL': 10.0,
          'CL': 2.0,
          'ML': 0.0,
          'PL': 0.0,
          'UL': 0.0,
        };
        when(mockRepository.getLeaveBalance(any))
            .thenAnswer((_) async => Right(partialBalance));

        // act
        final result = await useCase(tStaffId);

        // assert
        result.fold(
          (failure) => fail('Should return partial balance'),
          (balance) {
            expect(balance['AL'], 7.5);
            expect(balance['SL'], 10.0);
            expect(balance['CL'], 2.0);
          },
        );
      },
    );

    test(
      'should handle half-day balance calculations',
      () async {
        // arrange
        final balanceWithHalfDays = {
          'AL': 14.5,
          'SL': 9.5,
          'CL': 4.5,
          'ML': 0.0,
          'PL': 0.0,
          'UL': 0.0,
        };
        when(mockRepository.getLeaveBalance(any))
            .thenAnswer((_) async => Right(balanceWithHalfDays));

        // act
        final result = await useCase(tStaffId);

        // assert
        result.fold(
          (failure) => fail('Should return balance with half days'),
          (balance) {
            expect(balance['AL'], 14.5);
            expect(balance['SL'], 9.5);
            expect(balance['CL'], 4.5);
          },
        );
      },
    );

    test(
      'should return balance for all leave types',
      () async {
        // arrange
        when(mockRepository.getLeaveBalance(any))
            .thenAnswer((_) async => Right(tBalance));

        // act
        final result = await useCase(tStaffId);

        // assert
        result.fold(
          (failure) => fail('Should return all leave types'),
          (balance) {
            expect(balance.keys.length, 6);
            expect(balance.containsKey('AL'), true);
            expect(balance.containsKey('SL'), true);
            expect(balance.containsKey('CL'), true);
            expect(balance.containsKey('ML'), true);
            expect(balance.containsKey('PL'), true);
            expect(balance.containsKey('UL'), true);
          },
        );
      },
    );
  });
}
