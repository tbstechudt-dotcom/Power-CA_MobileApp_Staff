import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../../../core/services/priority_service.dart';
import '../../../device_security/data/models/device_info_model.dart';
import '../../../device_security/domain/repositories/device_security_repository.dart';
import '../../domain/repositories/auth_repository.dart';

/// Splash/Welcome Screen Page
/// Professional design with clean aesthetics
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  bool _isCheckingSession = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    // Check for existing session
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkExistingSession();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    try {
      final authRepository = getIt<AuthRepository>();
      final result = await authRepository.getCurrentStaff();

      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _isCheckingSession = false;
          });
        },
        (staff) async {
          if (staff != null) {
            await PriorityService.setCurrentStaffId(staff.staffId);

            if (!mounted) return;

            // Staff is logged in - go to security gate for OTP verification
            Navigator.pushReplacementNamed(
              context,
              '/security-gate',
            );
          } else {
            setState(() {
              _isCheckingSession = false;
            });
          }
        },
      );
    } catch (e) {
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E40AF), // Deep blue
              Color(0xFF2563EB), // Primary blue
              Color(0xFF3B82F6), // Light blue
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                // Top spacing
                SizedBox(height: 60.h),

                // Logo Section
                _buildLogoSection(),

                // Spacer
                const Spacer(flex: 1),

                // Feature highlights
                _buildFeatureSection(),

                // Spacer
                const Spacer(flex: 1),

                // Bottom section with button
                _buildBottomSection(),

                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo container with white background
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

        SizedBox(height: 8.h),

        // Tagline
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            'Auditor WorkLog',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Column(
        children: [
          // Feature items
          _buildFeatureItem(
            icon: Icons.access_time_rounded,
            title: 'Track Work Hours',
            subtitle: 'Log your daily activities',
          ),
          SizedBox(height: 16.h),
          _buildFeatureItem(
            icon: Icons.assignment_rounded,
            title: 'Manage Tasks',
            subtitle: 'Stay organized with checklists',
          ),
          SizedBox(height: 16.h),
          _buildFeatureItem(
            icon: Icons.sync_rounded,
            title: 'Real-time Sync',
            subtitle: 'Always up to date',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            icon,
            size: 22.sp,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Column(
        children: [
          if (_isCheckingSession)
            // Loading indicator
            Column(
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Checking session...',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            )
          else
            // Sign In Button
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed: _navigateToSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20.sp,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Version text
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
