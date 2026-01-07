import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_info.dart';
import '../entities/otp_response.dart';
import '../repositories/device_security_repository.dart';

/// Use case for sending OTP with phone number
/// Used for first-time device verification when staff_id is not yet known
@injectable
class SendOtpWithPhoneUseCase {
  final DeviceSecurityRepository _repository;

  SendOtpWithPhoneUseCase(this._repository);

  /// Send OTP to the provided phone number
  /// [phone] - The phone number to send OTP to
  /// [deviceInfo] - The device information for registration
  Future<Either<Failure, OtpResponse>> call({
    required String phone,
    required DeviceInfo deviceInfo,
  }) {
    return _repository.sendOtpWithPhone(phone, deviceInfo);
  }
}
