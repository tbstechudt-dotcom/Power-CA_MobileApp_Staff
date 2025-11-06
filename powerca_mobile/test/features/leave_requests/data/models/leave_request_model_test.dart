import 'package:flutter_test/flutter_test.dart';

import 'package:powerca_mobile/features/leave_requests/data/models/leave_request_model.dart';
import 'package:powerca_mobile/features/leave_requests/domain/entities/leave_request.dart';

void main() {
  final tRequestDate = DateTime(2025, 11, 1, 10, 0);
  final tFromDate = DateTime(2025, 11, 10);
  final tToDate = DateTime(2025, 11, 12);
  final tCreatedAt = DateTime(2025, 11, 1, 9, 0);
  final tUpdatedAt = DateTime(2025, 11, 1, 10, 0);

  final tModel = LeaveRequestModel(
    leaId: 1,
    orgId: 1,
    conId: 1,
    locId: 1,
    staffId: 5,
    requestDate: tRequestDate,
    fromDate: tFromDate,
    toDate: tToDate,
    leaveType: 'AL',
    leaveRemarks: 'Annual leave for vacation',
    approvalStatus: 'P',
    createdAt: tCreatedAt,
    updatedAt: tUpdatedAt,
  );

  group('LeaveRequestModel', () {
    test('should be a subclass of LeaveRequest entity', () {
      // assert
      expect(tModel, isA<LeaveRequest>());
    });

    group('fromJson', () {
      test(
        'should return a valid model from complete JSON',
        () {
          // arrange
          final jsonMap = {
            'learequest_id': 1,
            'org_id': 1,
            'con_id': 1,
            'loc_id': 1,
            'staff_id': 5,
            'requestdate': '2025-11-01T10:00:00.000',
            'fromdate': '2025-11-10T00:00:00.000',
            'todate': '2025-11-12T00:00:00.000',
            'fhvalue': null,
            'shvalue': null,
            'leavetype': 'AL',
            'leaveremarks': 'Annual leave for vacation',
            'createdby': null,
            'created_date': null,
            'approval_status': 'P',
            'approvedby': null,
            'approveddate': null,
            'source': 'M',
            'created_at': '2025-11-01T09:00:00.000',
            'updated_at': '2025-11-01T10:00:00.000',
          };

          // act
          final result = LeaveRequestModel.fromJson(jsonMap);

          // assert
          expect(result.leaId, 1);
          expect(result.orgId, 1);
          expect(result.conId, 1);
          expect(result.locId, 1);
          expect(result.staffId, 5);
          expect(result.requestDate, tRequestDate);
          expect(result.fromDate, tFromDate);
          expect(result.toDate, tToDate);
          expect(result.leaveType, 'AL');
          expect(result.leaveRemarks, 'Annual leave for vacation');
          expect(result.approvalStatus, 'P');
          expect(result.source, 'M');
          expect(result.createdAt, tCreatedAt);
          expect(result.updatedAt, tUpdatedAt);
        },
      );

      test(
        'should handle JSON with null optional fields',
        () {
          // arrange
          final jsonMap = {
            'org_id': 1,
            'con_id': 1,
            'loc_id': 1,
            'staff_id': 5,
            'fromdate': '2025-11-10T00:00:00.000',
            'todate': '2025-11-12T00:00:00.000',
            'leavetype': 'AL',
            'approval_status': 'P',
          };

          // act
          final result = LeaveRequestModel.fromJson(jsonMap);

          // assert
          expect(result.leaId, isNull);
          expect(result.requestDate, isNull);
          expect(result.firstHalfValue, isNull);
          expect(result.secondHalfValue, isNull);
          expect(result.leaveRemarks, isNull);
          expect(result.createdBy, isNull);
          expect(result.createdDate, isNull);
          expect(result.approvedBy, isNull);
          expect(result.approvedDate, isNull);
          expect(result.source, isNull);
          expect(result.createdAt, isNull);
          expect(result.updatedAt, isNull);
        },
      );

      test(
        'should handle half-day values',
        () {
          // arrange
          final jsonMap = {
            'org_id': 1,
            'con_id': 1,
            'loc_id': 1,
            'staff_id': 5,
            'fromdate': '2025-11-10T00:00:00.000',
            'todate': '2025-11-10T00:00:00.000',
            'fhvalue': 'AM',
            'shvalue': null,
            'leavetype': 'AL',
            'approval_status': 'P',
          };

          // act
          final result = LeaveRequestModel.fromJson(jsonMap);

          // assert
          expect(result.firstHalfValue, 'AM');
          expect(result.secondHalfValue, isNull);
        },
      );

      test(
        'should handle all leave types',
        () {
          final leaveTypes = ['AL', 'SL', 'CL', 'ML', 'PL', 'UL'];

          for (final type in leaveTypes) {
            // arrange
            final jsonMap = {
              'org_id': 1,
              'con_id': 1,
              'loc_id': 1,
              'staff_id': 5,
              'fromdate': '2025-11-10T00:00:00.000',
              'todate': '2025-11-12T00:00:00.000',
              'leavetype': type,
              'approval_status': 'P',
            };

            // act
            final result = LeaveRequestModel.fromJson(jsonMap);

            // assert
            expect(result.leaveType, type);
          }
        },
      );

      test(
        'should handle all approval statuses',
        () {
          final statuses = ['P', 'A', 'R', 'C'];

          for (final status in statuses) {
            // arrange
            final jsonMap = {
              'org_id': 1,
              'con_id': 1,
              'loc_id': 1,
              'staff_id': 5,
              'fromdate': '2025-11-10T00:00:00.000',
              'todate': '2025-11-12T00:00:00.000',
              'leavetype': 'AL',
              'approval_status': status,
            };

            // act
            final result = LeaveRequestModel.fromJson(jsonMap);

            // assert
            expect(result.approvalStatus, status);
          }
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
            'learequest_id': 1,
            'org_id': 1,
            'con_id': 1,
            'loc_id': 1,
            'staff_id': 5,
            'requestdate': tRequestDate.toIso8601String(),
            'fromdate': tFromDate.toIso8601String(),
            'todate': tToDate.toIso8601String(),
            'leavetype': 'AL',
            'leaveremarks': 'Annual leave for vacation',
            'approval_status': 'P',
            'created_at': tCreatedAt.toIso8601String(),
            'updated_at': tUpdatedAt.toIso8601String(),
          });
        },
      );

      test(
        'should exclude null optional fields from JSON',
        () {
          // arrange
          final modelWithoutOptionals = LeaveRequestModel(
            orgId: 1,
            conId: 1,
            locId: 1,
            staffId: 5,
            fromDate: tFromDate,
            toDate: tToDate,
            leaveType: 'AL',
            approvalStatus: 'P',
          );

          // act
          final result = modelWithoutOptionals.toJson();

          // assert
          expect(result.containsKey('learequest_id'), false);
          expect(result.containsKey('requestdate'), false);
          expect(result.containsKey('fhvalue'), false);
          expect(result.containsKey('shvalue'), false);
          expect(result.containsKey('leaveremarks'), false);
          expect(result.containsKey('createdby'), false);
          expect(result.containsKey('created_date'), false);
          expect(result.containsKey('approvedby'), false);
          expect(result.containsKey('approveddate'), false);
          expect(result.containsKey('source'), false);
          expect(result.containsKey('created_at'), false);
          expect(result.containsKey('updated_at'), false);
        },
      );

      test(
        'should include half-day values when present',
        () {
          // arrange
          final modelWithHalfDays = LeaveRequestModel(
            orgId: 1,
            conId: 1,
            locId: 1,
            staffId: 5,
            fromDate: tFromDate,
            toDate: tFromDate,
            firstHalfValue: 'AM',
            secondHalfValue: 'PM',
            leaveType: 'AL',
            approvalStatus: 'P',
          );

          // act
          final result = modelWithHalfDays.toJson();

          // assert
          expect(result['fhvalue'], 'AM');
          expect(result['shvalue'], 'PM');
        },
      );

      test(
        'should include source field when present',
        () {
          // arrange
          final modelWithSource = LeaveRequestModel(
            orgId: 1,
            conId: 1,
            locId: 1,
            staffId: 5,
            fromDate: tFromDate,
            toDate: tToDate,
            leaveType: 'AL',
            approvalStatus: 'P',
            source: 'M',
          );

          // act
          final result = modelWithSource.toJson();

          // assert
          expect(result['source'], 'M');
        },
      );
    });

    group('toEntity', () {
      test(
        'should return a LeaveRequest entity with same values',
        () {
          // act
          final entity = tModel.toEntity();

          // assert
          expect(entity, isA<LeaveRequest>());
          expect(entity.leaId, tModel.leaId);
          expect(entity.orgId, tModel.orgId);
          expect(entity.conId, tModel.conId);
          expect(entity.locId, tModel.locId);
          expect(entity.staffId, tModel.staffId);
          expect(entity.requestDate, tModel.requestDate);
          expect(entity.fromDate, tModel.fromDate);
          expect(entity.toDate, tModel.toDate);
          expect(entity.firstHalfValue, tModel.firstHalfValue);
          expect(entity.secondHalfValue, tModel.secondHalfValue);
          expect(entity.leaveType, tModel.leaveType);
          expect(entity.leaveRemarks, tModel.leaveRemarks);
          expect(entity.createdBy, tModel.createdBy);
          expect(entity.createdDate, tModel.createdDate);
          expect(entity.approvalStatus, tModel.approvalStatus);
          expect(entity.approvedBy, tModel.approvedBy);
          expect(entity.approvedDate, tModel.approvedDate);
          expect(entity.source, tModel.source);
          expect(entity.createdAt, tModel.createdAt);
          expect(entity.updatedAt, tModel.updatedAt);
        },
      );

      test(
        'should preserve null values when converting to entity',
        () {
          // arrange
          final modelWithNulls = LeaveRequestModel(
            orgId: 1,
            conId: 1,
            locId: 1,
            staffId: 5,
            fromDate: tFromDate,
            toDate: tToDate,
            leaveType: 'AL',
            approvalStatus: 'P',
          );

          // act
          final entity = modelWithNulls.toEntity();

          // assert
          expect(entity.leaId, isNull);
          expect(entity.requestDate, isNull);
          expect(entity.firstHalfValue, isNull);
          expect(entity.secondHalfValue, isNull);
          expect(entity.leaveRemarks, isNull);
          expect(entity.createdBy, isNull);
          expect(entity.createdDate, isNull);
          expect(entity.approvedBy, isNull);
          expect(entity.approvedDate, isNull);
          expect(entity.source, isNull);
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
            'learequest_id': 1,
            'org_id': 1,
            'con_id': 1,
            'loc_id': 1,
            'staff_id': 5,
            'requestdate': '2025-11-01T10:00:00.000',
            'fromdate': '2025-11-10T00:00:00.000',
            'todate': '2025-11-12T00:00:00.000',
            'fhvalue': 'AM',
            'shvalue': null,
            'leavetype': 'AL',
            'leaveremarks': 'Test remarks',
            'approval_status': 'P',
            'source': 'M',
            'created_at': '2025-11-01T09:00:00.000',
            'updated_at': '2025-11-01T10:00:00.000',
          };

          // act
          final model = LeaveRequestModel.fromJson(originalJson);
          final resultJson = model.toJson();

          // assert
          expect(resultJson['learequest_id'], originalJson['learequest_id']);
          expect(resultJson['org_id'], originalJson['org_id']);
          expect(resultJson['con_id'], originalJson['con_id']);
          expect(resultJson['loc_id'], originalJson['loc_id']);
          expect(resultJson['staff_id'], originalJson['staff_id']);
          expect(resultJson['requestdate'], originalJson['requestdate']);
          expect(resultJson['fromdate'], originalJson['fromdate']);
          expect(resultJson['todate'], originalJson['todate']);
          expect(resultJson['fhvalue'], originalJson['fhvalue']);
          expect(resultJson['leavetype'], originalJson['leavetype']);
          expect(resultJson['leaveremarks'], originalJson['leaveremarks']);
          expect(resultJson['approval_status'], originalJson['approval_status']);
          expect(resultJson['source'], originalJson['source']);
          expect(resultJson['created_at'], originalJson['created_at']);
          expect(resultJson['updated_at'], originalJson['updated_at']);
        },
      );
    });

    group('Entity computed properties', () {
      test(
        'should calculate total leave days correctly',
        () {
          // arrange - 3 full days
          final fullDaysModel = LeaveRequestModel(
            orgId: 1,
            conId: 1,
            locId: 1,
            staffId: 5,
            fromDate: DateTime(2025, 11, 10),
            toDate: DateTime(2025, 11, 12),
            leaveType: 'AL',
            approvalStatus: 'P',
          );

          // act
          final entity = fullDaysModel.toEntity();

          // assert
          expect(entity.totalLeaveDays, 3.0);
        },
      );

      test(
        'should calculate half-day leave correctly',
        () {
          // arrange - 1 day with AM half
          final halfDayModel = LeaveRequestModel(
            orgId: 1,
            conId: 1,
            locId: 1,
            staffId: 5,
            fromDate: DateTime(2025, 11, 10),
            toDate: DateTime(2025, 11, 10),
            firstHalfValue: 'AM',
            leaveType: 'AL',
            approvalStatus: 'P',
          );

          // act
          final entity = halfDayModel.toEntity();

          // assert
          expect(entity.totalLeaveDays, 0.5);
        },
      );

      test(
        'should display status correctly',
        () {
          final statuses = {
            'P': 'Pending',
            'A': 'Approved',
            'R': 'Rejected',
            'C': 'Cancelled',
          };

          for (final entry in statuses.entries) {
            // arrange
            final model = LeaveRequestModel(
              orgId: 1,
              conId: 1,
              locId: 1,
              staffId: 5,
              fromDate: tFromDate,
              toDate: tToDate,
              leaveType: 'AL',
              approvalStatus: entry.key,
            );

            // act
            final entity = model.toEntity();

            // assert
            expect(entity.statusDisplay, entry.value);
          }
        },
      );

      test(
        'should display leave type correctly',
        () {
          final types = {
            'AL': 'Annual Leave',
            'SL': 'Sick Leave',
            'CL': 'Casual Leave',
            'ML': 'Maternity Leave',
            'PL': 'Paternity Leave',
            'UL': 'Unpaid Leave',
          };

          for (final entry in types.entries) {
            // arrange
            final model = LeaveRequestModel(
              orgId: 1,
              conId: 1,
              locId: 1,
              staffId: 5,
              fromDate: tFromDate,
              toDate: tToDate,
              leaveType: entry.key,
              approvalStatus: 'P',
            );

            // act
            final entity = model.toEntity();

            // assert
            expect(entity.leaveTypeDisplay, entry.value);
          }
        },
      );
    });
  });
}
