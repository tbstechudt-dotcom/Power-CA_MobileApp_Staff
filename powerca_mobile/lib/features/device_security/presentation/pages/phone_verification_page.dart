import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/injection.dart';
import '../../../../shared/widgets/auth_sheet.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../domain/entities/device_info.dart';
import '../bloc/device_security_bloc.dart';
import '../bloc/device_security_event.dart';
import '../bloc/device_security_state.dart';

/// Phone Verification Page
/// First step of device verification - user enters phone number
/// Phone must exist in staff table (validated by server via OTP)
class PhoneVerificationPage extends StatefulWidget {
  final DeviceInfo deviceInfo;
  final int? staffId;

  const PhoneVerificationPage({
    super.key,
    required this.deviceInfo,
    this.staffId,
  });

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  late final DeviceSecurityBloc _bloc = getIt<DeviceSecurityBloc>();
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Normalize phone number by removing spaces and country code
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

  /// Validate phone number (10 digits)
  bool _isValidPhone(String phone) {
    final normalized = _normalizePhone(phone);
    return normalized.length == 10 && RegExp(r'^\d{10}$').hasMatch(normalized);
  }

  /// Send OTP to the entered phone number
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _normalizePhone(_phoneController.text.trim());

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // Send OTP via BLoC - include staffId for server-side validation
    // This ensures the phone number belongs to the logged-in staff
    if (mounted) {
      // Use the bloc owned by this page: the State's own context sits above
      // the BlocProvider created in build(), so context.read would fail.
      _bloc.add(
        SendOtpWithPhoneRequested(
          phone: phone,
          deviceInfo: widget.deviceInfo,
          staffId: widget.staffId, // Validate phone belongs to this staff
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: BlocConsumer<DeviceSecurityBloc, DeviceSecurityState>(
        listener: (context, state) {
          if (state is OtpSent) {
            setState(() {
              _isLoading = false;
            });
            // Navigate to OTP verification page
            Navigator.pushReplacementNamed(
              context,
              '/otp-verification',
              arguments: {
                'maskedPhone': state.maskedPhone,
                'expiresInSeconds': state.expiresInSeconds,
                'phoneNumber': _normalizePhone(_phoneController.text.trim()),
                'fingerprint': widget.deviceInfo.fingerprint,
              },
            );
          } else if (state is DeviceSecurityError) {
            setState(() {
              _isLoading = false;
              _errorMessage = state.message;
            });
          }
        },
        builder: (context, state) {
          final p = SoftPalette.of(context);
          return AuthSheet(
            title: 'Verify your phone',
            subtitle:
                "Enter your registered mobile number. We'll send you a 6-digit code.",
            icon: Icons.smartphone_rounded,
            note: 'Use the number registered in your staff profile.',
            showBack: true,
            onBack: () => Navigator.of(context).pop(),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Phone number field
                    const SoftFieldLabel('Mobile number'),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: softInputDecoration(
                        context,
                        hint: 'Enter 10-digit number',
                        prefixText: '+91',
                      ),
                      style: softInputTextStyle(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!_isValidPhone(value)) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                    ),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
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
                              child: Text(
                                _errorMessage!,
                                style: SoftText.body(p, size: 13, color: p.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Send OTP button
                    SoftPillButton(
                      label: 'Send OTP',
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _handleSendOtp,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
