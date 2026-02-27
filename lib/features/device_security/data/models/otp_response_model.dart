import '../../domain/entities/otp_response.dart';

class OtpResponseModel extends OtpResponse {
  const OtpResponseModel({
    required super.success,
    super.phoneMasked,
    super.expiresInSeconds,
    super.error,
    super.message,
    super.otp,
  });

  factory OtpResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpResponseModel(
      success: json['success'] ?? false,
      phoneMasked: json['phone_masked'],
      expiresInSeconds: json['expires_in_seconds'],
      error: json['error'],
      message: json['message'],
      otp: json['otp'], // Only for testing
    );
  }

  OtpResponse toEntity() => OtpResponse(
        success: success,
        phoneMasked: phoneMasked,
        expiresInSeconds: expiresInSeconds,
        error: error,
        message: message,
        otp: otp,
      );
}

class OtpVerificationResponseModel extends OtpVerificationResponse {
  const OtpVerificationResponseModel({
    required super.success,
    super.error,
    super.message,
    super.remainingAttempts,
    super.staffId,
    super.staffName,
  });

  factory OtpVerificationResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpVerificationResponseModel(
      success: json['success'] ?? false,
      error: json['error'],
      message: json['message'],
      remainingAttempts: json['remaining_attempts'],
      staffId: json['staff_id'],
      staffName: json['staff_name'],
    );
  }

  OtpVerificationResponse toEntity() => OtpVerificationResponse(
        success: success,
        error: error,
        message: message,
        remainingAttempts: remainingAttempts,
        staffId: staffId,
        staffName: staffName,
      );
}
