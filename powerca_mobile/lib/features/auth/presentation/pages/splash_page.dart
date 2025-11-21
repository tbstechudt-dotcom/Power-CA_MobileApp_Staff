import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
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
                      const PowerCALogo(
                        width: 61,
                        height: 49,
                      ),

                      const SizedBox(height: 24),

                      // App Name "POWER CA"
                      Text(
                        'POWER CA',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w600, // SemiBold
                          color: Colors.white,
                          letterSpacing: 0,
                          height: 1.43, // 40px line height
                        ),
                      ),

                      const SizedBox(height: 2),

                      // Subtitle "Auditor WorkLog"
                      Text(
                        'Auditor WorkLog',
                        style: GoogleFonts.inter(
                          fontSize: 12,
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
                        height: screenHeight * 0.3,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 32),

                      // Description text
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'The Auditor WorkLog application is specially designed for Auditor Offices that have adopted the PowerCA system.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
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

              // Bottom section: Buttons
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sign In Button (White background)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _navigateToSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Sign in',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Bottom navigation indicator
              Container(
                height: 30,
                alignment: Alignment.center,
                child: Container(
                  width: 108,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor, // #263238
                    borderRadius: BorderRadius.circular(12),
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
