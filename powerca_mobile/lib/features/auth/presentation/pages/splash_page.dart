import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/injection.dart';
import '../../../../core/services/priority_service.dart';
import '../../../../shared/widgets/auth_sheet.dart';
import '../../../../shared/widgets/soft_page.dart';
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
    final p = SoftPalette.of(context);
    return AuthSheet(
      title: 'Auditor WorkLog',
      subtitle: 'Track work hours, manage tasks and stay in sync with your office.',
      icon: Icons.work_outline_rounded,
      note: 'Version 2.0.0',
      children: [
        AnimatedBuilder(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthFeatureRow(
                icon: Icons.access_time_rounded,
                title: 'Track Work Hours',
                subtitle: 'Log your daily activities',
              ),
              const AuthFeatureRow(
                icon: Icons.assignment_rounded,
                title: 'Manage Tasks',
                subtitle: 'Stay organized with checklists',
              ),
              const AuthFeatureRow(
                icon: Icons.sync_rounded,
                title: 'Real-time Sync',
                subtitle: 'Always up to date',
              ),
              const SizedBox(height: 22),
              _buildBottomSection(p),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection(SoftPalette p) {
    if (_isCheckingSession) {
      // Loading indicator
      return Column(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(p.ink),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text('Checking session...', style: SoftText.body(p, color: p.muted)),
        ],
      );
    }

    // Sign In Button
    return SoftPillButton(
      label: 'Get Started',
      trailingIcon: Icons.arrow_forward_rounded,
      onPressed: _navigateToSignIn,
    );
  }
}
