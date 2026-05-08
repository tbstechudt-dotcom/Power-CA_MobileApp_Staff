import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../domain/repositories/device_security_repository.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Security Gate Page
/// This is the FIRST screen shown when app launches
/// Simplified Flow (No Fingerprint):
/// 1. Check if device verified locally (phone stored)
/// 2. If not verified → Enter phone → OTP → Store verification → Go to Login
/// 3. If verified → Go to Login/Dashboard
class SecurityGatePage extends StatefulWidget {
  const SecurityGatePage({super.key});

  @override
  State<SecurityGatePage> createState() => _SecurityGatePageState();
}

class _SecurityGatePageState extends State<SecurityGatePage> {
  String? _error;
  final _phoneController = TextEditingController();
  bool _isSendingOtp = false;
  bool _isCheckingVerification = true;

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

    // Check if device is already verified
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkIfAlreadyVerified();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Check if device is already verified locally (phone stored)
  /// If verified → go to login/dashboard
  /// If not verified → show phone input
  Future<void> _checkIfAlreadyVerified() async {
    try {
      final securityRepository = getIt<DeviceSecurityRepository>();

      // Check local storage for verified phone (NO fingerprint needed)
      final isVerified = await securityRepository.isDeviceVerifiedLocally();

      if (!mounted) return;

      if (isVerified) {
        // Device already verified - check if logged in
        final authRepository = getIt<AuthRepository>();
        final staffResult = await authRepository.getCurrentStaff();

        if (!mounted) return;

        staffResult.fold(
          (failure) {
            // Not logged in - go to login
            Navigator.pushReplacementNamed(context, '/splash');
          },
          (staff) {
            if (staff != null) {
              // Already logged in - go to Dashboard
              Navigator.pushReplacementNamed(
                context,
                '/dashboard',
                arguments: staff,
              );
            } else {
              // Not logged in - go to login
              Navigator.pushReplacementNamed(context, '/splash');
            }
          },
        );
      } else {
        // Not verified - show phone input
        setState(() {
          _isCheckingVerification = false;
        });
      }
    } catch (e) {
      // Error checking - show phone input
      debugPrint('Device check error: $e');
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  /// Normalize phone number
  String _normalizePhone(String phone) {
    String normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (normalized.startsWith('+91')) {
      normalized = normalized.substring(3);
    } else if (normalized.startsWith('91') && normalized.length > 10) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('0') && normalized.length == 11) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  Future<void> _sendOtpWithPhone() async {
    final phone = _normalizePhone(_phoneController.text.trim());
    if (phone.isEmpty) {
      setState(() {
        _error = 'Please enter your phone number';
      });
      return;
    }

    if (phone.length != 10) {
      setState(() {
        _error = 'Please enter a valid 10-digit phone number';
      });
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _error = null;
    });

    try {
      final securityRepository = getIt<DeviceSecurityRepository>();

      // Get device info (still needed for device tracking in backend)
      final deviceInfoResult = await securityRepository.getDeviceInfo();

      if (!mounted) return;

      deviceInfoResult.fold(
        (failure) {
          setState(() {
            _error = 'Failed to initialize: ${failure.message}';
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
              // Pass phone number for verification (no fingerprint in UI)
              Navigator.pushReplacementNamed(
                context,
                '/otp-verification',
                arguments: {
                  'maskedPhone': otpResponse.phoneMasked ?? '',
                  'expiresInSeconds': otpResponse.expiresInSeconds ?? 300,
                  'phoneNumber': phone,
                  'fingerprint': deviceInfo.fingerprint, // Still passed for backend
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
          child: _isCheckingVerification
              ? _buildLoadingView()
              : _buildPhoneInputView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
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
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        SizedBox(height: 16.h),
        Text(
          'Checking verification...',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInputView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60.h),
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

          // Phone input section
          Container(
            margin: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              children: [
                Text(
                  'Verify Your Phone',
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
                      hintText: 'Enter 10-digit phone number',
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
                      prefixText: '+91 ',
                      prefixStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
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
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
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
          SizedBox(height: 60.h),
        ],
      ),
    );
  }
}
