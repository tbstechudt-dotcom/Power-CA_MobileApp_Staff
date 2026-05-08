import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_info.dart';
import '../entities/otp_response.dart';
import '../repositories/device_security_repository.dart';

@lazySingleton
class SendOtpUseCase {
  final DeviceSecurityRepository repository;

  SendOtpUseCase(this.repository);

  Future<Either<Failure, OtpResponse>> call({
    required int staffId,
    required DeviceInfo deviceInfo,
  }) {
    return repository.sendOtp(staffId, deviceInfo);
  }
}
