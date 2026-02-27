import '../../domain/entities/dashboard_stats.dart';

/// Data model for dashboard statistics
class DashboardStatsModel extends DashboardStats {
  const DashboardStatsModel({
    required super.activeJobsCount,
    required super.pendingTasksCount,
    required super.hoursWorkedThisWeek,
    required super.upcomingRemindersCount,
    required super.pendingLeaveRequestsCount,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      activeJobsCount: json['active_jobs_count'] ?? 0,
      pendingTasksCount: json['pending_tasks_count'] ?? 0,
      hoursWorkedThisWeek: (json['hours_worked_this_week'] ?? 0).toDouble(),
      upcomingRemindersCount: json['upcoming_reminders_count'] ?? 0,
      pendingLeaveRequestsCount: json['pending_leave_requests_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_jobs_count': activeJobsCount,
      'pending_tasks_count': pendingTasksCount,
      'hours_worked_this_week': hoursWorkedThisWeek,
      'upcoming_reminders_count': upcomingRemindersCount,
      'pending_leave_requests_count': pendingLeaveRequestsCount,
    };
  }
}
