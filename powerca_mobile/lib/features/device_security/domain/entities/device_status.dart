import 'package:equatable/equatable.dart';

/// Represents the verification status of a device
class DeviceStatus extends Equatable {
  final bool deviceRegistered;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? deviceName;

  const DeviceStatus({
    required this.deviceRegistered,
    required this.isVerified,
    this.verifiedAt,
    this.deviceName,
  });

  /// Returns true if device needs OTP verification
  bool get needsVerification => !isVerified;

  @override
  List<Object?> get props => [deviceRegistered, isVerified, verifiedAt, deviceName];
}
