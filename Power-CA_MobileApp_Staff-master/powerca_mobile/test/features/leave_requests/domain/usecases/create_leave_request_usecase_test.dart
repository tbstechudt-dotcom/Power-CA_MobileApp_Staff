import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/leave_requests/domain/entities/leave_request.dart';
import 'package:powerca_mobile/features/leave_requests/domain/usecases/create_leave_request_usecase.dart';

import 'get_leave_requests_usecase_test.mocks.dart';

void main() {
  late CreateLeaveRequestUseCase useCase;
  late MockLeaveRequestRepository mockRepository;

  setUp(() {
    mockRepository = MockLeaveRequestRepository();
    useCase = CreateLeaveRequestUseCase(mockRepository);
  });

  final tRequest = LeaveRequest(
    orgId: 1,
    conId: 1,
    locId: 1,
    staffId: 1,
    requestDate: DateTime(2025, 11, 1),
    fromDate: DateTime(2025, 11, 10),
    toDate: DateTime(2025, 11, 12),
    leaveType: 'AL',
    leaveRemarks: 'Annual leave for vacation',
    approvalStatus: 'P',
  );

  final tCreatedRequest = LeaveRequest(
    leaId: 1,
    orgId: 1,
    conId: 1,
    locId: 1,
    staffId: 1,
    requestDate: DateTime(2025, 11, 1),
    fromDate: DateTime(2025, 11, 10),
    toDate: DateTime(2025, 11, 12),
    leaveType: 'AL',
    leaveRemarks: 'Annual leave for vacation',
    approvalStatus: 'P',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('CreateLeaveRequestUseCase', () {
    test(
      'should create leave request through repository',
      () async {
        // arrange
        when(mockRepository.createLeaveRequest(any))
            .thenAnswer((_) async => Right(tCreatedRequest));

        // act
        final result = await useCase(tRequest);

        // assert
        expect(result, Right(tCreatedRequest));
        verify(mockRepository.createLeaveRequest(tRequest));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Failed to create leave request');
        when(mockRepository.createLeaveRequest(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tRequest);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.createLeaveRequest(tRequest));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return request with generated ID after creating',
      () async {
        // arrange
        when(mockRepository.createLeaveRequest(any))
            .thenAnswer((_) async => Right(tCreatedRequest));

        // act
        final result = await useCase(tRequest);

        // assert
        result.fold(
          (failure) => fail('Should return created request'),
          (request) {
            expect(request.leaId, isNotNull);
            expect(request.staffId, tRequest.staffId);
            expect(request.fromDate, tRequest.fromDate);
            expect(request.toDate, tRequest.toDate);
            expect(request.leaveType, tRequest.leaveType);
            expect(request.approvalStatus, 'P');
          },
        );
      },
    );

    test(
      'should create request with half-day values',
      () async {
        // arrange
        final requestWithHalfDays = LeaveRequest(
          orgId: 1,
          conId: 1,
          locId: 1,
          staffId: 1,
          requestDate: DateTime(2025, 11, 1),
          fromDate: DateTime(2025, 11, 10),
          toDate: DateTime(2025, 11, 10),
          firstHalfValue: 'AM',
          leaveType: 'AL',
          approvalStatus: 'P',
        );

        final createdWithHalfDays = LeaveRequest(
          leaId: 2,
          orgId: 1,
          conId: 1,
          locId: 1,
          staffId: 1,
          requestDate: DateTime(2025, 11, 1),
          fromDate: DateTime(2025, 11, 10),
          toDate: DateTime(2025, 11, 10),
          firstHalfValue: 'AM',
          leaveType: 'AL',
          approvalStatus: 'P',
          createdAt: DateTime.now(),
        );

        when(mockRepository.createLeaveRequest(any))
            .thenAnswer((_) async => Right(createdWithHalfDays));

        // act
        final result = await useCase(requestWithHalfDays);

        // assert
        result.fold(
          (failure) => fail('Should create half-day request'),
          (request) {
            expect(request.firstHalfValue, 'AM');
            expect(request.totalLeaveDays, 0.5);
          },
        );
      },
    );

    test(
      'should create request for different leave types',
      () async {
        // arrange
        final sickLeaveRequest = LeaveRequest(
          orgId: 1,
          conId: 1,
          locId: 1,
          staffId: 1,
          requestDate: DateTime(2025, 11, 1),
          fromDate: DateTime(2025, 11, 10),
          toDate: DateTime(2025, 11, 11),
          leaveType: 'SL',
          leaveRemarks: 'Medical leave',
          approvalStatus: 'P',
        );

        when(mockRepository.createLeaveRequest(any))
            .thenAnswer((_) async => Right(sickLeaveRequest));

        // act
        final result = await useCase(sickLeaveRequest);

        // assert
        result.fold(
          (failure) => fail('Should create sick leave request'),
          (request) {
            expect(request.leaveType, 'SL');
            expect(request.leaveTypeDisplay, 'Sick Leave');
          },
        );
      },
    );
  });
}
