import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/leave_requests/domain/entities/leave_request.dart';
import 'package:powerca_mobile/features/leave_requests/domain/repositories/leave_request_repository.dart';
import 'package:powerca_mobile/features/leave_requests/domain/usecases/get_leave_requests_usecase.dart';

import 'get_leave_requests_usecase_test.mocks.dart';

@GenerateMocks([LeaveRequestRepository])
void main() {
  late GetLeaveRequestsUseCase useCase;
  late MockLeaveRequestRepository mockRepository;

  setUp(() {
    mockRepository = MockLeaveRequestRepository();
    useCase = GetLeaveRequestsUseCase(mockRepository);
  });

  const tStaffId = 1;
  const tStatus = 'P';
  const tLimit = 20;
  const tOffset = 0;

  final tRequests = [
    LeaveRequest(
      leaId: 1,
      orgId: 1,
      conId: 1,
      locId: 1,
      staffId: 1,
      requestDate: DateTime(2025, 11, 1),
      fromDate: DateTime(2025, 11, 10),
      toDate: DateTime(2025, 11, 12),
      leaveType: 'AL',
      approvalStatus: 'P',
    ),
    LeaveRequest(
      leaId: 2,
      orgId: 1,
      conId: 1,
      locId: 1,
      staffId: 1,
      requestDate: DateTime(2025, 10, 25),
      fromDate: DateTime(2025, 11, 5),
      toDate: DateTime(2025, 11, 7),
      leaveType: 'SL',
      approvalStatus: 'A',
    ),
  ];

  group('GetLeaveRequestsUseCase', () {
    test(
      'should get leave requests from repository when called',
      () async {
        // arrange
        when(mockRepository.getLeaveRequests(
          staffId: anyNamed('staffId'),
          status: anyNamed('status'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => Right(tRequests));

        // act
        final result = await useCase(
          staffId: tStaffId,
          status: tStatus,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, Right(tRequests));
        verify(mockRepository.getLeaveRequests(
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
        when(mockRepository.getLeaveRequests(
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
        verify(mockRepository.getLeaveRequests(
          staffId: tStaffId,
          status: tStatus,
          limit: tLimit,
          offset: tOffset,
        ),);
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should get all requests when status is not provided',
      () async {
        // arrange
        when(mockRepository.getLeaveRequests(
          staffId: anyNamed('staffId'),
          status: null,
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => Right(tRequests));

        // act
        final result = await useCase(
          staffId: tStaffId,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        expect(result, Right(tRequests));
        verify(mockRepository.getLeaveRequests(
          staffId: tStaffId,
          status: null,
          limit: tLimit,
          offset: tOffset,
        ),);
      },
    );

    test(
      'should get all requests when limit and offset are not provided',
      () async {
        // arrange
        when(mockRepository.getLeaveRequests(
          staffId: anyNamed('staffId'),
          status: anyNamed('status'),
          limit: null,
          offset: null,
        ),).thenAnswer((_) async => Right(tRequests));

        // act
        final result = await useCase(
          staffId: tStaffId,
          status: tStatus,
        );

        // assert
        expect(result, Right(tRequests));
        verify(mockRepository.getLeaveRequests(
          staffId: tStaffId,
          status: tStatus,
          limit: null,
          offset: null,
        ),);
      },
    );

    test(
      'should return empty list when no requests exist',
      () async {
        // arrange
        when(mockRepository.getLeaveRequests(
          staffId: anyNamed('staffId'),
          status: anyNamed('status'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => const Right([]));

        // act
        final result = await useCase(
          staffId: tStaffId,
          status: tStatus,
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        result.fold(
          (failure) => fail('Should return empty list'),
          (requests) {
            expect(requests, isEmpty);
            expect(requests, isA<List<LeaveRequest>>());
          },
        );
        verify(mockRepository.getLeaveRequests(
          staffId: tStaffId,
          status: tStatus,
          limit: tLimit,
          offset: tOffset,
        ),);
      },
    );

    test(
      'should filter by pending status only',
      () async {
        // arrange
        final pendingRequests = [tRequests[0]]; // Only pending request
        when(mockRepository.getLeaveRequests(
          staffId: anyNamed('staffId'),
          status: 'P',
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        ),).thenAnswer((_) async => Right(pendingRequests));

        // act
        final result = await useCase(
          staffId: tStaffId,
          status: 'P',
          limit: tLimit,
          offset: tOffset,
        );

        // assert
        result.fold(
          (failure) => fail('Should return pending requests'),
          (requests) {
            expect(requests.length, 1);
            expect(requests[0].approvalStatus, 'P');
          },
        );
      },
    );
  });
}
