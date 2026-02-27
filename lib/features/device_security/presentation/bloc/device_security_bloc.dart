import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/device_info.dart';
import '../../domain/usecases/check_device_status_usecase.dart';
import '../../domain/usecases/get_device_info_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/send_otp_with_phone_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import '../../domain/usecases/verify_otp_with_phone_usecase.dart';
import 'device_security_event.dart';
import 'device_security_state.dart';

@injectable
class DeviceSecurityBloc
    extends Bloc<DeviceSecurityEvent, DeviceSecurityState> {
  final CheckDeviceStatusUseCase checkDeviceStatus;
  final GetDeviceInfoUseCase getDeviceInfo;
  final SendOtpUseCase sendOtp;
  final SendOtpWithPhoneUseCase sendOtpWithPhone;
  final VerifyOtpUseCase verifyOtp;
  final VerifyOtpWithPhoneUseCase verifyOtpWithPhone;

  DeviceInfo? _currentDeviceInfo;
  int _staffId = 0;

  DeviceSecurityBloc({
    required this.checkDeviceStatus,
    required this.getDeviceInfo,
    required this.sendOtp,
    required this.sendOtpWithPhone,
    required this.verifyOtp,
    required this.verifyOtpWithPhone,
  }) : super(const DeviceSecurityInitial()) {
    on<CheckDeviceStatusRequested>(_onCheckDeviceStatus);
    on<SendOtpRequested>(_onSendOtp);
    on<SendOtpWithPhoneRequested>(_onSendOtpWithPhone);
    on<VerifyOtpRequested>(_onVerifyOtp);
    on<VerifyOtpWithPhoneRequested>(_onVerifyOtpWithPhone);
    on<ResendOtpRequested>(_onResendOtp);
  }

  Future<void> _onCheckDeviceStatus(
    CheckDeviceStatusRequested event,
    Emitter<DeviceSecurityState> emit,
  ) async {
    emit(const DeviceSecurityLoading(message: 'Checking device status...'));

    _staffId = event.staff.staffId;

    // Get device info first
    final deviceInfoResult = await getDeviceInfo();

    await deviceInfoResult.fold(
      (failure) async {
        emit(DeviceSecurityError(message: failure.message));
      },
      (deviceInfo) async {
        _currentDeviceInfo = deviceInfo;

        // Check device status
        final statusResult = await checkDeviceStatus(
          staffId: _staffId,
          fingerprint: deviceInfo.fingerprint,
        );

        statusResult.fold(
          (failure) {
            emit(DeviceSecurityError(message: failure.message));
          },
          (status) {
            if (status.isVerified) {
              // Device verified - proceed to login
              emit(DeviceVerified(deviceInfo: deviceInfo));
            } else {
              // Device not verified - need OTP
              emit(DeviceStatusChecked(
                status: status,
                deviceInfo: deviceInfo,
              ));
            }
          },
        );
      },
    );
  }

  Future<void> _onSendOtp(
    SendOtpRequested event,
    Emitter<DeviceSecurityState> emit,
  ) async {
    if (_currentDeviceInfo == null) {
      emit(const DeviceSecurityError(
        message: 'Device info not available. Please try again.',
      ));
      return;
    }

    emit(const DeviceSecurityLoading(message: 'Sending OTP...'));

    final result = await sendOtp(
      staffId: _staffId,
      deviceInfo: _currentDeviceInfo!,
    );

    result.fold(
      (failure) {
        emit(DeviceSecurityError(
          message: failure.message,
          previousState: state,
        ));
      },
      (response) {
        emit(OtpSent(
          maskedPhone: response.phoneMasked ?? '',
          expiresInSeconds: response.expiresInSeconds ?? 300,
          deviceInfo: _currentDeviceInfo!,
        ));
      },
    );
  }

  Future<void> _onSendOtpWithPhone(
    SendOtpWithPhoneRequested event,
    Emitter<DeviceSecurityState> emit,
  ) async {
    emit(const DeviceSecurityLoading(message: 'Sending OTP...'));

    // Convert DeviceInfoModel to DeviceInfo for the use case
    final deviceInfo = DeviceInfo(
      fingerprint: event.deviceInfo.fingerprint,
      deviceName: event.deviceInfo.deviceName,
      deviceModel: event.deviceInfo.deviceModel,
      platform: event.deviceInfo.platform,
    );

    // Pass staffId for server-side validation (ensures phone belongs to logged-in staff)
    final result = await sendOtpWithPhone(
      phone: event.phone,
      deviceInfo: deviceInfo,
      staffId: event.staffId,
    );

    result.fold(
      (failure) {
        emit(DeviceSecurityError(
          message: failure.message,
          previousState: state,
        ));
      },
      (response) {
        // Store device info for later use
        _currentDeviceInfo = deviceInfo;

        emit(OtpSent(
          maskedPhone: response.phoneMasked ?? '',
          expiresInSeconds: response.expiresInSeconds ?? 300,
          deviceInfo: deviceInfo,
        ));
      },
    );
  }

  Future<void> _onVerifyOtp(
    VerifyOtpRequested event,
    Emitter<DeviceSecurityState> emit,
  ) async {
    if (_currentDeviceInfo == null) {
      emit(const DeviceSecurityError(
        message: 'Device info not available. Please try again.',
      ));
      return;
    }

    emit(const OtpVerifying());

    final result = await verifyOtp(
      staffId: _staffId,
      fingerprint: _currentDeviceInfo!.fingerprint,
      otp: event.otp,
    );

    result.fold(
      (failure) {
        emit(DeviceSecurityError(
          message: failure.message,
          previousState: OtpSent(
            maskedPhone: '',
            expiresInSeconds: 300,
            deviceInfo: _currentDeviceInfo!,
          ),
        ));
      },
      (response) {
        if (response.success) {
          emit(OtpVerified(deviceInfo: _currentDeviceInfo!));
        } else {
          emit(DeviceSecurityError(
            message: response.error ?? 'Invalid OTP. Please try again.',
            previousState: OtpSent(
              maskedPhone: '',
              expiresInSeconds: 300,
              deviceInfo: _currentDeviceInfo!,
            ),
          ));
        }
      },
    );
  }

  Future<void> _onVerifyOtpWithPhone(
    VerifyOtpWithPhoneRequested event,
    Emitter<DeviceSecurityState> emit,
  ) async {
    emit(const OtpVerifying());

    final result = await verifyOtpWithPhone(
      phone: event.phone,
      fingerprint: event.fingerprint,
      otp: event.otp,
    );

    result.fold(
      (failure) {
        emit(DeviceSecurityError(
          message: failure.message,
          previousState: OtpSent(
            maskedPhone: '',
            expiresInSeconds: 300,
            deviceInfo: _currentDeviceInfo ?? DeviceInfo(
              fingerprint: event.fingerprint,
              deviceName: '',
              deviceModel: '',
              platform: '',
            ),
          ),
        ));
      },
      (response) {
        if (response.success) {
          // Create device info if not available
          final deviceInfo = _currentDeviceInfo ?? DeviceInfo(
            fingerprint: event.fingerprint,
            deviceName: '',
            deviceModel: '',
            platform: '',
          );
          // Emit with phone, staffId, and staffName for local storage
          emit(OtpVerified(
            deviceInfo: deviceInfo,
            phoneNumber: event.phone,
            staffId: response.staffId,
            staffName: response.staffName,
          ));
        } else {
          emit(DeviceSecurityError(
            message: response.error ?? 'Invalid OTP. Please try again.',
            previousState: OtpSent(
              maskedPhone: '',
              expiresInSeconds: 300,
              deviceInfo: _currentDeviceInfo ?? DeviceInfo(
                fingerprint: event.fingerprint,
                deviceName: '',
                deviceModel: '',
                platform: '',
              ),
            ),
          ));
        }
      },
    );
  }

  Future<void> _onResendOtp(
    ResendOtpRequested event,
    Emitter<DeviceSecurityState> emit,
  ) async {
    // Same as send OTP but can be rate limited
    add(const SendOtpRequested());
  }
}
