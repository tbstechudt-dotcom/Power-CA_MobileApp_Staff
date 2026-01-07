import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

abstract class DeviceSecurityLocalDataSource {
  /// Store device fingerprint (legacy - kept for compatibility)
  Future<void> storeDeviceFingerprint(String fingerprint);

  /// Get stored device fingerprint
  Future<String?> getDeviceFingerprint();

  /// Store verified phone number (new - phone-based verification)
  Future<void> storeVerifiedPhone(String phone);

  /// Get stored verified phone number
  Future<String?> getVerifiedPhone();

  /// Store verified staff ID
  Future<void> storeVerifiedStaffId(int staffId);

  /// Get stored verified staff ID
  Future<int?> getVerifiedStaffId();

  /// Store verified staff name
  Future<void> storeVerifiedStaffName(String staffName);

  /// Get stored verified staff name
  Future<String?> getVerifiedStaffName();

  /// Check if device is verified (has verified phone)
  Future<bool> isDeviceVerified();

  /// Clear all security data
  Future<void> clearAll();
}

@LazySingleton(as: DeviceSecurityLocalDataSource)
class DeviceSecurityLocalDataSourceImpl
    implements DeviceSecurityLocalDataSource {
  final FlutterSecureStorage secureStorage;

  static const String _fingerprintKey = 'device_security_fingerprint';
  static const String _verifiedPhoneKey = 'device_security_verified_phone';
  static const String _verifiedStaffIdKey = 'device_security_verified_staff_id';
  static const String _verifiedStaffNameKey = 'device_security_verified_staff_name';

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
  Future<void> storeVerifiedPhone(String phone) async {
    await secureStorage.write(key: _verifiedPhoneKey, value: phone);
  }

  @override
  Future<String?> getVerifiedPhone() async {
    return secureStorage.read(key: _verifiedPhoneKey);
  }

  @override
  Future<void> storeVerifiedStaffId(int staffId) async {
    await secureStorage.write(key: _verifiedStaffIdKey, value: staffId.toString());
  }

  @override
  Future<int?> getVerifiedStaffId() async {
    final staffIdStr = await secureStorage.read(key: _verifiedStaffIdKey);
    if (staffIdStr == null) return null;
    return int.tryParse(staffIdStr);
  }

  @override
  Future<void> storeVerifiedStaffName(String staffName) async {
    await secureStorage.write(key: _verifiedStaffNameKey, value: staffName);
  }

  @override
  Future<String?> getVerifiedStaffName() async {
    return secureStorage.read(key: _verifiedStaffNameKey);
  }

  @override
  Future<bool> isDeviceVerified() async {
    final phone = await getVerifiedPhone();
    return phone != null && phone.isNotEmpty;
  }

  @override
  Future<void> clearAll() async {
    await secureStorage.delete(key: _fingerprintKey);
    await secureStorage.delete(key: _verifiedPhoneKey);
    await secureStorage.delete(key: _verifiedStaffIdKey);
    await secureStorage.delete(key: _verifiedStaffNameKey);
  }
}
