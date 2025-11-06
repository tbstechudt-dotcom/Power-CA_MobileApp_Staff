import 'package:equatable/equatable.dart';

/// Job Entity
///
/// Represents a job from jobshead table with related data
class Job extends Equatable {
  final int jobId;
  final String jobReference; // e.g., "REG53677"
  final String clientName;
  final String jobName; // e.g., "Audit Planning"
  final String status; // Waiting, Planning, Progress, Work Done, Delivery, Closed
  final int staffId;
  final int clientId;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Job({
    required this.jobId,
    required this.jobReference,
    required this.clientName,
    required this.jobName,
    required this.status,
    required this.staffId,
    required this.clientId,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  /// Get status color based on job status
  String get statusColor {
    switch (status.toLowerCase()) {
      case 'waiting':
        return '#E3EFFF'; // Light blue
      case 'planning':
        return '#E3EFFF'; // Light blue
      case 'progress':
      case 'in progress':
        return '#E8E3FF'; // Light purple
      case 'work done':
        return '#D4F4DD'; // Light green
      case 'delivery':
        return '#E3EFFF'; // Light blue
      case 'closed':
        return '#E5E5E5'; // Gray
      default:
        return '#E3EFFF'; // Default light blue
    }
  }

  /// Get status text color
  String get statusTextColor {
    switch (status.toLowerCase()) {
      case 'waiting':
        return '#2255FC';
      case 'planning':
        return '#2255FC';
      case 'progress':
      case 'in progress':
        return '#6B4EFF';
      case 'work done':
        return '#00C853';
      case 'delivery':
        return '#2255FC';
      case 'closed':
        return '#757575';
      default:
        return '#2255FC';
    }
  }

  @override
  List<Object?> get props => [
        jobId,
        jobReference,
        clientName,
        jobName,
        status,
        staffId,
        clientId,
        startDate,
        endDate,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Job(jobId: $jobId, reference: $jobReference, client: $clientName, status: $status)';
  }
}
