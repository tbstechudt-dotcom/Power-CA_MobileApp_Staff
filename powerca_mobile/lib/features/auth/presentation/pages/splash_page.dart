import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../../../core/services/priority_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../widgets/powerca_logo.dart';

/// Splash/Welcome Screen Page
/// Initial screen shown when app launches with authentication options
/// Design extracted from Figma: PowerCA App > Splash Screen 5
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    // Set status bar to light mode for white text on blue background
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // Check for existing session after a brief delay for splash display
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkExistingSession();
    });
  }

  /// Check if user has an existing session and auto-login
  Future<void> _checkExistingSession() async {
    try {
      final authRepository = getIt<AuthRepository>();
      final result = await authRepository.getCurrentStaff();

      if (!mounted) return;

      result.fold(
        (failure) {
          // No session or error - show splash screen
          setState(() {
            _isCheckingSession = false;
          });
        },
        (staff) async {
          if (staff != null) {
            // Set staff ID in PriorityService for priority jobs persistence
            await PriorityService.setCurrentStaffId(staff.staffId);

            if (!mounted) return;

            // Session exists - navigate to dashboard
            Navigator.pushReplacementNamed(
              context,
              '/dashboard',
              arguments: staff,
            );
          } else {
            // No session - show splash screen
            setState(() {
              _isCheckingSession = false;
            });
          }
        },
      );
    } catch (e) {
      // Error checking session - show splash screen
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  void _navigateToSignIn() {
    Navigator.pushNamed(context, '/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor, // #2255FC blue background
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              // Top section: Logo + Title
              Expanded(
                flex: 5,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      PowerCALogo(
                        width: 61.w,
                        height: 49.h,
                      ),

                      SizedBox(height: 24.h),

                      // App Name "POWER CA"
                      Text(
                        'POWER CA',
                        style: GoogleFonts.inter(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w600, // SemiBold
                          color: Colors.white,
                          letterSpacing: 0,
                          height: 1.43, // 40px line height
                        ),
                      ),

                      SizedBox(height: 2.h),

                      // Subtitle "Auditor WorkLog"
                      Text(
                        'Auditor WorkLog',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500, // Medium
                          color: Colors.white,
                          letterSpacing: 0,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Middle section: Welcome illustration
              Expanded(
                flex: 6,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Welcome illustration from Figma
                      Image.asset(
                        'assets/images/splash/welcome_illustration.png',
                        width: screenWidth * 0.7,
                        height: screenHeight * 0.25,
                        fit: BoxFit.contain,
                      ),

                      SizedBox(height: 32.h),

                      // Description text
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Text(
                          'The Auditor WorkLog application is specially designed for Auditor Offices that have adopted the PowerCA system.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom section: Buttons or Loading
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isCheckingSession)
                        // Show loading while checking session
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      else
                        // Sign In Button (White background)
                        SizedBox(
                          width: double.infinity,
                          height: 52.h,
                          child: ElevatedButton(
                            onPressed: _navigateToSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Text(
                              'Sign in',
                              style: GoogleFonts.inter(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


