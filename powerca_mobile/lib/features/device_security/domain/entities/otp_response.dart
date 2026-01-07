import 'package:equatable/equatable.dart';

/// Response from OTP send request
class OtpResponse extends Equatable {
  final bool success;
  final String? phoneMasked;
  final int? expiresInSeconds;
  final String? error;
  final String? message;
  final String? otp; // Only for testing - remove in production

  const OtpResponse({
    required this.success,
    this.phoneMasked,
    this.expiresInSeconds,
    this.error,
    this.message,
    this.otp,
  });

  @override
  List<Object?> get props => [success, phoneMasked, expiresInSeconds, error, message];
}

/// Response from OTP verification
class OtpVerificationResponse extends Equatable {
  final bool success;
  final String? error;
  final String? message;
  final int? remainingAttempts;

  const OtpVerificationResponse({
    required this.success,
    this.error,
    this.message,
    this.remainingAttempts,
  });

  @override
  List<Object?> get props => [success, error, message, remainingAttempts];
}
