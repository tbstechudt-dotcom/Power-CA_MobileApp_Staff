import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/otp_response.dart';
import '../repositories/device_security_repository.dart';

@lazySingleton
class VerifyOtpUseCase {
  final DeviceSecurityRepository repository;

  VerifyOtpUseCase(this.repository);

  Future<Either<Failure, OtpVerificationResponse>> call({
    required int staffId,
    required String fingerprint,
    required String otp,
  }) {
    return repository.verifyOtp(staffId, fingerprint, otp);
  }
}
