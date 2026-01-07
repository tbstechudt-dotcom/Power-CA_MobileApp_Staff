import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../bloc/device_security_bloc.dart';
import '../bloc/device_security_event.dart';
import '../bloc/device_security_state.dart';
import '../widgets/otp_input_field.dart';

class OtpVerificationPage extends StatefulWidget {
  final String maskedPhone;
  final int expiresInSeconds;
  final String? phoneNumber; // Actual phone number for verification
  final String? fingerprint; // Device fingerprint for verification

  const OtpVerificationPage({
    super.key,
    required this.maskedPhone,
    required this.expiresInSeconds,
    this.phoneNumber,
    this.fingerprint,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  late int _remainingSeconds;
  Timer? _timer;
  bool _canResend = false;
  String _otpValue = '';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.expiresInSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _onOtpCompleted(String otp) {
    setState(() {
      _otpValue = otp;
      _hasError = false;
    });

    // Use phone-based verification if phone number and fingerprint are provided
    if (widget.phoneNumber != null && widget.fingerprint != null) {
      context.read<DeviceSecurityBloc>().add(VerifyOtpWithPhoneRequested(
        phone: widget.phoneNumber!,
        fingerprint: widget.fingerprint!,
        otp: otp,
      ));
    } else {
      // Fallback to staff-based verification
      context.read<DeviceSecurityBloc>().add(VerifyOtpRequested(otp));
    }
  }

  void _onResendOtp() {
    if (_canResend) {
      context.read<DeviceSecurityBloc>().add(const ResendOtpRequested());
      setState(() {
        _canResend = false;
        _remainingSeconds = 60; // 1 minute cooldown for resend
      });
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: AppTheme.textPrimaryColor,
            size: 20.sp,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocListener<DeviceSecurityBloc, DeviceSecurityState>(
        listener: (context, state) async {
          if (state is DeviceSecurityError) {
            setState(() {
              _hasError = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is OtpVerified) {
            // OTP verified - navigate to login page
            // Device is now verified, user needs to login
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device verified successfully! Please login.'),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate to splash/login page
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/splash',
              (route) => false,
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40.h),
                // Icon
                Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_android,
                    size: 40.sp,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(height: 32.h),
                // Title
                Text(
                  'Verify Your Phone',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 12.h),
                // Description
                Text(
                  'We\'ve sent a 6-digit OTP to',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  widget.maskedPhone,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 48.h),
                // OTP Input
                OtpInputField(
                  length: 6,
                  onCompleted: _onOtpCompleted,
                  hasError: _hasError,
                  onChanged: (value) {
                    setState(() {
                      _otpValue = value;
                      _hasError = false;
                    });
                  },
                ),
                SizedBox(height: 32.h),
                // Timer / Resend
                if (!_canResend)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18.sp,
                        color: AppTheme.textMutedColor,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Expires in $_formattedTime',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMutedColor,
                        ),
                      ),
                    ],
                  )
                else
                  TextButton(
                    onPressed: _onResendOtp,
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                const Spacer(),
                // Verify Button
                BlocBuilder<DeviceSecurityBloc, DeviceSecurityState>(
                  builder: (context, state) {
                    final isLoading = state is OtpVerifying;
                    return SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: _otpValue.length == 6 && !isLoading
                            ? () => _onOtpCompleted(_otpValue)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Verify',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
