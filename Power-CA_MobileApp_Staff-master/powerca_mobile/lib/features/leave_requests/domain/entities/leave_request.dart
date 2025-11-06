import 'package:equatable/equatable.dart';

/// Leave Request Entity
/// Represents a staff member's leave request in the domain layer
class LeaveRequest extends Equatable {
  final int? leaId;
  final int orgId;
  final int conId;
  final int locId;
  final int staffId;
  final DateTime? requestDate;
  final DateTime fromDate;
  final DateTime toDate;
  final String? firstHalfValue;  // AM/PM indicator for first day
  final String? secondHalfValue; // AM/PM indicator for last day
  final String leaveType;        // Leave type code (e.g., 'AL' = Annual Leave)
  final String? leaveRemarks;
  final String? createdBy;
  final DateTime? createdDate;
  final String approvalStatus;   // 'P' = Pending, 'A' = Approved, 'R' = Rejected
  final String? approvedBy;
  final DateTime? approvedDate;
  final String? source;          // 'M' = Mobile, 'D' = Desktop
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Computed properties
  String get statusDisplay {
    switch (approvalStatus) {
      case 'P':
        return 'Pending';
      case 'A':
        return 'Approved';
      case 'R':
        return 'Rejected';
      case 'C':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String get leaveTypeDisplay {
    switch (leaveType) {
      case 'AL':
        return 'Annual Leave';
      case 'SL':
        return 'Sick Leave';
      case 'CL':
        return 'Casual Leave';
      case 'ML':
        return 'Maternity Leave';
      case 'PL':
        return 'Paternity Leave';
      case 'UL':
        return 'Unpaid Leave';
      case 'OT':
        return 'Other';
      default:
        return leaveType;
    }
  }

  /// Calculate number of leave days
  double get totalLeaveDays {
    if (fromDate.isAfter(toDate)) return 0;

    // Calculate full days difference
    final daysDiff = toDate.difference(fromDate).inDays + 1;

    // Adjust for half days
    double adjustment = 0;
    if (firstHalfValue != null && firstHalfValue!.isNotEmpty) {
      adjustment -= 0.5; // First day is half day
    }
    if (secondHalfValue != null && secondHalfValue!.isNotEmpty) {
      adjustment -= 0.5; // Last day is half day
    }

    return daysDiff + adjustment;
  }

  String get formattedDateRange {
    final from = '${fromDate.day}/${fromDate.month}/${fromDate.year}';
    final to = '${toDate.day}/${toDate.month}/${toDate.year}';
    return fromDate == toDate ? from : '$from - $to';
  }

  const LeaveRequest({
    this.leaId,
    required this.orgId,
    required this.conId,
    required this.locId,
    required this.staffId,
    this.requestDate,
    required this.fromDate,
    required this.toDate,
    this.firstHalfValue,
    this.secondHalfValue,
    required this.leaveType,
    this.leaveRemarks,
    this.createdBy,
    this.createdDate,
    required this.approvalStatus,
    this.approvedBy,
    this.approvedDate,
    this.source,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        leaId,
        orgId,
        conId,
        locId,
        staffId,
        requestDate,
        fromDate,
        toDate,
        firstHalfValue,
        secondHalfValue,
        leaveType,
        leaveRemarks,
        createdBy,
        createdDate,
        approvalStatus,
        approvedBy,
        approvedDate,
        source,
        createdAt,
        updatedAt,
      ];
}
