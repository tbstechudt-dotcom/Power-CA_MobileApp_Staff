import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../domain/entities/device_info.dart';

class DeviceInfoModel extends DeviceInfo {
  const DeviceInfoModel({
    required super.fingerprint,
    required super.deviceName,
    required super.deviceModel,
    required super.platform,
  });

  /// Create DeviceInfoModel from device_info_plus plugin
  static Future<DeviceInfoModel> fromDevice(int staffId) async {
    final deviceInfo = DeviceInfoPlugin();

    String deviceId = '';
    String deviceName = '';
    String deviceModel = '';
    String platform = '';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id; // Android ID
      deviceName = androidInfo.device;
      deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      platform = 'Android';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
      deviceName = iosInfo.name;
      deviceModel = iosInfo.model;
      platform = 'iOS';
    }

    // Generate fingerprint
    final fingerprintSource = '$platform|$deviceModel|$deviceId|$staffId';
    final fingerprint = sha256.convert(utf8.encode(fingerprintSource)).toString();

    return DeviceInfoModel(
      fingerprint: fingerprint,
      deviceName: deviceName,
      deviceModel: deviceModel,
      platform: platform,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fingerprint': fingerprint,
      'device_name': deviceName,
      'device_model': deviceModel,
      'platform': platform,
    };
  }

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    return DeviceInfoModel(
      fingerprint: json['fingerprint'] ?? '',
      deviceName: json['device_name'] ?? '',
      deviceModel: json['device_model'] ?? '',
      platform: json['platform'] ?? '',
    );
  }

  DeviceInfo toEntity() => DeviceInfo(
        fingerprint: fingerprint,
        deviceName: deviceName,
        deviceModel: deviceModel,
        platform: platform,
      );
}
