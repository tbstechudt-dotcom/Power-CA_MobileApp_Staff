import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../shared/widgets/update_dialog.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/modern_work_calendar.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';

/// Dashboard page - Dynamic version with real data
class DashboardPage extends StatefulWidget {
  final Staff currentStaff;

  const DashboardPage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  final _sessionService = SessionService();

  double _hoursLoggedToday = 0.0;
  double _hoursLoggedThisWeek = 0.0;
  double _totalMonthHours = 0.0;
  int _daysActive = 0;
  bool _isLoading = true;
  bool _isCheckingSession = false;
  bool _isSessionDialogShowing = false;
  bool _isLoginRequestDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchDashboardStats();
    _checkForAppUpdate();
    // Check session validity on first load
    _validateSession();
    // Start real-time session listener for instant alerts
    _startSessionListener();
    // Start listening for login requests from other devices
    _startLoginRequestListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionService.stopSessionListener();
    _sessionService.stopLoginRequestListener();
    super.dispose();
  }

  /// Start listening for real-time session changes
  /// When another device logs in, we get an instant alert
  void _startSessionListener() {
    _sessionService.startSessionListener(
      staffId: widget.currentStaff.staffId,
      onSessionInvalidated: (deviceName, message) {
        debugPrint('Dashboard: Session invalidated by $deviceName');
        if (mounted && !_isSessionDialogShowing) {
          _showSessionExpiredDialog(message);
        }
      },
    );
  }

  /// Start listening for login requests from other devices
  /// Shows a permission dialog when another device wants to login
  void _startLoginRequestListener() {
    _sessionService.startLoginRequestListener(
      staffId: widget.currentStaff.staffId,
      onLoginRequest: (requestId, deviceName) {
        debugPrint('Dashboard: Login request from $deviceName (ID: $requestId)');
        if (mounted && !_isLoginRequestDialogShowing) {
          _showLoginRequestDialog(requestId, deviceName);
        }
      },
    );
  }

  /// Show dialog when another device requests permission to login
  void _showLoginRequestDialog(int requestId, String deviceName) {
    if (_isLoginRequestDialogShowing) return;
    _isLoginRequestDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Icon(
                  Icons.phone_android_rounded,
                  size: 20.sp,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Login Request',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$deviceName is trying to sign in to your account.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'If you allow, you will be logged out from this device.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
        actionsPadding: EdgeInsets.all(16.w),
        actions: [
          Row(
            children: [
              // Deny Button
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    _isLoginRequestDialogShowing = false;
                    // Deny the request
                    await _sessionService.denyLoginRequest(requestId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Login request denied'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text(
                    'Deny',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Allow Button
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    _isLoginRequestDialogShowing = false;
                    // Approve the request
                    await _sessionService.approveLoginRequest(requestId);
                    // Now logout this device
                    if (mounted) {
                      _showSessionExpiredDialog(
                        'You approved login on $deviceName. You have been logged out.',
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Allow',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Check session when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _validateSession();
    }
  }

  /// Validate if current session is still active
  /// If another device logged in, this session becomes invalid
  Future<void> _validateSession() async {
    if (_isCheckingSession) return;
    _isCheckingSession = true;

    try {
      final authRepository = getIt<AuthRepository>();
      final errorMessage = await authRepository.validateSession();

      if (errorMessage != null && mounted) {
        // Session was invalidated by another device
        _showSessionExpiredDialog(errorMessage);
      }
    } catch (e) {
      debugPrint('Error validating session: $e');
    } finally {
      _isCheckingSession = false;
    }
  }

  /// Show dialog when session is expired/invalidated
  void _showSessionExpiredDialog(String message) {
    // Prevent multiple dialogs
    if (_isSessionDialogShowing) return;
    _isSessionDialogShowing = true;

    // Stop the real-time listeners since we're logging out
    _sessionService.stopSessionListener();
    _sessionService.stopLoginRequestListener();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Icon(
                  Icons.devices_other_rounded,
                  size: 20.sp,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Signed In Elsewhere',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          ),
        ),
        actionsPadding: EdgeInsets.all(16.w),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                _isSessionDialogShowing = false;
                // Clear local session and navigate to splash
                try {
                  final authRepository = getIt<AuthRepository>();
                  await authRepository.clearStaffSession();
                } catch (e) {
                  debugPrint('Error clearing session: $e');
                }
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/splash',
                    (route) => false,
                  );
                }
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check for app updates on dashboard load
  Future<void> _checkForAppUpdate() async {
    debugPrint('Dashboard: Starting update check...');
    // Delay slightly to ensure context is ready
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) {
      debugPrint('Dashboard: Widget not mounted, skipping update check');
      return;
    }

    final updateService = AppUpdateService();
    final updateInfo = await updateService.checkForUpdate();

    debugPrint('Dashboard: Update info received: $updateInfo');

    if (updateInfo != null && mounted) {
      debugPrint('Dashboard: Showing update dialog...');
      await UpdateDialog.show(context, updateInfo);
    } else {
      debugPrint('Dashboard: No update to show');
    }
  }

  /// Update status bar style based on theme
  void _updateStatusBarStyle(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      // Calculate start of this week (Monday)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekStr = DateFormat('yyyy-MM-dd').format(
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
      );

      // Calculate start of this month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfMonthStr = DateFormat('yyyy-MM-dd').format(startOfMonth);

      // Fetch hours logged today
      final todayResponse = await supabase
          .from('workdiary')
          .select('minutes')
          .eq('staff_id', widget.currentStaff.staffId)
          .eq('date', todayStr);

      double todayHours = 0.0;
      for (final entry in todayResponse) {
        final minutes = entry['minutes'];
        if (minutes != null) {
          final minutesValue = minutes is int ? minutes.toDouble() : minutes as double;
          todayHours += minutesValue / 60.0;
        }
      }

      // Fetch hours logged this week
      final weekResponse = await supabase
          .from('workdiary')
          .select('minutes')
          .eq('staff_id', widget.currentStaff.staffId)
          .gte('date', startOfWeekStr);

      double weekHours = 0.0;
      for (final entry in weekResponse) {
        final minutes = entry['minutes'];
        if (minutes != null) {
          final minutesValue = minutes is int ? minutes.toDouble() : minutes as double;
          weekHours += minutesValue / 60.0;
        }
      }

      // Fetch all entries this month (with date and minutes for calculations)
      final monthResponse = await supabase
          .from('workdiary')
          .select('wd_id, date, minutes')
          .eq('staff_id', widget.currentStaff.staffId)
          .gte('date', startOfMonthStr);

      // Calculate days active and total hours for the month
      final Set<String> uniqueDates = {};
      double totalMonthHours = 0.0;

      for (final entry in monthResponse) {
        // Track unique dates (days active)
        if (entry['date'] != null) {
          uniqueDates.add(entry['date'] as String);
        }

        // Calculate total hours for the month
        final minutes = entry['minutes'];
        if (minutes != null) {
          final minutesValue = minutes is int ? minutes.toDouble() : minutes as double;
          totalMonthHours += minutesValue / 60.0;
        }
      }

      final daysActive = uniqueDates.length;

      if (mounted) {
        setState(() {
          _hoursLoggedToday = todayHours;
          _hoursLoggedThisWeek = weekHours;
          _totalMonthHours = totalMonthHours;
          _daysActive = daysActive;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatHours(double hours) {
    if (hours == 0) return '0h';

    final wholeHours = hours.floor();
    final minutes = ((hours - wholeHours) * 60).round();

    if (minutes == 0) {
      return '${wholeHours}h';
    } else {
      return '${wholeHours}h ${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    final contentBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    // Update status bar style based on theme
    _updateStatusBarStyle(isDarkMode);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Minimize the app instead of logging out
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: scaffoldBgColor,
        drawer: AppDrawer(currentStaff: widget.currentStaff),
        body: SafeArea(
          top: false,
          child: Builder(
            builder: (scaffoldContext) => Column(
              children: [
                // Modern Top App Bar
                AppHeader(
                  currentStaff: widget.currentStaff,
                  onMenuTap: () {
                    Scaffold.of(scaffoldContext).openDrawer();
                  },
                ),

                // Content - Show static UI
                Expanded(
                  child: Container(
                    color: contentBgColor,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Main Content Area
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Staff Profile Card
                                _buildStaffProfileCard(),

                                const SizedBox(height: 16),

                                // Monthly Calendar (Moved to second section)
                                _buildMonthlyCalendar(),

                                const SizedBox(height: 16),

                                // Statistics Grid (4 cards in 2x2)
                                _buildStatisticsGrid(),

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: ModernBottomNavigation(
          currentIndex: 0,
          currentStaff: widget.currentStaff,
        ),
      ),
    );
  }

  String _getStaffRole(int? staffType) {
    switch (staffType) {
      case 1:
        return 'Administrator';
      case 2:
        return 'Manager';
      case 3:
        return 'Senior Staff';
      case 4:
        return 'Staff Member';
      case 5:
        return 'Junior Staff';
      default:
        return 'Staff Member';
    }
  }

  Widget _buildStaffProfileCard() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : AppTheme.textPrimaryColor;
    final textMutedColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;
    final badgeBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final staffRole = _getStaffRole(widget.currentStaff.staffType);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52.w,
            height: 52.h,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Center(
              child: Text(
                widget.currentStaff.name.isNotEmpty
                    ? widget.currentStaff.name[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 14.w),
          // Staff Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.currentStaff.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    staffRole,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: textMutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Staff ID Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: [
                Text(
                  'ID',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: textMutedColor,
                  ),
                ),
                Text(
                  '#${widget.currentStaff.staffId}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    // Use the new ModernWorkCalendar widget with flutter_calendar_carousel
    return ModernWorkCalendar(
      staffId: widget.currentStaff.staffId,
      onDataReloaded: _fetchDashboardStats,
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 1.4,
      children: [
        _buildStatTile(
          icon: Icons.wb_sunny_rounded,
          title: 'Today Hours',
          value: _isLoading ? '...' : _formatHours(_hoursLoggedToday),
          gradient: [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
          trend: 'Today',
        ),
        _buildStatTile(
          icon: Icons.date_range_rounded,
          title: 'Hours Logged',
          value: _isLoading ? '...' : _formatHours(_hoursLoggedThisWeek),
          gradient: [const Color(0xFF60A5FA), const Color(0xFF3B82F6)],
          trend: 'Week',
        ),
        _buildStatTile(
          icon: Icons.calendar_month_rounded,
          title: 'Total Hours',
          value: _isLoading ? '...' : _formatHours(_totalMonthHours),
          gradient: [const Color(0xFF34D399), const Color(0xFF10B981)],
          trend: 'Month',
        ),
        _buildStatTile(
          icon: Icons.check_circle_rounded,
          title: 'Days Active',
          value: _isLoading ? '...' : '$_daysActive',
          gradient: [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)],
          trend: 'Month',
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
    required String trend,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern icon
          Positioned(
            right: -20.w,
            bottom: -20.h,
            child: Icon(
              icon,
              size: 80.sp,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        icon,
                        size: 24.sp,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        trend,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}


