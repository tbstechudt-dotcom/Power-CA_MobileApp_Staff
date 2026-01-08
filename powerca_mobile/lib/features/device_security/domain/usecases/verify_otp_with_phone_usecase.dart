import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/otp_response.dart';
import '../repositories/device_security_repository.dart';

@lazySingleton
class VerifyOtpWithPhoneUseCase {
  final DeviceSecurityRepository repository;

  VerifyOtpWithPhoneUseCase(this.repository);

  Future<Either<Failure, OtpVerificationResponse>> call({
    required String phone,
    required String fingerprint,
    required String otp,
  }) {
    return repository.verifyOtpWithPhone(phone, fingerprint, otp);
  }
}
