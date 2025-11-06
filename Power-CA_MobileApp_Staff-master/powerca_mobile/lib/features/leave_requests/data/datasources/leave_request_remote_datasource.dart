import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leave_request_model.dart';

/// Leave Request Remote Data Source Interface
abstract class LeaveRequestRemoteDataSource {
  Future<List<LeaveRequestModel>> getLeaveRequests({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  });

  Future<LeaveRequestModel> getLeaveRequestById(int leaId);

  Future<LeaveRequestModel> createLeaveRequest(LeaveRequestModel request);

  Future<LeaveRequestModel> updateLeaveRequest(LeaveRequestModel request);

  Future<void> cancelLeaveRequest(int leaId);

  Future<Map<String, double>> getLeaveBalance(int staffId);
}

/// Leave Request Remote Data Source Implementation
class LeaveRequestRemoteDataSourceImpl
    implements LeaveRequestRemoteDataSource {
  final SupabaseClient supabaseClient;

  LeaveRequestRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests({
    required int staffId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    try {
      // Build filter query
      var filterQuery = supabaseClient
          .from('learequest')
          .select('*')
          .eq('staff_id', staffId);

      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        filterQuery = filterQuery.eq('approval_status', status);
      }

      // Apply transform operations
      var finalQuery = filterQuery.order('requestdate', ascending: false);

      if (limit != null) {
        finalQuery = finalQuery.limit(limit);
      }

      if (offset != null) {
        finalQuery = finalQuery.range(offset, offset + (limit ?? 20) - 1);
      }

      final response = await finalQuery;

      return (response as List)
          .map((json) => LeaveRequestModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get leave requests: $e');
    }
  }

  @override
  Future<LeaveRequestModel> getLeaveRequestById(int leaId) async {
    try {
      final response = await supabaseClient
          .from('learequest')
          .select('*')
          .eq('learequest_id', leaId)
          .single();

      return LeaveRequestModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get leave request: $e');
    }
  }

  @override
  Future<LeaveRequestModel> createLeaveRequest(
    LeaveRequestModel request,
  ) async {
    try {
      final response = await supabaseClient
          .from('learequest')
          .insert(request.toJson())
          .select('*')
          .single();

      return LeaveRequestModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create leave request: $e');
    }
  }

  @override
  Future<LeaveRequestModel> updateLeaveRequest(
    LeaveRequestModel request,
  ) async {
    try {
      if (request.leaId == null) {
        throw Exception('Cannot update leave request without ID');
      }

      final response = await supabaseClient
          .from('learequest')
          .update(request.toJson())
          .eq('learequest_id', request.leaId!)
          .select('*')
          .single();

      return LeaveRequestModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update leave request: $e');
    }
  }

  @override
  Future<void> cancelLeaveRequest(int leaId) async {
    try {
      await supabaseClient
          .from('learequest')
          .update({'approval_status': 'C'})
          .eq('learequest_id', leaId);
    } catch (e) {
      throw Exception('Failed to cancel leave request: $e');
    }
  }

  @override
  Future<Map<String, double>> getLeaveBalance(int staffId) async {
    try {
      // Get all approved leave requests for this year
      final year = DateTime.now().year;
      final yearStart = DateTime(year, 1, 1).toIso8601String();
      final yearEnd = DateTime(year, 12, 31).toIso8601String();

      final response = await supabaseClient
          .from('learequest')
          .select('leavetype, fromdate, todate, fhvalue, shvalue')
          .eq('staff_id', staffId)
          .eq('approval_status', 'A')
          .gte('fromdate', yearStart)
          .lte('todate', yearEnd);

      // Calculate used leave by type
      final Map<String, double> usedLeave = {};

      for (final record in response) {
        final leaveType = record['leavetype'] as String;
        final fromDate = DateTime.parse(record['fromdate'] as String);
        final toDate = DateTime.parse(record['todate'] as String);
        final fhValue = record['fhvalue'] as String?;
        final shValue = record['shvalue'] as String?;

        // Calculate days
        double days = toDate.difference(fromDate).inDays.toDouble() + 1;

        // Adjust for half days
        if (fhValue != null && fhValue.isNotEmpty) {
          days -= 0.5;
        }
        if (shValue != null && shValue.isNotEmpty) {
          days -= 0.5;
        }

        usedLeave[leaveType] = (usedLeave[leaveType] ?? 0) + days;
      }

      // Define leave entitlements (hardcoded for now - should come from DB)
      final Map<String, double> entitlements = {
        'AL': 15.0, // Annual Leave
        'SL': 10.0, // Sick Leave
        'CL': 5.0,  // Casual Leave
        'ML': 90.0, // Maternity Leave
        'PL': 5.0,  // Paternity Leave
      };

      // Calculate remaining leave
      final Map<String, double> remaining = {};
      entitlements.forEach((type, total) {
        remaining[type] = total - (usedLeave[type] ?? 0);
      });

      return remaining;
    } catch (e) {
      throw Exception('Failed to get leave balance: $e');
    }
  }
}
