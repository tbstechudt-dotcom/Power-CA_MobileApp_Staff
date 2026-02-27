import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_info.dart';
import '../entities/device_status.dart';
import '../entities/otp_response.dart';

/// Repository interface for device security operations
abstract class DeviceSecurityRepository {
  /// Set current staff ID for device fingerprint generation
  void setStaffId(int staffId);

  /// Get device fingerprint for current device
  Future<Either<Failure, DeviceInfo>> getDeviceInfo();

  /// Check if device is registered and verified
  Future<Either<Failure, DeviceStatus>> checkDeviceStatus(
    int staffId,
    String fingerprint,
  );

  /// Check if device is verified by fingerprint only (no staff_id required)
  Future<Either<Failure, DeviceStatus>> checkDeviceStatusByFingerprint(
    String fingerprint,
  );

  /// Send OTP for device verification
  Future<Either<Failure, OtpResponse>> sendOtp(
    int staffId,
    DeviceInfo deviceInfo,
  );

  /// Send OTP using phone number (for first-time device verification)
  /// [staffId] - Optional staff ID for validation (ensures phone belongs to logged-in staff)
  Future<Either<Failure, OtpResponse>> sendOtpWithPhone(
    String phone,
    DeviceInfo deviceInfo, {
    int? staffId,
  });

  /// Verify OTP code
  Future<Either<Failure, OtpVerificationResponse>> verifyOtp(
    int staffId,
    String fingerprint,
    String otp,
  );

  /// Verify OTP using phone number (for first-time device verification)
  Future<Either<Failure, OtpVerificationResponse>> verifyOtpWithPhone(
    String phone,
    String fingerprint,
    String otp,
  );

  /// Clear all security data (for logout or reset)
  Future<Either<Failure, void>> clearSecurityData();

  /// Store device fingerprint locally
  Future<void> storeDeviceFingerprint(String fingerprint);

  /// Get stored device fingerprint
  Future<String?> getStoredFingerprint();

  /// Check if device is owned by another staff member
  /// Returns owner info if device is already verified by someone
  Future<Either<Failure, DeviceOwnerInfo>> checkDeviceOwner(String fingerprint);

  // ============ Phone-based verification (no fingerprint) ============

  /// Check if device is verified locally (phone stored)
  Future<bool> isDeviceVerifiedLocally();

  /// Get locally stored verified phone
  Future<String?> getVerifiedPhone();

  /// Get locally stored verified staff ID
  Future<int?> getVerifiedStaffId();

  /// Get locally stored verified staff name
  Future<String?> getVerifiedStaffName();

  /// Store verified phone, staff ID, and staff name locally after OTP verification
  Future<void> storeVerificationData(String phone, int staffId, String staffName);
}

/// Device owner information
class DeviceOwnerInfo {
  final bool hasOwner;
  final int? ownerStaffId;
  final String? ownerName;
  final String? ownerPhoneMasked; // Shows last 4 digits only (e.g., ******1234)
  final DateTime? verifiedAt;

  DeviceOwnerInfo({
    required this.hasOwner,
    this.ownerStaffId,
    this.ownerName,
    this.ownerPhoneMasked,
    this.verifiedAt,
  });

  factory DeviceOwnerInfo.fromJson(Map<String, dynamic> json) {
    return DeviceOwnerInfo(
      hasOwner: json['has_owner'] ?? false,
      ownerStaffId: json['owner_staff_id'] != null
          ? (json['owner_staff_id'] is int
              ? json['owner_staff_id']
              : int.tryParse(json['owner_staff_id'].toString()))
          : null,
      ownerName: json['owner_name'],
      ownerPhoneMasked: json['owner_phone_masked'],
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString())
          : null,
    );
  }
}
