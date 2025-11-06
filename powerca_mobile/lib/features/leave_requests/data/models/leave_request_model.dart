import '../../domain/entities/leave_request.dart';

/// Leave Request Model
/// Data transfer object for leave requests with JSON serialization
class LeaveRequestModel extends LeaveRequest {
  const LeaveRequestModel({
    super.leaId,
    required super.orgId,
    required super.conId,
    required super.locId,
    required super.staffId,
    super.requestDate,
    required super.fromDate,
    required super.toDate,
    super.firstHalfValue,
    super.secondHalfValue,
    required super.leaveType,
    super.leaveRemarks,
    super.createdBy,
    super.createdDate,
    required super.approvalStatus,
    super.approvedBy,
    super.approvedDate,
    super.source,
    super.createdAt,
    super.updatedAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      leaId: json['learequest_id'] as int?,
      orgId: json['org_id'] as int,
      conId: json['con_id'] as int,
      locId: json['loc_id'] as int,
      staffId: json['staff_id'] as int,
      requestDate: json['requestdate'] != null
          ? DateTime.parse(json['requestdate'] as String)
          : null,
      fromDate: DateTime.parse(json['fromdate'] as String),
      toDate: DateTime.parse(json['todate'] as String),
      firstHalfValue: json['fhvalue'] as String?,
      secondHalfValue: json['shvalue'] as String?,
      leaveType: json['leavetype'] as String,
      leaveRemarks: json['leaveremarks'] as String?,
      createdBy: json['createdby'] as String?,
      createdDate: json['createddate'] != null
          ? DateTime.parse(json['createddate'] as String)
          : null,
      approvalStatus: json['approval_status'] as String,
      approvedBy: json['approvedby'] as String?,
      approvedDate: json['approveddate'] != null
          ? DateTime.parse(json['approveddate'] as String)
          : null,
      source: json['source'] as String?,
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
      if (leaId != null) 'learequest_id': leaId,
      'org_id': orgId,
      'con_id': conId,
      'loc_id': locId,
      'staff_id': staffId,
      if (requestDate != null) 'requestdate': requestDate!.toIso8601String(),
      'fromdate': fromDate.toIso8601String(),
      'todate': toDate.toIso8601String(),
      if (firstHalfValue != null) 'fhvalue': firstHalfValue,
      if (secondHalfValue != null) 'shvalue': secondHalfValue,
      'leavetype': leaveType,
      if (leaveRemarks != null) 'leaveremarks': leaveRemarks,
      if (createdBy != null) 'createdby': createdBy,
      if (createdDate != null) 'createddate': createdDate!.toIso8601String(),
      'approval_status': approvalStatus,
      if (approvedBy != null) 'approvedby': approvedBy,
      if (approvedDate != null) 'approveddate': approvedDate!.toIso8601String(),
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  LeaveRequest toEntity() {
    return LeaveRequest(
      leaId: leaId,
      orgId: orgId,
      conId: conId,
      locId: locId,
      staffId: staffId,
      requestDate: requestDate,
      fromDate: fromDate,
      toDate: toDate,
      firstHalfValue: firstHalfValue,
      secondHalfValue: secondHalfValue,
      leaveType: leaveType,
      leaveRemarks: leaveRemarks,
      createdBy: createdBy,
      createdDate: createdDate,
      approvalStatus: approvalStatus,
      approvedBy: approvedBy,
      approvedDate: approvedDate,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
