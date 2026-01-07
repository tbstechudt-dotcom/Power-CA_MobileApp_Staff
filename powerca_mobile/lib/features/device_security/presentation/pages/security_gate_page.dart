import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../domain/repositories/device_security_repository.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Security Gate Page
/// This is the FIRST screen shown when app launches
/// Flow: Check device verified → If not, enter phone → OTP → Then to Splash/Login
class SecurityGatePage extends StatefulWidget {
  const SecurityGatePage({super.key});

  @override
  State<SecurityGatePage> createState() => _SecurityGatePageState();
}

class _SecurityGatePageState extends State<SecurityGatePage> {
  bool _isChecking = true;
  bool _showPhoneInput = false;
  String? _error;
  final _phoneController = TextEditingController();
  bool _isSendingOtp = false;

  @override
  void initState() {
    super.initState();

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // Check security status after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkSecurityStatus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkSecurityStatus() async {
    try {
      final securityRepository = getIt<DeviceSecurityRepository>();

      // Get device info first
      final deviceInfoResult = await securityRepository.getDeviceInfo();

      if (!mounted) return;

      deviceInfoResult.fold(
        (failure) {
          setState(() {
            _error = 'Failed to get device info: ${failure.message}';
            _isChecking = false;
          });
        },
        (deviceInfo) async {
          // Check if this device is already verified (using device fingerprint only)
          final deviceStatusResult = await securityRepository.checkDeviceStatusByFingerprint(
            deviceInfo.fingerprint,
          );

          if (!mounted) return;

          deviceStatusResult.fold(
            (failure) {
              // Device not verified - show phone input
              setState(() {
                _isChecking = false;
                _showPhoneInput = true;
              });
            },
            (deviceStatus) async {
              if (deviceStatus.isVerified) {
                // Device already verified - check if staff is logged in
                final authRepository = getIt<AuthRepository>();
                final staffResult = await authRepository.getCurrentStaff();

                if (!mounted) return;

                staffResult.fold(
                  (failure) {
                    // Not logged in - go to splash/login
                    Navigator.pushReplacementNamed(context, '/splash');
                  },
                  (staff) {
                    if (staff != null) {
                      // Logged in - go directly to Dashboard
                      Navigator.pushReplacementNamed(
                        context,
                        '/dashboard',
                        arguments: staff,
                      );
                    } else {
                      // Not logged in - go to splash/login
                      Navigator.pushReplacementNamed(context, '/splash');
                    }
                  },
                );
              } else {
                // Device not verified - show phone input
                setState(() {
                  _isChecking = false;
                  _showPhoneInput = true;
                });
              }
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Security check failed: $e';
          _isChecking = false;
          _showPhoneInput = true;
        });
      }
    }
  }

  Future<void> _sendOtpWithPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _error = 'Please enter your phone number';
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _error = null;
    });

    try {
      final securityRepository = getIt<DeviceSecurityRepository>();
      final deviceInfoResult = await securityRepository.getDeviceInfo();

      if (!mounted) return;

      deviceInfoResult.fold(
        (failure) {
          setState(() {
            _error = 'Failed to get device info: ${failure.message}';
            _isSendingOtp = false;
          });
        },
        (deviceInfo) async {
          // Send OTP using phone number
          final otpResult = await securityRepository.sendOtpWithPhone(
            phone,
            deviceInfo,
          );

          if (!mounted) return;

          otpResult.fold(
            (failure) {
              setState(() {
                _error = failure.message;
                _isSendingOtp = false;
              });
            },
            (otpResponse) {
              // Navigate to OTP verification page
              Navigator.pushReplacementNamed(
                context,
                '/otp-verification',
                arguments: {
                  'maskedPhone': otpResponse.phoneMasked ?? '',
                  'expiresInSeconds': otpResponse.expiresInSeconds ?? 300,
                  'phoneNumber': phone,
                  'fingerprint': deviceInfo.fingerprint,
                },
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to send OTP: $e';
          _isSendingOtp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E40AF),
              Color(0xFF2563EB),
              Color(0xFF3B82F6),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(16.w),
                child: Image.asset(
                  'assets/images/Logo/Power CA Logo Only-04.png',
                  fit: BoxFit.contain,
                ),
              ),

              SizedBox(height: 24.h),

              // App name
              Text(
                'POWER CA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 32.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),

              SizedBox(height: 48.h),

              if (_isChecking) ...[
                // Loading indicator
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Checking security...',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ] else if (_showPhoneInput) ...[
                // Phone input section
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    children: [
                      Text(
                        'Verify Your Device',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Enter your registered phone number to receive OTP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      // Phone input field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16.sp,
                            color: AppTheme.textPrimaryColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Phone Number',
                            hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.sp,
                              color: AppTheme.textMutedColor,
                            ),
                            prefixIcon: Icon(
                              Icons.phone,
                              color: AppTheme.primaryColor,
                              size: 22.sp,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 16.h,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 12.h),
                        Text(
                          _error!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            color: Colors.red.shade200,
                          ),
                        ),
                      ],
                      SizedBox(height: 24.h),
                      // Send OTP button
                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: _isSendingOtp ? null : _sendOtpWithPhone,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: _isSendingOtp
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Send OTP',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
