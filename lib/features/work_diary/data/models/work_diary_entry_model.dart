import '../../domain/entities/work_diary_entry.dart';

class WorkDiaryEntryModel extends WorkDiaryEntry {
  const WorkDiaryEntryModel({
    super.wdId,
    required super.jobId,
    super.jobReference,
    super.taskName,
    required super.staffId,
    required super.date,
    required super.hoursWorked,
    super.notes,
    super.createdAt,
    super.updatedAt,
  });

  factory WorkDiaryEntryModel.fromJson(Map<String, dynamic> json) {
    return WorkDiaryEntryModel(
      wdId: json['wd_id'] as int?,
      jobId: json['job_id'] as int,
      jobReference: json['jobshead']?['job_name'] as String?,
      taskName: json['jobtasks']?['task_name'] as String?,
      staffId: json['staff_id'] as int,
      date: DateTime.parse(json['wd_date'] as String),
      hoursWorked: (json['actual_hrs'] as num?)?.toDouble() ?? 0.0,
      notes: json['wd_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (wdId != null) 'wd_id': wdId,
      'job_id': jobId,
      'staff_id': staffId,
      'wd_date': date.toIso8601String(),
      'actual_hrs': hoursWorked,
      if (notes != null) 'wd_notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  WorkDiaryEntry toEntity() {
    return WorkDiaryEntry(
      wdId: wdId,
      jobId: jobId,
      jobReference: jobReference,
      taskName: taskName,
      staffId: staffId,
      date: date,
      hoursWorked: hoursWorked,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
