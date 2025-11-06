import 'package:equatable/equatable.dart';

/// Entity representing a recent activity item on the dashboard
class RecentActivity extends Equatable {
  final String id;
  final String type; // 'job', 'task', 'work_diary', 'reminder'
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final String? status;

  const RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.status,
  });

  @override
  List<Object?> get props => [id, type, title, subtitle, timestamp, status];
}
