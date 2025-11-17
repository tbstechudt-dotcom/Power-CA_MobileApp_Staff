import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme.dart';
import 'core/config/injection.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/domain/entities/staff.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/auth/presentation/pages/sign_up_page.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/home/presentation/pages/dashboard_page.dart';
import 'features/jobs/presentation/pages/jobs_page.dart';
import 'features/leave/presentation/pages/leave_page.dart';
import 'features/pinboard/presentation/pages/pinboard_page.dart';
import 'features/work_diary/domain/entities/job.dart';
import 'features/work_diary/presentation/pages/work_diary_list_page.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Configure dependency injection
  await configureDependencies();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Hide status bar on all pages
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  runApp(const PowerCAApp());
}

class PowerCAApp extends StatelessWidget {
  const PowerCAApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create a mock staff for development/testing
    final mockStaff = Staff(
      staffId: 2,
      name: 'MUTHAMMAL M',
      username: 'MM',
      orgId: 1,
      locId: 1,
      conId: 1,
      email: 'logaram2009@gmail.com',
      phoneNumber: '9842865699',
      dateOfBirth: DateTime(1971, 4, 15),
      staffType: 1,
      isActive: true,
    );

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
          home: DashboardPage(currentStaff: mockStaff),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
              case '/splash':
                return MaterialPageRoute(builder: (_) => const SplashPage());
              case '/sign-in':
                return MaterialPageRoute(builder: (_) => const SignInPage());
              case '/sign-up':
                return MaterialPageRoute(builder: (_) => const SignUpPage());
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
      backgroundColor: AppTheme.backgroundColor,
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
                    '2. Add Poppins fonts',
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
