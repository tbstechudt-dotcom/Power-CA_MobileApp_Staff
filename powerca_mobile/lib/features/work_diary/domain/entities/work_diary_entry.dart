import 'package:equatable/equatable.dart';

class WorkDiaryEntry extends Equatable {
  final int? wdId;
  final int jobId;
  final String? jobReference;
  final String? taskName;
  final int staffId;
  final DateTime date;
  final double hoursWorked;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkDiaryEntry({
    this.wdId,
    required this.jobId,
    this.jobReference,
    this.taskName,
    required this.staffId,
    required this.date,
    required this.hoursWorked,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Format hours as "HH:MM Hrs"
  String get formattedHours {
    final hours = hoursWorked.floor();
    final minutes = ((hoursWorked - hours) * 60).round();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} Hrs';
  }

  /// Format date as "DD MMM YYYY"
  String get formattedDate {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  List<Object?> get props => [
        wdId,
        jobId,
        jobReference,
        taskName,
        staffId,
        date,
        hoursWorked,
        notes,
        createdAt,
        updatedAt,
      ];

  WorkDiaryEntry copyWith({
    int? wdId,
    int? jobId,
    String? jobReference,
    String? taskName,
    int? staffId,
    DateTime? date,
    double? hoursWorked,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkDiaryEntry(
      wdId: wdId ?? this.wdId,
      jobId: jobId ?? this.jobId,
      jobReference: jobReference ?? this.jobReference,
      taskName: taskName ?? this.taskName,
      staffId: staffId ?? this.staffId,
      date: date ?? this.date,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
