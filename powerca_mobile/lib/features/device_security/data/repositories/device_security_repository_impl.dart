import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/device_info.dart';
import '../../domain/entities/device_status.dart';
import '../../domain/entities/otp_response.dart';
import '../../domain/repositories/device_security_repository.dart';
import '../datasources/device_security_local_datasource.dart';
import '../datasources/device_security_remote_datasource.dart';
import '../models/device_info_model.dart';

@LazySingleton(as: DeviceSecurityRepository)
class DeviceSecurityRepositoryImpl implements DeviceSecurityRepository {
  final DeviceSecurityRemoteDataSource remoteDataSource;
  final DeviceSecurityLocalDataSource localDataSource;

  // Cache staff ID for device info generation
  int? _currentStaffId;

  DeviceSecurityRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  /// Set current staff ID for fingerprint generation
  @override
  void setStaffId(int staffId) {
    _currentStaffId = staffId;
  }

  @override
  Future<Either<Failure, DeviceInfo>> getDeviceInfo() async {
    try {
      // Use staff ID if available, otherwise use 0 for device-only fingerprint
      final staffId = _currentStaffId ?? 0;
      final deviceInfo = await DeviceInfoModel.fromDevice(staffId);

      // Store fingerprint locally
      await localDataSource.storeDeviceFingerprint(deviceInfo.fingerprint);

      return Right(deviceInfo.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to get device info: $e'));
    }
  }

  @override
  Future<Either<Failure, DeviceStatus>> checkDeviceStatus(
    int staffId,
    String fingerprint,
  ) async {
    try {
      _currentStaffId = staffId;
      final status = await remoteDataSource.checkDeviceStatus(
        staffId,
        fingerprint,
      );
      return Right(status.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to check device status: $e'));
    }
  }

  @override
  Future<Either<Failure, DeviceStatus>> checkDeviceStatusByFingerprint(
    String fingerprint,
  ) async {
    try {
      final status = await remoteDataSource.checkDeviceStatusByFingerprint(
        fingerprint,
      );
      return Right(status.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to check device status: $e'));
    }
  }

  @override
  Future<Either<Failure, OtpResponse>> sendOtp(
    int staffId,
    DeviceInfo deviceInfo,
  ) async {
    try {
      final deviceInfoModel = DeviceInfoModel(
        fingerprint: deviceInfo.fingerprint,
        deviceName: deviceInfo.deviceName,
        deviceModel: deviceInfo.deviceModel,
        platform: deviceInfo.platform,
      );

      final response = await remoteDataSource.sendOtp(staffId, deviceInfoModel);

      if (!response.success) {
        return Left(ServerFailure(response.message ?? 'Failed to send OTP'));
      }

      return Right(response.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to send OTP: $e'));
    }
  }

  @override
  Future<Either<Failure, OtpResponse>> sendOtpWithPhone(
    String phone,
    DeviceInfo deviceInfo,
  ) async {
    try {
      final deviceInfoModel = DeviceInfoModel(
        fingerprint: deviceInfo.fingerprint,
        deviceName: deviceInfo.deviceName,
        deviceModel: deviceInfo.deviceModel,
        platform: deviceInfo.platform,
      );

      final response = await remoteDataSource.sendOtpWithPhone(phone, deviceInfoModel);

      if (!response.success) {
        return Left(ServerFailure(response.message ?? 'Failed to send OTP'));
      }

      return Right(response.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to send OTP: $e'));
    }
  }

  @override
  Future<Either<Failure, OtpVerificationResponse>> verifyOtp(
    int staffId,
    String fingerprint,
    String otp,
  ) async {
    try {
      final response = await remoteDataSource.verifyOtp(
        staffId,
        fingerprint,
        otp,
      );

      if (!response.success) {
        return Left(ServerFailure(response.message ?? 'Invalid OTP'));
      }

      return Right(response.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to verify OTP: $e'));
    }
  }

  @override
  Future<Either<Failure, OtpVerificationResponse>> verifyOtpWithPhone(
    String phone,
    String fingerprint,
    String otp,
  ) async {
    try {
      final response = await remoteDataSource.verifyOtpWithPhone(
        phone,
        fingerprint,
        otp,
      );

      if (!response.success) {
        return Left(ServerFailure(response.message ?? 'Invalid OTP'));
      }

      return Right(response.toEntity());
    } catch (e) {
      return Left(ServerFailure('Failed to verify OTP: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSecurityData() async {
    try {
      await localDataSource.clearAll();
      _currentStaffId = null;
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to clear security data: $e'));
    }
  }

  @override
  Future<void> storeDeviceFingerprint(String fingerprint) async {
    await localDataSource.storeDeviceFingerprint(fingerprint);
  }

  @override
  Future<String?> getStoredFingerprint() async {
    return localDataSource.getDeviceFingerprint();
  }
}
