import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme.dart';
import 'core/config/injection.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/domain/entities/staff.dart';
import 'features/auth/presentation/pages/select_concern_location_page.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/device_security/presentation/bloc/device_security_bloc.dart';
import 'features/device_security/domain/entities/device_info.dart';
import 'features/device_security/presentation/pages/otp_verification_page.dart';
import 'features/device_security/presentation/pages/phone_verification_page.dart';
import 'features/device_security/presentation/pages/security_gate_page.dart';
import 'features/home/presentation/pages/dashboard_page.dart';
import 'features/jobs/presentation/pages/jobs_page.dart';
import 'features/leave/presentation/pages/leave_page.dart';
import 'features/pinboard/presentation/pages/pinboard_page.dart';
import 'features/work_diary/domain/entities/job.dart';
import 'features/work_diary/presentation/pages/work_diary_list_page.dart';

// Global error message for display
String? _initializationError;

void main() async {
  // Catch all errors and display them
  runZonedGuarded(() async {
    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Set up Flutter error handler to show errors on screen
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
    };

    try {
      // Set preferred orientations first
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Show status bar and navigation bar normally (not edge-to-edge)
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );

      // Initialize Supabase with error handling
      bool supabaseInitialized = false;
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
        supabaseInitialized = true;
        debugPrint('Supabase initialized successfully');
      } catch (e, stack) {
        _initializationError = 'Supabase Error: $e';
        debugPrint('Supabase initialization error: $e');
        debugPrint('Stack: $stack');
      }

      // Configure dependency injection only if Supabase is initialized
      if (supabaseInitialized) {
        try {
          await configureDependencies();
          debugPrint('Dependencies configured successfully');
        } catch (e, stack) {
          _initializationError = 'DI Error: $e';
          debugPrint('Dependency injection error: $e');
          debugPrint('Stack: $stack');
        }
      }

      runApp(const PowerCAApp());
    } catch (e, stack) {
      _initializationError = 'Init Error: $e';
      debugPrint('Main initialization error: $e');
      debugPrint('Stack: $stack');
      runApp(ErrorApp(error: e.toString(), stack: stack.toString()));
    }
  }, (error, stack) {
    debugPrint('Uncaught Error: $error');
    debugPrint('Stack: $stack');
  });
}

/// Error display app for when main app fails to initialize
class ErrorApp extends StatelessWidget {
  final String error;
  final String stack;

  const ErrorApp({super.key, required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        appBar: AppBar(
          title: const Text('App Error'),
          backgroundColor: Colors.red,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The app failed to start:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Text(
                  error,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stack Trace:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Text(
                  stack,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PowerCAApp extends StatelessWidget {
  const PowerCAApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Show error screen if there was an initialization error
    if (_initializationError != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.orange[50],
          appBar: AppBar(
            title: const Text('Initialization Warning'),
            backgroundColor: Colors.orange,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App started with errors:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  width: double.infinity,
                  child: Text(
                    _initializationError!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please check:\n'
                  '1. Internet connection\n'
                  '2. Supabase configuration\n'
                  '3. App permissions',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ScreenUtilInit(
      designSize: const Size(
          393, 852,), // Based on Figma design (Splash Screen dimensions)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'PowerCA - Auditor WorkLog',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const SecurityGatePage(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
              case '/security-gate':
                return MaterialPageRoute(builder: (_) => const SecurityGatePage());
              case '/splash':
                return MaterialPageRoute(builder: (_) => const SplashPage());
              case '/sign-in':
                return MaterialPageRoute(builder: (_) => const SignInPage());
              case '/select-concern-location':
                final staff = settings.arguments as Staff;
                return MaterialPageRoute(
                  builder: (_) => SelectConcernLocationPage(currentStaff: staff),
                );
              case '/dashboard':
                final staff = settings.arguments as Staff;
                return MaterialPageRoute(
                  builder: (_) => DashboardPage(currentStaff: staff),
                );
              case '/jobs':
                final staff = settings.arguments as Staff;
                return MaterialPageRoute(
                  builder: (_) => JobsPage(currentStaff: staff),
                );
              case '/leave':
                final staff = settings.arguments as Staff;
                return MaterialPageRoute(
                  builder: (_) => LeavePage(currentStaff: staff),
                );
              case '/pinboard':
                final staff = settings.arguments as Staff;
                return MaterialPageRoute(
                  builder: (_) => PinboardPage(currentStaff: staff),
                );
              case '/work-diary':
                final job = settings.arguments as Job;
                return MaterialPageRoute(
                  builder: (_) => WorkDiaryListPage(job: job),
                );
              case '/phone-verification':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => PhoneVerificationPage(
                    deviceInfo: args['deviceInfo'] as DeviceInfo,
                    staffId: args['staffId'] as int?,
                  ),
                );
              case '/otp-verification':
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => getIt<DeviceSecurityBloc>(),
                    child: OtpVerificationPage(
                      maskedPhone: args['maskedPhone'] as String,
                      expiresInSeconds: args['expiresInSeconds'] as int,
                      phoneNumber: args['phoneNumber'] as String?,
                      fingerprint: args['fingerprint'] as String?,
                    ),
                  ),
                );
              default:
                return MaterialPageRoute(builder: (_) => const SplashPage());
            }
          },
        );
      },
    );
  }
}

/// Placeholder home page
/// TODO: Replace with actual Splash Screen once created
class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo placeholder
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.business_center_rounded,
                size: 60,
                color: AppTheme.surfaceColor,
              ),
            ),
            const SizedBox(height: 24),

            // App name
            Text(
              'POWER CA',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Auditor WorkLog',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
            ),
            const SizedBox(height: 48),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.successColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Scaffold Ready',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Next steps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    'Next Steps:',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildNextStep(
                    context,
                    '1. Add Supabase ANON key',
                    'lib/core/config/supabase_config.dart',
                  ),
                  const SizedBox(height: 8),
                  _buildNextStep(
                    context,
                    '2. Add Inter fonts',
                    'assets/fonts/',
                  ),
                  const SizedBox(height: 8),
                  _buildNextStep(
                    context,
                    '3. Implement Splash & Login screens',
                    'From Figma designs',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStep(BuildContext context, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
          ),
        ],
      ),
    );
  }
}

/// Auto Splash Screen that redirects to Dashboard after delay
class AutoSplashScreen extends StatefulWidget {
  final Staff mockStaff;

  const AutoSplashScreen({super.key, required this.mockStaff});

  @override
  State<AutoSplashScreen> createState() => _AutoSplashScreenState();
}

class _AutoSplashScreenState extends State<AutoSplashScreen> {
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

    // Navigate to dashboard after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(currentStaff: widget.mockStaff),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/images/Logo/Power CA Logo Only-04.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            const Text(
              'POWER CA',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Auditor WorkLog',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),

            // Loading indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
