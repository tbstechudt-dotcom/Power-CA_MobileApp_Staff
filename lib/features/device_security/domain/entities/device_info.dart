import 'package:equatable/equatable.dart';

/// Represents device information used for device fingerprinting
class DeviceInfo extends Equatable {
  final String fingerprint;
  final String deviceName;
  final String deviceModel;
  final String platform;

  const DeviceInfo({
    required this.fingerprint,
    required this.deviceName,
    required this.deviceModel,
    required this.platform,
  });

  @override
  List<Object?> get props => [fingerprint, deviceName, deviceModel, platform];
}
