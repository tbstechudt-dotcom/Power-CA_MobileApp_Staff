import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:powerca_mobile/core/errors/failures.dart';
import 'package:powerca_mobile/features/home/domain/entities/recent_activity.dart';
import 'package:powerca_mobile/features/home/domain/usecases/get_recent_activities_usecase.dart';

import 'get_dashboard_stats_usecase_test.mocks.dart';

void main() {
  late GetRecentActivitiesUseCase useCase;
  late MockHomeRepository mockRepository;

  setUp(() {
    mockRepository = MockHomeRepository();
    useCase = GetRecentActivitiesUseCase(mockRepository);
  });

  const tStaffId = 1;
  const tLimit = 10;

  final tActivities = [
    RecentActivity(
      id: '1',
      type: 'job',
      title: 'Job Updated',
      subtitle: 'Audit Planning status changed to In Progress',
      timestamp: DateTime(2025, 11, 1, 10, 30),
      status: 'updated',
    ),
    RecentActivity(
      id: '2',
      type: 'task',
      title: 'Task Completed',
      subtitle: 'Completed review task',
      timestamp: DateTime(2025, 11, 1, 9, 15),
      status: 'completed',
    ),
    RecentActivity(
      id: '3',
      type: 'work_diary',
      title: 'Hours Logged',
      subtitle: 'Logged 2.5 hours on Audit Planning',
      timestamp: DateTime(2025, 10, 31, 16, 45),
    ),
  ];

  group('GetRecentActivitiesUseCase', () {
    test(
      'should get recent activities from repository when called',
      () async {
        // arrange
        when(mockRepository.getRecentActivities(any, limit: anyNamed('limit')))
            .thenAnswer((_) async => Right(tActivities));

        // act
        final result = await useCase(tStaffId, limit: tLimit);

        // assert
        expect(result, Right(tActivities));
        verify(mockRepository.getRecentActivities(tStaffId, limit: tLimit));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should return failure when repository call fails',
      () async {
        // arrange
        const tFailure = ServerFailure('Server error');
        when(mockRepository.getRecentActivities(any, limit: anyNamed('limit')))
            .thenAnswer((_) async => const Left(tFailure));

        // act
        final result = await useCase(tStaffId, limit: tLimit);

        // assert
        expect(result, const Left(tFailure));
        verify(mockRepository.getRecentActivities(tStaffId, limit: tLimit));
        verifyNoMoreInteractions(mockRepository);
      },
    );

    test(
      'should use default limit when not provided',
      () async {
        // arrange
        when(mockRepository.getRecentActivities(any, limit: 10))
            .thenAnswer((_) async => Right(tActivities));

        // act
        final result = await useCase(tStaffId);

        // assert
        expect(result, Right(tActivities));
        verify(mockRepository.getRecentActivities(tStaffId, limit: 10));
      },
    );

    test(
      'should return empty list when no activities exist',
      () async {
        // arrange
        when(mockRepository.getRecentActivities(any, limit: anyNamed('limit')))
            .thenAnswer((_) async => const Right([]));

        // act
        final result = await useCase(tStaffId, limit: tLimit);

        // assert
        result.fold(
          (failure) => fail('Should return empty list'),
          (activities) {
            expect(activities, isEmpty);
            expect(activities, isA<List<RecentActivity>>());
          },
        );
      },
    );

    test(
      'should return activities sorted by timestamp',
      () async {
        // arrange
        when(mockRepository.getRecentActivities(any, limit: anyNamed('limit')))
            .thenAnswer((_) async => Right(tActivities));

        // act
        final result = await useCase(tStaffId, limit: tLimit);

        // assert
        result.fold(
          (failure) => fail('Should return activities'),
          (activities) {
            expect(activities.length, 3);
            // Verify first activity is most recent
            expect(
              activities[0].timestamp.isAfter(activities[1].timestamp),
              true,
            );
            expect(
              activities[1].timestamp.isAfter(activities[2].timestamp),
              true,
            );
          },
        );
      },
    );

    test(
      'should return activities with correct data types',
      () async {
        // arrange
        when(mockRepository.getRecentActivities(any, limit: anyNamed('limit')))
            .thenAnswer((_) async => Right(tActivities));

        // act
        final result = await useCase(tStaffId, limit: tLimit);

        // assert
        result.fold(
          (failure) => fail('Should return activities'),
          (activities) {
            for (final activity in activities) {
              expect(activity, isA<RecentActivity>());
              expect(activity.id, isA<String>());
              expect(activity.type, isA<String>());
              expect(activity.title, isA<String>());
              expect(activity.timestamp, isA<DateTime>());
            }
          },
        );
      },
    );

    test(
      'should handle different activity types',
      () async {
        // arrange
        final diverseActivities = [
          RecentActivity(
            id: '1',
            type: 'job',
            title: 'Job Updated',
            subtitle: 'Status changed',
            timestamp: DateTime.now(),
          ),
          RecentActivity(
            id: '2',
            type: 'task',
            title: 'Task Completed',
            subtitle: 'Task done',
            timestamp: DateTime.now(),
          ),
          RecentActivity(
            id: '3',
            type: 'reminder',
            title: 'Reminder',
            subtitle: 'Upcoming deadline',
            timestamp: DateTime.now(),
          ),
          RecentActivity(
            id: '4',
            type: 'work_diary',
            title: 'Hours Logged',
            subtitle: 'Logged work hours',
            timestamp: DateTime.now(),
          ),
        ];

        when(mockRepository.getRecentActivities(any, limit: anyNamed('limit')))
            .thenAnswer((_) async => Right(diverseActivities));

        // act
        final result = await useCase(tStaffId, limit: tLimit);

        // assert
        result.fold(
          (failure) => fail('Should return diverse activities'),
          (activities) {
            expect(activities.length, 4);
            expect(
              activities.map((a) => a.type).toSet(),
              {'job', 'task', 'reminder', 'work_diary'},
            );
          },
        );
      },
    );
  });
}
