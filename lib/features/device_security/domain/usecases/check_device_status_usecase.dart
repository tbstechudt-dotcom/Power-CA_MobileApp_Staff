import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_status.dart';
import '../repositories/device_security_repository.dart';

@lazySingleton
class CheckDeviceStatusUseCase {
  final DeviceSecurityRepository repository;

  CheckDeviceStatusUseCase(this.repository);

  Future<Either<Failure, DeviceStatus>> call({
    required int staffId,
    required String fingerprint,
  }) {
    return repository.checkDeviceStatus(staffId, fingerprint);
  }
}
