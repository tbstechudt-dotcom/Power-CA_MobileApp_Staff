import 'package:flutter/material.dart';

/// PowerCA App Theme - "soft" style.
///
/// Geist (bundled in assets/fonts) on calm off-white surfaces, large radii,
/// hairline borders and very light shadows. Page-level building blocks live
/// in `lib/shared/widgets/soft_page.dart` and `soft_ui.dart`.
class AppTheme {
  /// Bundled font family (see pubspec.yaml).
  static const String fontFamily = 'Geist';

  // Brand colors
  static const Color primaryColor = Color(0xFF2563EB); // Blue - Primary
  static const Color primaryDark = Color(0xFF1E40AF); // Deep Blue
  static const Color primaryLight = Color(0xFF3B82F6); // Soft Blue
  static const Color primaryVeryLight = Color(0xFFEFF4FF); // Pale Blue tint

  static const Color surfaceColor = Color(0xFFFFFFFF); // Card surface
  static const Color backgroundColor = Color(0xFFF4F5F7); // Soft page background
  static const Color accentColor = Color(0xFF0D9488); // Teal - Accent

  // Semantic colors
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF2563EB);

  // Text colors
  static const Color textPrimaryColor = Color(0xFF0F172A);
  static const Color textSecondaryColor = Color(0xFF475569);
  static const Color textMutedColor = Color(0xFF8A94A6);
  static const Color textDisabledColor = Color(0xFFB4BCC8);
  static const Color textOnPrimaryColor = Color(0xFFFFFFFF);

  // Border & divider
  static const Color borderColor = Color(0xFFE6E8EC);
  static const Color dividerColor = Color(0xFFEEF0F3);

  // Text field colors
  static const Color textFieldFillColor = Color(0xFFF4F5F7);
  static const Color textFieldBorderColor = Color(0xFFE6E8EC);
  static const Color textFieldFocusedBorder = Color(0xFF2563EB);
  static const Color textFieldErrorBorder = Color(0xFFEF4444);

  // Dark palette
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF151C2C);
  static const Color darkSurfaceAlt = Color(0xFF1E2638);
  static const Color darkBorder = Color(0xFF263045);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextMuted = Color(0xFF8B95A8);

  static TextTheme _textTheme(Color primary, Color muted) {
    TextStyle s(double size, FontWeight w, Color c, {double ls = 0}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          color: c,
          letterSpacing: ls,
        );
    return TextTheme(
      displayLarge: s(34, FontWeight.w700, primary, ls: -1.0),
      displayMedium: s(28, FontWeight.w700, primary, ls: -0.8),
      displaySmall: s(24, FontWeight.w600, primary, ls: -0.6),
      headlineLarge: s(22, FontWeight.w600, primary, ls: -0.5),
      headlineMedium: s(19, FontWeight.w600, primary, ls: -0.4),
      headlineSmall: s(16, FontWeight.w600, primary, ls: -0.2),
      titleLarge: s(18, FontWeight.w600, primary, ls: -0.3),
      titleMedium: s(15, FontWeight.w600, primary, ls: -0.1),
      titleSmall: s(13, FontWeight.w600, primary),
      bodyLarge: s(16, FontWeight.w400, primary),
      bodyMedium: s(14, FontWeight.w400, primary),
      bodySmall: s(12, FontWeight.w400, muted),
      labelLarge: s(14, FontWeight.w500, primary),
      labelMedium: s(12, FontWeight.w500, primary),
      labelSmall: s(11, FontWeight.w500, muted, ls: 0.2),
    );
  }

  static OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );

  /// Smooth page transitions used by every MaterialPageRoute on all
  /// platforms (see [SoftPageTransitionsBuilder]).
  static const PageTransitionsTheme softPageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: SoftPageTransitionsBuilder(),
      TargetPlatform.iOS: SoftPageTransitionsBuilder(),
      TargetPlatform.windows: SoftPageTransitionsBuilder(),
      TargetPlatform.macOS: SoftPageTransitionsBuilder(),
      TargetPlatform.linux: SoftPageTransitionsBuilder(),
      TargetPlatform.fuchsia: SoftPageTransitionsBuilder(),
    },
  );

  /// Light Theme
  static ThemeData get lightTheme {
    final text = _textTheme(textPrimaryColor, textMutedColor);
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: softPageTransitions,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: surfaceColor,
        primaryContainer: primaryVeryLight,
        onPrimaryContainer: primaryDark,
        secondary: accentColor,
        onSecondary: surfaceColor,
        error: errorColor,
        onError: surfaceColor,
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        surfaceContainerHighest: Color(0xFFEEF0F3),
        outline: borderColor,
        outlineVariant: dividerColor,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimaryColor),
        titleTextStyle: text.titleLarge,
        toolbarHeight: 60,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderColor),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimaryColor,
          foregroundColor: surfaceColor,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: textPrimaryColor,
          foregroundColor: surfaceColor,
          minimumSize: const Size(64, 50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimaryColor,
          side: const BorderSide(color: borderColor),
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _border(textFieldBorderColor),
        enabledBorder: _border(textFieldBorderColor),
        focusedBorder: _border(textPrimaryColor, 1.4),
        errorBorder: _border(textFieldErrorBorder),
        focusedErrorBorder: _border(textFieldErrorBorder, 1.4),
        disabledBorder: _border(dividerColor),
        labelStyle: text.bodyMedium?.copyWith(color: textMutedColor),
        floatingLabelStyle:
            text.bodyMedium?.copyWith(color: textPrimaryColor),
        hintStyle: text.bodyMedium?.copyWith(color: textMutedColor),
        errorStyle: text.bodySmall?.copyWith(color: errorColor),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: textPrimaryColor,
        unselectedItemColor: textMutedColor,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: textPrimaryColor,
        disabledColor: dividerColor,
        side: const BorderSide(color: borderColor),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: surfaceColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: textSecondaryColor),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimaryColor,
        contentTextStyle: text.bodyMedium?.copyWith(color: surfaceColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: textPrimaryColor,
        foregroundColor: surfaceColor,
        elevation: 2,
        shape: StadiumBorder(),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: primaryColor),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: textPrimaryColor, size: 22),
      primaryIconTheme: const IconThemeData(color: primaryColor, size: 22),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    final text = _textTheme(darkText, darkTextMuted);
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: softPageTransitions,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF60A5FA),
        onPrimary: darkBackground,
        primaryContainer: Color(0xFF1E2A4A),
        onPrimaryContainer: Color(0xFFBFD4FE),
        secondary: accentColor,
        onSecondary: surfaceColor,
        error: Color(0xFFF87171),
        onError: darkBackground,
        surface: darkSurface,
        onSurface: darkText,
        surfaceContainerHighest: darkSurfaceAlt,
        outline: darkBorder,
        outlineVariant: darkBorder,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: darkText),
        titleTextStyle: text.titleLarge,
        toolbarHeight: 60,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkText,
          foregroundColor: darkBackground,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkText,
          foregroundColor: darkBackground,
          minimumSize: const Size(64, 50),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: const BorderSide(color: darkBorder),
          minimumSize: const Size(64, 50),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF60A5FA),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: _border(darkBorder),
        enabledBorder: _border(darkBorder),
        focusedBorder: _border(darkText, 1.4),
        errorBorder: _border(const Color(0xFFF87171)),
        focusedErrorBorder: _border(const Color(0xFFF87171), 1.4),
        labelStyle: text.bodyMedium?.copyWith(color: darkTextMuted),
        hintStyle: text.bodyMedium?.copyWith(color: darkTextMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkText,
        unselectedItemColor: darkTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkText,
        contentTextStyle: text.bodyMedium?.copyWith(color: darkBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkText,
        foregroundColor: darkBackground,
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: darkText, size: 22),
    );
  }
}

/// App Spacing Constants
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// App Radius Constants
class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 9999;
}

/// Soft page transition, built only from transforms (no page-wide opacity,
/// which forces an offscreen layer every frame and stutters):
/// - the new page slides in from the right edge with an emphasized
///   ease-out and a soft shadow on its leading edge;
/// - the page underneath drifts a quarter to the left (parallax) and is
///   dimmed by a light scrim painted on top of it.
/// Works for push, pop and the system back gesture.
class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 360);

  static final Animatable<Offset> _enterTween = Tween<Offset>(
    begin: const Offset(1.0, 0),
    end: Offset.zero,
  );

  static final Animatable<Offset> _exitTween = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.25, 0),
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.fastEaseInToSlowEaseOut,
      reverseCurve: Curves.easeInOutCubic,
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.fastEaseInToSlowEaseOut,
      reverseCurve: Curves.easeInOutCubic,
    );

    return SlideTransition(
      position: _exitTween.animate(exit),
      child: _Scrim(
        animation: exit,
        child: SlideTransition(
          position: _enterTween.animate(enter),
          child: _EdgeShadow(animation: enter, child: child),
        ),
      ),
    );
  }
}

/// Darkens the page underneath while another page covers it. A colored
/// box painted on top is far cheaper than fading the page itself.
class _Scrim extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _Scrim({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = animation.value;
                if (t <= 0) return const SizedBox.shrink();
                return ColoredBox(
                  color: Colors.black.withValues(alpha: 0.10 * t),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft shadow along the leading edge of the incoming page, so it reads
/// as a sheet sliding over the previous one. Hidden once settled.
class _EdgeShadow extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _EdgeShadow({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, page) {
        final t = animation.value;
        if (t >= 1 || t <= 0) return page!;
        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12 * (1 - t) + 0.04),
                blurRadius: 24,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: page,
        );
      },
    );
  }
}
