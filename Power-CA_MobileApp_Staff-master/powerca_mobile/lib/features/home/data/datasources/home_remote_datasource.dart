import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/dashboard_stats_model.dart';
import '../models/recent_activity_model.dart';

/// Remote data source for home/dashboard data
abstract class HomeRemoteDataSource {
  Future<DashboardStatsModel> getDashboardStats(int staffId);
  Future<List<RecentActivityModel>> getRecentActivities(int staffId, int limit);
}

@LazySingleton(as: HomeRemoteDataSource)
class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final SupabaseClient supabaseClient;

  HomeRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<DashboardStatsModel> getDashboardStats(int staffId) async {
    try {
      // Get staff's org_id to filter jobs by organization
      final staffResponse = await supabaseClient
          .from('mbstaff')
          .select('org_id')
          .eq('staff_id', staffId)
          .single();

      final orgId = staffResponse['org_id'];

      // Get active jobs count for the staff's organization
      final activeJobsResponse = await supabaseClient
          .from('jobshead')
          .select('job_id')
          .eq('org_id', orgId)
          .or('job_status.eq.In Progress,job_status.eq.Active,job_status.eq.Started');

      final activeJobsCount = activeJobsResponse.length;

      // Get pending tasks count (count all tasks for now since jobtasks has no staff_id)
      final pendingTasksResponse = await supabaseClient
          .from('jobtasks')
          .select('jt_id')
          .eq('task_status', 0); // Assuming 0 is pending status

      final pendingTasksCount = pendingTasksResponse.length;

      // Get hours worked this week
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekStr = startOfWeek.toIso8601String().split('T')[0];

      final workDiaryResponse = await supabaseClient
          .from('workdiary')
          .select('minutes')
          .eq('staff_id', staffId)
          .gte('date', startOfWeekStr);

      double hoursWorkedThisWeek = 0.0;
      for (final entry in workDiaryResponse) {
        final minutes = entry['minutes'];
        if (minutes != null) {
          final minutesValue = minutes is int ? minutes.toDouble() : minutes as double;
          hoursWorkedThisWeek += minutesValue / 60.0; // Convert minutes to hours
        }
      }

      // Get upcoming reminders count
      final upcomingRemindersResponse = await supabaseClient
          .from('reminder')
          .select('rem_id')
          .eq('staff_id', staffId)
          .gte('remdate', DateTime.now().toIso8601String().split('T')[0])
          .eq('remstatus', 1); // Assuming 1 is Active status

      final upcomingRemindersCount = upcomingRemindersResponse.length;

      // Get pending leave requests count
      final leaveRequestsResponse = await supabaseClient
          .from('learequest')
          .select('learequest_id')
          .eq('staff_id', staffId)
          .eq('approval_status', 'P'); // P for Pending

      final pendingLeaveRequestsCount = leaveRequestsResponse.length;

      return DashboardStatsModel(
        activeJobsCount: activeJobsCount,
        pendingTasksCount: pendingTasksCount,
        hoursWorkedThisWeek: hoursWorkedThisWeek,
        upcomingRemindersCount: upcomingRemindersCount,
        pendingLeaveRequestsCount: pendingLeaveRequestsCount,
      );
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<RecentActivityModel>> getRecentActivities(int staffId, int limit) async {
    try {
      final List<RecentActivityModel> activities = [];

      // Get staff's org_id to filter jobs by organization
      final staffResponse = await supabaseClient
          .from('mbstaff')
          .select('org_id')
          .eq('staff_id', staffId)
          .single();

      final orgId = staffResponse['org_id'];

      // Get recent jobs (last 5) for the staff's organization
      final recentJobs = await supabaseClient
          .from('jobshead')
          .select('job_id, work_desc, job_status, updated_at')
          .eq('org_id', orgId)
          .order('updated_at', ascending: false)
          .limit(5);

      for (final job in recentJobs) {
        activities.add(
          RecentActivityModel(
            id: job['job_id'].toString(),
            type: 'job',
            title: job['work_desc'] ?? 'Unnamed Job',
            subtitle: 'Job #${job['job_id']}',
            timestamp: job['updated_at'] != null
                ? DateTime.parse(job['updated_at'])
                : DateTime.now(),
            status: job['job_status'],
          ),
        );
      }

      // Get recent work diary entries (last 5)
      final recentWorkDiary = await supabaseClient
          .from('workdiary')
          .select('wd_id, date, minutes, tasknotes, job_id')
          .eq('staff_id', staffId)
          .order('date', ascending: false)
          .limit(5);

      for (final entry in recentWorkDiary) {
        final minutes = entry['minutes'];
        final hours = minutes != null
            ? ((minutes is int ? minutes.toDouble() : minutes as double) / 60.0).toStringAsFixed(1)
            : '0.0';

        activities.add(
          RecentActivityModel(
            id: entry['wd_id'].toString(),
            type: 'work_diary',
            title: '$hours hours logged',
            subtitle: entry['tasknotes'] ?? 'Job #${entry['job_id']}',
            timestamp: entry['date'] != null
                ? DateTime.parse(entry['date'])
                : DateTime.now(),
            status: null,
          ),
        );
      }

      // Sort all activities by timestamp and take the requested limit
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return activities.take(limit).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
