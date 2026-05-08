import 'package:equatable/equatable.dart';

/// Entity representing dashboard statistics for a staff member
class DashboardStats extends Equatable {
  final int activeJobsCount;
  final int pendingTasksCount;
  final double hoursWorkedThisWeek;
  final int upcomingRemindersCount;
  final int pendingLeaveRequestsCount;

  const DashboardStats({
    required this.activeJobsCount,
    required this.pendingTasksCount,
    required this.hoursWorkedThisWeek,
    required this.upcomingRemindersCount,
    required this.pendingLeaveRequestsCount,
  });

  @override
  List<Object?> get props => [
        activeJobsCount,
        pendingTasksCount,
        hoursWorkedThisWeek,
        upcomingRemindersCount,
        pendingLeaveRequestsCount,
      ];
}
