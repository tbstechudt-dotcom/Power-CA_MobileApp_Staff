import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/injection.dart';
import '../../../../core/services/tab_data_cache.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../../shared/widgets/auth_sheet.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../domain/repositories/device_security_repository.dart';
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

  Future<void> _handleOtpVerified(OtpVerified state) async {
    if (!mounted) return;

    // Store phone, staffId, and staffName for future login verification
    if (state.phoneNumber != null && state.staffId != null) {
      final securityRepository = getIt<DeviceSecurityRepository>();
      await securityRepository.storeVerificationData(
        state.phoneNumber!,
        state.staffId!,
        state.staffName ?? 'Unknown',
      );
    }

    // A freshly verified device always signs in again: drop any login left
    // over from before, so the verified staff member can't land in an older
    // (possibly someone else's) session.
    try {
      await getIt<AuthRepository>().clearStaffSession();
    } catch (e) {
      debugPrint('Error clearing old session after OTP: $e');
    }
    TabDataCache.clear();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Phone verified successfully! Please login.'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate to splash/login page
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/splash',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return BlocListener<DeviceSecurityBloc, DeviceSecurityState>(
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
          // OTP verified - store verification data locally and navigate
          _handleOtpVerified(state);
        }
      },
      child: AuthSheet(
        title: 'Check your messages',
        subtitle: "We've sent a 6-digit code to",
        subtitleExtra: Text(widget.maskedPhone),
        icon: Icons.sms_outlined,
        showBack: true,
        onBack: () => Navigator.of(context).pop(),
        children: [
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
          const SizedBox(height: 18),
          // Timer
          Text(
            _canResend ? 'Code expired' : 'Code expires in $_formattedTime',
            textAlign: TextAlign.center,
            style: SoftText.caption(p, size: 13),
          ),
          const SizedBox(height: 22),
          // Verify Button
          BlocBuilder<DeviceSecurityBloc, DeviceSecurityState>(
            builder: (context, state) {
              final isLoading = state is OtpVerifying;
              return SoftPillButton(
                label: 'Verify',
                loading: isLoading,
                onPressed: _otpValue.length == 6 && !isLoading
                    ? () => _onOtpCompleted(_otpValue)
                    : null,
              );
            },
          ),
          const SizedBox(height: 6),
          // Resend (enabled once the timer runs out)
          Center(
            child: TextButton(
              onPressed: _canResend ? _onResendOtp : null,
              style: TextButton.styleFrom(
                foregroundColor: p.accent,
                disabledForegroundColor: p.muted,
              ),
              child: const Text('Resend code'),
            ),
          ),
        ],
      ),
    );
  }
}
