import 'package:equatable/equatable.dart';

import '../../domain/entities/device_info.dart';
import '../../domain/entities/device_status.dart';

/// Base state for device security
abstract class DeviceSecurityState extends Equatable {
  const DeviceSecurityState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no checks performed yet
class DeviceSecurityInitial extends DeviceSecurityState {
  const DeviceSecurityInitial();
}

/// Loading state - performing async operation
class DeviceSecurityLoading extends DeviceSecurityState {
  final String message;

  const DeviceSecurityLoading({this.message = 'Loading...'});

  @override
  List<Object?> get props => [message];
}

/// Device check completed - device not verified
class DeviceStatusChecked extends DeviceSecurityState {
  final DeviceStatus status;
  final DeviceInfo deviceInfo;

  const DeviceStatusChecked({
    required this.status,
    required this.deviceInfo,
  });

  @override
  List<Object?> get props => [status, deviceInfo];
}

/// Device already verified - proceed to login
class DeviceVerified extends DeviceSecurityState {
  final DeviceInfo deviceInfo;

  const DeviceVerified({required this.deviceInfo});

  @override
  List<Object?> get props => [deviceInfo];
}

/// OTP sent successfully - waiting for user to enter OTP
class OtpSent extends DeviceSecurityState {
  final String maskedPhone;
  final int expiresInSeconds;
  final DeviceInfo deviceInfo;

  const OtpSent({
    required this.maskedPhone,
    required this.expiresInSeconds,
    required this.deviceInfo,
  });

  @override
  List<Object?> get props => [maskedPhone, expiresInSeconds, deviceInfo];
}

/// OTP verification in progress
class OtpVerifying extends DeviceSecurityState {
  const OtpVerifying();
}

/// OTP verified successfully - device is now verified
class OtpVerified extends DeviceSecurityState {
  final DeviceInfo deviceInfo;

  const OtpVerified({required this.deviceInfo});

  @override
  List<Object?> get props => [deviceInfo];
}

/// Error state
class DeviceSecurityError extends DeviceSecurityState {
  final String message;
  final DeviceSecurityState? previousState;

  const DeviceSecurityError({
    required this.message,
    this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];
}

/// OTP resend cooldown state
class OtpResendCooldown extends DeviceSecurityState {
  final int remainingSeconds;
  final DeviceInfo deviceInfo;

  const OtpResendCooldown({
    required this.remainingSeconds,
    required this.deviceInfo,
  });

  @override
  List<Object?> get props => [remainingSeconds, deviceInfo];
}
