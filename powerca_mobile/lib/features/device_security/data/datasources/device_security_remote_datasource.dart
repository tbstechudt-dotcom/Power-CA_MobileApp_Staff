import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../models/device_info_model.dart';
import '../models/device_status_model.dart';
import '../models/otp_response_model.dart';

abstract class DeviceSecurityRemoteDataSource {
  /// Check device status via RPC
  Future<DeviceStatusModel> checkDeviceStatus(int staffId, String fingerprint);

  /// Check device status by fingerprint only (no staff_id)
  Future<DeviceStatusModel> checkDeviceStatusByFingerprint(String fingerprint);

  /// Send OTP via RPC
  Future<OtpResponseModel> sendOtp(int staffId, DeviceInfoModel deviceInfo);

  /// Send OTP via phone number (for first-time verification)
  Future<OtpResponseModel> sendOtpWithPhone(String phone, DeviceInfoModel deviceInfo);

  /// Verify OTP via RPC
  Future<OtpVerificationResponseModel> verifyOtp(
    int staffId,
    String fingerprint,
    String otp,
  );

  /// Verify OTP via phone number
  Future<OtpVerificationResponseModel> verifyOtpWithPhone(
    String phone,
    String fingerprint,
    String otp,
  );
}

@LazySingleton(as: DeviceSecurityRemoteDataSource)
class DeviceSecurityRemoteDataSourceImpl
    implements DeviceSecurityRemoteDataSource {
  final SupabaseClient supabaseClient;

  DeviceSecurityRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<DeviceStatusModel> checkDeviceStatus(
    int staffId,
    String fingerprint,
  ) async {
    final response = await supabaseClient.rpc(
      'check_device_status',
      params: {
        'p_staff_id': staffId,
        'p_device_fingerprint': fingerprint,
      },
    );

    if (response == null) {
      return const DeviceStatusModel(
        deviceRegistered: false,
        isVerified: false,
      );
    }

    return DeviceStatusModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<DeviceStatusModel> checkDeviceStatusByFingerprint(
    String fingerprint,
  ) async {
    final response = await supabaseClient.rpc(
      'check_device_status_by_fingerprint',
      params: {
        'p_device_fingerprint': fingerprint,
      },
    );

    if (response == null) {
      return const DeviceStatusModel(
        deviceRegistered: false,
        isVerified: false,
      );
    }

    return DeviceStatusModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<OtpResponseModel> sendOtp(
    int staffId,
    DeviceInfoModel deviceInfo,
  ) async {
    final response = await supabaseClient.rpc(
      'send_device_verification_otp',
      params: {
        'p_staff_id': staffId,
        'p_device_fingerprint': deviceInfo.fingerprint,
        'p_device_name': deviceInfo.deviceName,
        'p_device_model': deviceInfo.deviceModel,
        'p_platform': deviceInfo.platform,
      },
    );

    if (response == null) {
      return const OtpResponseModel(
        success: false,
        error: 'NO_RESPONSE',
        message: 'No response from server',
      );
    }

    return OtpResponseModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<OtpResponseModel> sendOtpWithPhone(
    String phone,
    DeviceInfoModel deviceInfo,
  ) async {
    // Call Edge Function for real SMS OTP via Twilio
    final url = Uri.parse('${SupabaseConfig.url}/functions/v1/send-otp-sms');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'apikey': SupabaseConfig.anonKey,
      },
      body: json.encode({
        'phone': phone,
        'device_fingerprint': deviceInfo.fingerprint,
        'device_name': deviceInfo.deviceName,
        'device_model': deviceInfo.deviceModel,
        'platform': deviceInfo.platform,
      }),
    );

    if (response.statusCode != 200) {
      final errorBody = json.decode(response.body);
      return OtpResponseModel(
        success: false,
        error: errorBody['error'] ?? 'REQUEST_FAILED',
        message: errorBody['message'] ?? 'Failed to send OTP',
      );
    }

    final responseData = json.decode(response.body) as Map<String, dynamic>;
    return OtpResponseModel.fromJson(responseData);
  }

  @override
  Future<OtpVerificationResponseModel> verifyOtp(
    int staffId,
    String fingerprint,
    String otp,
  ) async {
    final response = await supabaseClient.rpc(
      'verify_device_otp',
      params: {
        'p_staff_id': staffId,
        'p_device_fingerprint': fingerprint,
        'p_otp': otp,
      },
    );

    if (response == null) {
      return const OtpVerificationResponseModel(
        success: false,
        error: 'NO_RESPONSE',
        message: 'No response from server',
      );
    }

    return OtpVerificationResponseModel.fromJson(
      response as Map<String, dynamic>,
    );
  }

  @override
  Future<OtpVerificationResponseModel> verifyOtpWithPhone(
    String phone,
    String fingerprint,
    String otp,
  ) async {
    // Call Edge Function for OTP verification
    final url = Uri.parse('${SupabaseConfig.url}/functions/v1/verify-otp-sms');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'apikey': SupabaseConfig.anonKey,
      },
      body: json.encode({
        'phone': phone,
        'device_fingerprint': fingerprint,
        'otp': otp,
      }),
    );

    if (response.statusCode != 200) {
      final errorBody = json.decode(response.body);
      return OtpVerificationResponseModel(
        success: false,
        error: errorBody['error'] ?? 'VERIFICATION_FAILED',
        message: errorBody['message'] ?? 'Failed to verify OTP',
      );
    }

    final responseData = json.decode(response.body) as Map<String, dynamic>;
    return OtpVerificationResponseModel.fromJson(responseData);
  }
}
