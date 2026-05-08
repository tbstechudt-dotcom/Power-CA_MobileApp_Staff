import 'package:equatable/equatable.dart';

/// Staff Entity
///
/// Represents an authenticated staff member from mbstaff table
class Staff extends Equatable {
  final int staffId;
  final String name;
  final String username;
  final int orgId;
  final int locId;
  final int conId;
  final String? email;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final int? staffType;
  final bool isActive;

  const Staff({
    required this.staffId,
    required this.name,
    required this.username,
    required this.orgId,
    required this.locId,
    required this.conId,
    this.email,
    this.phoneNumber,
    this.dateOfBirth,
    this.staffType,
    this.isActive = true,
  });

  /// Check if staff is active and can log in
  bool get canLogin => isActive;

  @override
  List<Object?> get props => [
        staffId,
        name,
        username,
        orgId,
        locId,
        conId,
        email,
        phoneNumber,
        dateOfBirth,
        staffType,
        isActive,
      ];

  @override
  String toString() {
    return 'Staff(staffId: $staffId, name: $name, username: $username, isActive: $isActive)';
  }
}
