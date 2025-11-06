import '../../domain/entities/recent_activity.dart';

/// Data model for recent activity
class RecentActivityModel extends RecentActivity {
  const RecentActivityModel({
    required super.id,
    required super.type,
    required super.title,
    super.subtitle,
    required super.timestamp,
    super.status,
  });

  factory RecentActivityModel.fromJson(Map<String, dynamic> json) {
    return RecentActivityModel(
      id: json['id'].toString(),
      type: json['type'] ?? 'unknown',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }
}
