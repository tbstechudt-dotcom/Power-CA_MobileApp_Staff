import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/injection.dart';
import '../../../../shared/widgets/auth_sheet.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../domain/repositories/device_security_repository.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Skips the phone / OTP step in every build type when true.
/// Must stay false in released builds.
const bool _skipPhoneVerification = false;

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
      final isVerified = _skipPhoneVerification ||
          await securityRepository.isDeviceVerifiedLocally();

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
      debugPrint('[OTP] Step 1: getDeviceInfo() starting...');
      final securityRepository = getIt<DeviceSecurityRepository>();

      // Get device info (still needed for device tracking in backend)
      final deviceInfoResult = await securityRepository.getDeviceInfo();
      debugPrint('[OTP] Step 2: getDeviceInfo() returned');

      if (!mounted) return;

      deviceInfoResult.fold(
        (failure) {
          debugPrint('[OTP] getDeviceInfo failure: ${failure.message}');
          setState(() {
            _error = 'Failed to initialize: ${failure.message}';
            _isSendingOtp = false;
          });
        },
        (deviceInfo) async {
          debugPrint('[OTP] Step 3: sendOtpWithPhone() starting (phone=$phone)...');
          // Send OTP using phone number
          final otpResult = await securityRepository.sendOtpWithPhone(
            phone,
            deviceInfo,
          );
          debugPrint('[OTP] Step 4: sendOtpWithPhone() returned');

          if (!mounted) return;

          otpResult.fold(
            (failure) {
              debugPrint('[OTP] sendOtpWithPhone failure: ${failure.message}');
              setState(() {
                _error = failure.message;
                _isSendingOtp = false;
              });
            },
            (otpResponse) {
              debugPrint('[OTP] Step 5: navigating to /otp-verification');
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
      debugPrint('[OTP] Outer catch: $e');
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
    final p = SoftPalette.of(context);
    if (_isCheckingVerification) {
      return AuthSheet(
        title: 'Just a moment',
        subtitle: 'Checking this device...',
        icon: Icons.verified_user_outlined,
        children: [
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: p.ink),
            ),
          ),
        ],
      );
    }
    return _buildPhoneInputView(p);
  }

  Widget _buildPhoneInputView(SoftPalette p) {
    return AuthSheet(
      title: 'Verify your phone',
      subtitle:
          "Enter your registered mobile number. We'll send you a 6-digit code.",
      icon: Icons.smartphone_rounded,
      note: 'Use the number registered with your office.',
      children: [
        const SoftFieldLabel('Mobile number'),
        // Phone input field
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: softInputTextStyle(context),
          decoration: softInputDecoration(
            context,
            hint: 'Enter 10-digit number',
            prefixText: '+91',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _error!),
        ],
        const SizedBox(height: 20),
        // Send OTP button
        SoftPillButton(
          label: 'Send OTP',
          loading: _isSendingOtp,
          onPressed: _isSendingOtp ? null : _sendOtpWithPhone,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.tint(p.danger),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: p.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: SoftText.body(p, size: 13, color: p.danger)),
          ),
        ],
      ),
    );
  }
}
