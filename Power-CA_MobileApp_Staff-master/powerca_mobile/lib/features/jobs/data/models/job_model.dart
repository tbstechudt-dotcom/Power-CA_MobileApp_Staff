import '../../domain/entities/job.dart';

/// Data model for Job
class JobModel extends Job {
  const JobModel({
    required super.jobId,
    required super.jobReference,
    required super.clientName,
    required super.jobName,
    required super.status,
    required super.staffId,
    required super.clientId,
    super.startDate,
    super.endDate,
    super.createdAt,
    super.updatedAt,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      jobId: json['job_id'] as int,
      jobReference: json['job_reference'] ?? 'REG${json['job_id']}',
      clientName: json['client_name'] ?? 'Unknown Client',
      jobName: json['job_name'] ?? '',
      status: json['job_status'] ?? 'Waiting',
      staffId: json['staff_id'] as int,
      clientId: json['client_id'] as int,
      startDate: json['jstartdate'] != null
          ? DateTime.parse(json['jstartdate'])
          : null,
      endDate:
          json['jenddate'] != null ? DateTime.parse(json['jenddate']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'job_reference': jobReference,
      'client_name': clientName,
      'job_name': jobName,
      'job_status': status,
      'staff_id': staffId,
      'client_id': clientId,
      'jstartdate': startDate?.toIso8601String(),
      'jenddate': endDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
