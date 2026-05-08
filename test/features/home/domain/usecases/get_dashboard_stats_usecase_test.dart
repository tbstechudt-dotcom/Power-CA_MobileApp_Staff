import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/home/domain/entities/dashboard_stats.dart';
import 'package:powerca_mobile/features/home/domain/repositories/home_repository.dart';
import 'package:powerca_mobile/features/home/domain/usecases/get_dashboard_stats_usecase.dart';

import 'get_dashboard_stats_usecase_test.mocks.dart';

@GenerateMocks([HomeRepository])
void main() {
  late GetDashboardStatsUseCase useCase;
  late MockHomeRepository mockRepository;

  setUp(() {
    mockRepository = MockHomeRepository();
    useCase = GetDashboardStatsUseCase(mockRepository);
  });

  const tStaffId = 1;

  const tStats = DashboardStats(
    activeJobsCount: 15,
    pendingTasksCount: 42,
    hoursWorkedThisWeek: 38.5,
    upcomingRemindersCount: 5,
    pendingLeaveRequestsCount: 2,
  );

  group('GetDashboardStatsUseCase', () {
    test(
      'should get dashboard stats from repository when called',
      () async {
        // arrange
        when(mockRepository.getDashboardStats(any))
            .thenAnswer((_) async => const Right(tStats));

        // act
        final result = await useCase(tStaffId);

        // assert
        expect(result, const Right(tStats));
        verify(mockRepository.getDashboardStats(tStaffId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Server error');
        when(mockRepository.getDashboardStats(any))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tStaffId);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.getDashboardStats(tStaffId));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return stats with correct data types',
      () async {
        // arrange
        when(mockRepository.getDashboardStats(any))
            .thenAnswer((_) async => const Right(tStats));

        // act
        final result = await useCase(tStaffId);

        // assert
        result.fold(
          (failure) => fail('Should return stats'),
          (stats) {
            expect(stats, isA<DashboardStats>());
            expect(stats.activeJobsCount, isA<int>());
            expect(stats.pendingTasksCount, isA<int>());
            expect(stats.hoursWorkedThisWeek, isA<double>());
            expect(stats.upcomingRemindersCount, isA<int>());
            expect(stats.pendingLeaveRequestsCount, isA<int>());
          },
        );
      },
    );

    test(
      'should handle zero counts correctly',
      () async {
        // arrange
        const zeroStats = DashboardStats(
          activeJobsCount: 0,
          pendingTasksCount: 0,
          hoursWorkedThisWeek: 0.0,
          upcomingRemindersCount: 0,
          pendingLeaveRequestsCount: 0,
        );
        when(mockRepository.getDashboardStats(any))
            .thenAnswer((_) async => const Right(zeroStats));

        // act
        final result = await useCase(tStaffId);

        // assert
        result.fold(
          (failure) => fail('Should return zero stats'),
          (stats) {
            expect(stats.activeJobsCount, 0);
            expect(stats.pendingTasksCount, 0);
            expect(stats.hoursWorkedThisWeek, 0.0);
            expect(stats.upcomingRemindersCount, 0);
            expect(stats.pendingLeaveRequestsCount, 0);
          },
        );
      },
    );

    test(
      'should handle large numbers correctly',
      () async {
        // arrange
        const largeStats = DashboardStats(
          activeJobsCount: 999,
          pendingTasksCount: 1500,
          hoursWorkedThisWeek: 168.0,
          upcomingRemindersCount: 100,
          pendingLeaveRequestsCount: 50,
        );
        when(mockRepository.getDashboardStats(any))
            .thenAnswer((_) async => const Right(largeStats));

        // act
        final result = await useCase(tStaffId);

        // assert
        result.fold(
          (failure) => fail('Should return large stats'),
          (stats) {
            expect(stats.activeJobsCount, 999);
            expect(stats.pendingTasksCount, 1500);
            expect(stats.hoursWorkedThisWeek, 168.0);
          },
        );
      },
    );
  });
}
