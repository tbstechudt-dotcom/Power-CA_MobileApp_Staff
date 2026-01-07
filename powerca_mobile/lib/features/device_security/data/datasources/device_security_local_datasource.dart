import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

abstract class DeviceSecurityLocalDataSource {
  /// Store device fingerprint
  Future<void> storeDeviceFingerprint(String fingerprint);

  /// Get stored device fingerprint
  Future<String?> getDeviceFingerprint();

  /// Clear all security data
  Future<void> clearAll();
}

@LazySingleton(as: DeviceSecurityLocalDataSource)
class DeviceSecurityLocalDataSourceImpl
    implements DeviceSecurityLocalDataSource {
  final FlutterSecureStorage secureStorage;

  static const String _fingerprintKey = 'device_security_fingerprint';

  DeviceSecurityLocalDataSourceImpl({required this.secureStorage});

  @override
  Future<void> storeDeviceFingerprint(String fingerprint) async {
    await secureStorage.write(key: _fingerprintKey, value: fingerprint);
  }

  @override
  Future<String?> getDeviceFingerprint() async {
    return secureStorage.read(key: _fingerprintKey);
  }

  @override
  Future<void> clearAll() async {
    await secureStorage.delete(key: _fingerprintKey);
  }
}
