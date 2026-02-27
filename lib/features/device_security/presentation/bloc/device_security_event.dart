import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/staff.dart';
import '../../domain/entities/device_info.dart';

abstract class DeviceSecurityEvent extends Equatable {
  const DeviceSecurityEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize and check device status
class CheckDeviceStatusRequested extends DeviceSecurityEvent {
  final Staff staff;

  const CheckDeviceStatusRequested(this.staff);

  @override
  List<Object?> get props => [staff];
}

/// Request OTP to be sent
class SendOtpRequested extends DeviceSecurityEvent {
  const SendOtpRequested();
}

/// Request OTP with phone number (for first-time device verification)
class SendOtpWithPhoneRequested extends DeviceSecurityEvent {
  final String phone;
  final DeviceInfo deviceInfo;
  final int? staffId; // Staff ID for validation - ensures phone belongs to logged-in staff

  const SendOtpWithPhoneRequested({
    required this.phone,
    required this.deviceInfo,
    this.staffId,
  });

  @override
  List<Object?> get props => [phone, deviceInfo, staffId];
}

/// Verify OTP code
class VerifyOtpRequested extends DeviceSecurityEvent {
  final String otp;

  const VerifyOtpRequested(this.otp);

  @override
  List<Object?> get props => [otp];
}

/// Verify OTP code with phone number (before login)
class VerifyOtpWithPhoneRequested extends DeviceSecurityEvent {
  final String phone;
  final String otp;
  final String fingerprint;

  const VerifyOtpWithPhoneRequested({
    required this.phone,
    required this.otp,
    required this.fingerprint,
  });

  @override
  List<Object?> get props => [phone, otp, fingerprint];
}

/// Resend OTP
class ResendOtpRequested extends DeviceSecurityEvent {
  const ResendOtpRequested();
}
