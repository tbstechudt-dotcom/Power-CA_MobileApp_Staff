import '../../domain/entities/staff.dart';

/// Staff Model
///
/// Data model for mbstaff table in Supabase
class StaffModel extends Staff {
  const StaffModel({
    required super.staffId,
    required super.name,
    required super.username,
    required super.orgId,
    required super.locId,
    required super.conId,
    super.email,
    super.phoneNumber,
    super.dateOfBirth,
    super.staffType,
    super.isActive,
  });

  /// Create from JSON (Supabase response)
  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      staffId: _parseNumeric(json['staff_id']),
      name: json['name'] ?? '',
      username: json['app_username'] ?? '',
      orgId: _parseNumeric(json['org_id']),
      locId: _parseNumeric(json['loc_id']),
      conId: json['con_id'] is int ? json['con_id'] : 0,
      email: json['email'],
      phoneNumber: json['phonumber'],
      dateOfBirth: json['dob'] != null ? DateTime.parse(json['dob']) : null,
      staffType: json['stafftype'] != null ? _parseNumeric(json['stafftype']) : null,
      isActive: _parseActiveStatus(json['active_status']),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'name': name,
      'app_username': username,
      'org_id': orgId,
      'loc_id': locId,
      'con_id': conId,
      'email': email,
      'phonumber': phoneNumber,
      'dob': dateOfBirth?.toIso8601String(),
      'stafftype': staffType,
      'active_status': isActive ? 1 : 2,
    };
  }

  /// Convert to entity
  Staff toEntity() {
    return Staff(
      staffId: staffId,
      name: name,
      username: username,
      orgId: orgId,
      locId: locId,
      conId: conId,
      email: email,
      phoneNumber: phoneNumber,
      dateOfBirth: dateOfBirth,
      staffType: staffType,
      isActive: isActive,
    );
  }

  /// Create from entity
  factory StaffModel.fromEntity(Staff staff) {
    return StaffModel(
      staffId: staff.staffId,
      name: staff.name,
      username: staff.username,
      orgId: staff.orgId,
      locId: staff.locId,
      conId: staff.conId,
      email: staff.email,
      phoneNumber: staff.phoneNumber,
      dateOfBirth: staff.dateOfBirth,
      staffType: staff.staffType,
      isActive: staff.isActive,
    );
  }

  /// Helper to parse numeric fields (handles both int and numeric/decimal from PostgreSQL)
  static int _parseNumeric(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Helper to parse active status (handles 0/1 or bool)
  static bool _parseActiveStatus(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1 || value == 0;
    if (value is String) {
      final intValue = int.tryParse(value);
      if (intValue != null) return intValue == 1 || intValue == 0;
    }
    return true; // Default to active
  }

  @override
  String toString() {
    return 'StaffModel(staffId: $staffId, name: $name, username: $username, isActive: $isActive)';
  }
}
