import '../../domain/entities/device_status.dart';

class DeviceStatusModel extends DeviceStatus {
  const DeviceStatusModel({
    required super.deviceRegistered,
    required super.isVerified,
    super.verifiedAt,
    super.deviceName,
  });

  factory DeviceStatusModel.fromJson(Map<String, dynamic> json) {
    return DeviceStatusModel(
      deviceRegistered: json['device_registered'] ?? false,
      isVerified: json['is_verified'] ?? false,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
      deviceName: json['device_name'],
    );
  }

  DeviceStatus toEntity() => DeviceStatus(
        deviceRegistered: deviceRegistered,
        isVerified: isVerified,
        verifiedAt: verifiedAt,
        deviceName: deviceName,
      );
}
