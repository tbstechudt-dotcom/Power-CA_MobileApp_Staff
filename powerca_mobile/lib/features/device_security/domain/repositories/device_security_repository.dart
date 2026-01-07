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
  Future<Either<Failure, OtpResponse>> sendOtpWithPhone(
    String phone,
    DeviceInfo deviceInfo,
  );

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
}
