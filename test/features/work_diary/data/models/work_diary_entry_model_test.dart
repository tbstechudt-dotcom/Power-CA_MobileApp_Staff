import 'package:flutter_test/flutter_test.dart';

import 'package:powerca_mobile/features/work_diary/data/models/work_diary_entry_model.dart';
import 'package:powerca_mobile/features/work_diary/domain/entities/work_diary_entry.dart';

void main() {
  final tDate = DateTime(2025, 11, 1, 10, 30);
  final tCreatedAt = DateTime(2025, 11, 1, 9, 0);
  final tUpdatedAt = DateTime(2025, 11, 1, 10, 0);

  final tModel = WorkDiaryEntryModel(
    wdId: 1,
    jobId: 100,
    jobReference: 'REG53677',
    taskName: 'Audit Planning',
    staffId: 5,
    date: tDate,
    hoursWorked: 2.5,
    notes: 'Completed audit planning tasks',
    createdAt: tCreatedAt,
    updatedAt: tUpdatedAt,
  );

  group('WorkDiaryEntryModel', () {
    test('should be a subclass of WorkDiaryEntry entity', () {
      // assert
      expect(tModel, isA<WorkDiaryEntry>());
    });

    group('fromJson', () {
      test(
        'should return a valid model from complete JSON',
        () {
          // arrange
          final jsonMap = {
            'wd_id': 1,
            'job_id': 100,
            'staff_id': 5,
            'wd_date': '2025-11-01T10:30:00.000',
            'actual_hrs': 2.5,
            'wd_notes': 'Completed audit planning tasks',
            'created_at': '2025-11-01T09:00:00.000',
            'updated_at': '2025-11-01T10:00:00.000',
            'jobshead': {'job_name': 'REG53677'},
            'jobtasks': {'task_name': 'Audit Planning'},
          };

          // act
          final result = WorkDiaryEntryModel.fromJson(jsonMap);

          // assert
          expect(result.wdId, 1);
          expect(result.jobId, 100);
          expect(result.jobReference, 'REG53677');
          expect(result.taskName, 'Audit Planning');
          expect(result.staffId, 5);
          expect(result.date, tDate);
          expect(result.hoursWorked, 2.5);
          expect(result.notes, 'Completed audit planning tasks');
          expect(result.createdAt, tCreatedAt);
          expect(result.updatedAt, tUpdatedAt);
        },
      );

      test(
        'should handle JSON with null optional fields',
        () {
          // arrange
          final jsonMap = {
            'job_id': 100,
            'staff_id': 5,
            'wd_date': '2025-11-01T10:30:00.000',
            'actual_hrs': 2.5,
          };

          // act
          final result = WorkDiaryEntryModel.fromJson(jsonMap);

          // assert
          expect(result.wdId, isNull);
          expect(result.jobReference, isNull);
          expect(result.taskName, isNull);
          expect(result.notes, isNull);
          expect(result.createdAt, isNull);
          expect(result.updatedAt, isNull);
        },
      );

      test(
        'should handle JSON with null jobshead (LEFT JOIN)',
        () {
          // arrange
          final jsonMap = {
            'wd_id': 1,
            'job_id': 100,
            'staff_id': 5,
            'wd_date': '2025-11-01T10:30:00.000',
            'actual_hrs': 2.5,
            'jobshead': null,
            'jobtasks': null,
          };

          // act
          final result = WorkDiaryEntryModel.fromJson(jsonMap);

          // assert
          expect(result.jobReference, isNull);
          expect(result.taskName, isNull);
        },
      );

      test(
        'should handle zero hours worked',
        () {
          // arrange
          final jsonMap = {
            'job_id': 100,
            'staff_id': 5,
            'wd_date': '2025-11-01T10:30:00.000',
            'actual_hrs': 0.0,
          };

          // act
          final result = WorkDiaryEntryModel.fromJson(jsonMap);

          // assert
          expect(result.hoursWorked, 0.0);
        },
      );

      test(
        'should handle null actual_hrs as 0.0',
        () {
          // arrange
          final jsonMap = {
            'job_id': 100,
            'staff_id': 5,
            'wd_date': '2025-11-01T10:30:00.000',
            'actual_hrs': null,
          };

          // act
          final result = WorkDiaryEntryModel.fromJson(jsonMap);

          // assert
          expect(result.hoursWorked, 0.0);
        },
      );

      test(
        'should handle integer hours (convert to double)',
        () {
          // arrange
          final jsonMap = {
            'job_id': 100,
            'staff_id': 5,
            'wd_date': '2025-11-01T10:30:00.000',
            'actual_hrs': 3, // Integer, not double
          };

          // act
          final result = WorkDiaryEntryModel.fromJson(jsonMap);

          // assert
          expect(result.hoursWorked, 3.0);
          expect(result.hoursWorked, isA<double>());
        },
      );
    });

    group('toJson', () {
      test(
        'should return a valid JSON map with all fields',
        () {
          // act
          final result = tModel.toJson();

          // assert
          expect(result, {
            'wd_id': 1,
            'job_id': 100,
            'staff_id': 5,
            'wd_date': tDate.toIso8601String(),
            'actual_hrs': 2.5,
            'wd_notes': 'Completed audit planning tasks',
            'created_at': tCreatedAt.toIso8601String(),
            'updated_at': tUpdatedAt.toIso8601String(),
          });
        },
      );

      test(
        'should exclude null optional fields from JSON',
        () {
          // arrange
          final modelWithoutOptionals = WorkDiaryEntryModel(
            jobId: 100,
            staffId: 5,
            date: tDate,
            hoursWorked: 2.5,
          );

          // act
          final result = modelWithoutOptionals.toJson();

          // assert
          expect(result.containsKey('wd_id'), false);
          expect(result.containsKey('wd_notes'), false);
          expect(result.containsKey('created_at'), false);
          expect(result.containsKey('updated_at'), false);
          expect(result, {
            'job_id': 100,
            'staff_id': 5,
            'wd_date': tDate.toIso8601String(),
            'actual_hrs': 2.5,
          });
        },
      );

      test(
        'should not include jobReference or taskName in JSON (computed fields)',
        () {
          // act
          final result = tModel.toJson();

          // assert
          expect(result.containsKey('jobReference'), false);
          expect(result.containsKey('job_name'), false);
          expect(result.containsKey('taskName'), false);
          expect(result.containsKey('task_name'), false);
        },
      );

      test(
        'should handle zero hours worked',
        () {
          // arrange
          final modelWithZeroHours = WorkDiaryEntryModel(
            jobId: 100,
            staffId: 5,
            date: tDate,
            hoursWorked: 0.0,
          );

          // act
          final result = modelWithZeroHours.toJson();

          // assert
          expect(result['actual_hrs'], 0.0);
        },
      );
    });

    group('toEntity', () {
      test(
        'should return a WorkDiaryEntry entity with same values',
        () {
          // act
          final entity = tModel.toEntity();

          // assert
          expect(entity, isA<WorkDiaryEntry>());
          expect(entity.wdId, tModel.wdId);
          expect(entity.jobId, tModel.jobId);
          expect(entity.jobReference, tModel.jobReference);
          expect(entity.taskName, tModel.taskName);
          expect(entity.staffId, tModel.staffId);
          expect(entity.date, tModel.date);
          expect(entity.hoursWorked, tModel.hoursWorked);
          expect(entity.notes, tModel.notes);
          expect(entity.createdAt, tModel.createdAt);
          expect(entity.updatedAt, tModel.updatedAt);
        },
      );

      test(
        'should preserve null values when converting to entity',
        () {
          // arrange
          final modelWithNulls = WorkDiaryEntryModel(
            jobId: 100,
            staffId: 5,
            date: tDate,
            hoursWorked: 2.5,
          );

          // act
          final entity = modelWithNulls.toEntity();

          // assert
          expect(entity.wdId, isNull);
          expect(entity.jobReference, isNull);
          expect(entity.taskName, isNull);
          expect(entity.notes, isNull);
          expect(entity.createdAt, isNull);
          expect(entity.updatedAt, isNull);
        },
      );
    });

    group('JSON round-trip', () {
      test(
        'should maintain data integrity through fromJson -> toJson cycle',
        () {
          // arrange
          final originalJson = {
            'wd_id': 1,
            'job_id': 100,
            'staff_id': 5,
            'wd_date': '2025-11-01T10:30:00.000',
            'actual_hrs': 2.5,
            'wd_notes': 'Test notes',
            'created_at': '2025-11-01T09:00:00.000',
            'updated_at': '2025-11-01T10:00:00.000',
            'jobshead': {'job_name': 'REG53677'},
            'jobtasks': {'task_name': 'Planning'},
          };

          // act
          final model = WorkDiaryEntryModel.fromJson(originalJson);
          final resultJson = model.toJson();

          // assert
          expect(resultJson['wd_id'], originalJson['wd_id']);
          expect(resultJson['job_id'], originalJson['job_id']);
          expect(resultJson['staff_id'], originalJson['staff_id']);
          expect(resultJson['wd_date'], originalJson['wd_date']);
          expect(resultJson['actual_hrs'], originalJson['actual_hrs']);
          expect(resultJson['wd_notes'], originalJson['wd_notes']);
          expect(resultJson['created_at'], originalJson['created_at']);
          expect(resultJson['updated_at'], originalJson['updated_at']);
        },
      );
    });

    group('Edge cases', () {
      test(
        'should handle very large hours worked',
        () {
          // arrange
          const largeHours = 999.99;
          final modelWithLargeHours = WorkDiaryEntryModel(
            jobId: 100,
            staffId: 5,
            date: tDate,
            hoursWorked: largeHours,
          );

          // act
          final json = modelWithLargeHours.toJson();
          final recreated = WorkDiaryEntryModel.fromJson(json);

          // assert
          expect(recreated.hoursWorked, largeHours);
        },
      );

      test(
        'should handle fractional hours (minutes)',
        () {
          // arrange
          const fractionalHours = 1.25; // 1 hour 15 minutes
          final modelWithFractional = WorkDiaryEntryModel(
            jobId: 100,
            staffId: 5,
            date: tDate,
            hoursWorked: fractionalHours,
          );

          // act
          final json = modelWithFractional.toJson();
          final recreated = WorkDiaryEntryModel.fromJson(json);

          // assert
          expect(recreated.hoursWorked, fractionalHours);
        },
      );

      test(
        'should handle very long notes',
        () {
          // arrange
          final longNotes = 'A' * 1000; // 1000 character notes
          final modelWithLongNotes = WorkDiaryEntryModel(
            jobId: 100,
            staffId: 5,
            date: tDate,
            hoursWorked: 2.5,
            notes: longNotes,
          );

          // act
          final json = modelWithLongNotes.toJson();
          final recreated = WorkDiaryEntryModel.fromJson(json);

          // assert
          expect(recreated.notes, longNotes);
          expect(recreated.notes?.length, 1000);
        },
      );

      test(
        'should handle dates with timezone information',
        () {
          // arrange
          final dateWithTimezone = DateTime.utc(2025, 11, 1, 10, 30);
          final modelWithTimezone = WorkDiaryEntryModel(
            jobId: 100,
            staffId: 5,
            date: dateWithTimezone,
            hoursWorked: 2.5,
          );

          // act
          final json = modelWithTimezone.toJson();
          final recreated = WorkDiaryEntryModel.fromJson(json);

          // assert
          expect(recreated.date.year, dateWithTimezone.year);
          expect(recreated.date.month, dateWithTimezone.month);
          expect(recreated.date.day, dateWithTimezone.day);
          expect(recreated.date.hour, dateWithTimezone.hour);
          expect(recreated.date.minute, dateWithTimezone.minute);
        },
      );
    });
  });
}
