import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../../device_security/domain/repositories/device_security_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Sign In Page
/// User authentication page with username and password
/// Design from Figma: Sign in Screen
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthBloc>(),
      child: const _SignInPageContent(),
    );
  }
}

class _SignInPageContent extends StatefulWidget {
  const _SignInPageContent();

  @override
  State<_SignInPageContent> createState() => _SignInPageContentState();
}

class _SignInPageContentState extends State<_SignInPageContent> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSignIn() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Dispatch sign in event to BLoC
    context.read<AuthBloc>().add(
          SignInRequested(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  /// Check if logged-in staff matches the locally verified staff
  /// This is the simplified staff ID-based verification
  Future<void> _checkPhoneVerification(
    BuildContext context,
    Authenticated state,
    DeviceSecurityRepository securityRepository,
  ) async {
    // Check if device has verified staff locally
    final isVerified = await securityRepository.isDeviceVerifiedLocally();

    // Debug: Log verification status
    debugPrint('=== Staff Verification Check ===');
    debugPrint('Device verified locally: $isVerified');
    debugPrint('Logged in staff ID: ${state.staff.staffId}');
    debugPrint('Logged in staff name: ${state.staff.name}');

    if (!context.mounted) return;

    if (!isVerified) {
      // No staff verified on this device - redirect to security gate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your phone number first.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pushReplacementNamed(context, '/security-gate');
      return;
    }

    // Get the verified staff ID and name from local storage
    final verifiedStaffId = await securityRepository.getVerifiedStaffId();
    final verifiedStaffName = await securityRepository.getVerifiedStaffName();

    // Debug: Log verified staff info
    debugPrint('Verified staff ID from storage: $verifiedStaffId');
    debugPrint('Verified staff name from storage: $verifiedStaffName');

    if (!context.mounted) return;

    if (verifiedStaffId == null) {
      // No verified staff stored - redirect to security gate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your phone number first.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pushReplacementNamed(context, '/security-gate');
      return;
    }

    // Debug: Log comparison
    debugPrint('Staff IDs match: ${state.staff.staffId == verifiedStaffId}');

    // Compare staff IDs
    if (state.staff.staffId == verifiedStaffId) {
      // Staff ID matches - allow login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome, ${state.staff.name}!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        '/select-concern-location',
        arguments: state.staff,
      );
    } else {
      // Staff ID doesn't match - this device is verified for another staff
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This device belongs to ${verifiedStaffName ?? 'another staff member'}. '
            'Please login with that account\'s credentials, or contact admin to reassign this device.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      // Don't navigate - stay on login page
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is Authenticated) {
          // Simplified phone-based verification (no fingerprint)
          final securityRepository = getIt<DeviceSecurityRepository>();
          await _checkPhoneVerification(context, state, securityRepository);
        } else if (state is AuthError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC), // Background color from Figma
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // PowerCA Logo
                      Image.asset(
                        'assets/images/Logo/Power CA Logo Only-04.png',
                        width: 120.w,
                        height: 100.h,
                      ),

                      SizedBox(height: 32.h),

                      // Welcome text
                      Text(
                        'Welcome Back!',
                        style: GoogleFonts.inter(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),

                      SizedBox(height: 8.h),

                      // Subtitle
                      Text(
                        'Enter your details to log in and continue\nwhere you left off.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textMutedColor,
                          height: 1.5,
                        ),
                      ),

                      SizedBox(height: 40.h),

                      // Username label
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Username',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),

                      SizedBox(height: 8.h),

                      // Username field
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Enter Your Username',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMutedColor,
                          ),
                          prefixIcon: Icon(Icons.person_outline,
                            color: AppTheme.textMutedColor,
                            size: 22.sp,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: AppTheme.textMutedColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: AppTheme.textMutedColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 20.h),

                      // Password label
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Password',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),

                      SizedBox(height: 8.h),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Enter Your Password',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMutedColor,
                          ),
                          prefixIcon: Icon(Icons.lock_outline,
                            color: AppTheme.textMutedColor,
                            size: 22.sp,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textMutedColor,
                              size: 22.sp,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: AppTheme.textMutedColor,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: AppTheme.textMutedColor,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 16.h),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 32.h),

                      // Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Sign in',
                                      style: GoogleFonts.inter(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.arrow_forward,
                                      size: 18.sp,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
