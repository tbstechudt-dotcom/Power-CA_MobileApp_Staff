import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/device_info.dart';
import '../repositories/device_security_repository.dart';

@lazySingleton
class GetDeviceInfoUseCase {
  final DeviceSecurityRepository repository;

  GetDeviceInfoUseCase(this.repository);

  Future<Either<Failure, DeviceInfo>> call() {
    return repository.getDeviceInfo();
  }
}
