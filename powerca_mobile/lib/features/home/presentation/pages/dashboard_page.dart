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
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../shared/widgets/update_dialog.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/modern_work_calendar.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import 'work_log_entry_form_page.dart';

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

  bool _isCheckingSession = false;
  bool _isSessionDialogShowing = false;
  bool _isLoginRequestDialogShowing = false;
  static const int _initialPage = 10000;
  late PageController _pageController;

  // Summary card state
  bool _isLoadingSummary = true;
  int _loggedDaysThisMonth = 0;
  int _leaveDaysThisMonth = 0;
  Map<String, int> _dailyMinutes = {};
  Map<String, int> _dailyLogCount = {};
  Set<String> _leaveDates = {};
  late DateTime _selectedDate = DateTime.now();
  static const int _initialPage = 10000;
  late final PageController _pageController =
      PageController(initialPage: _initialPage);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _initialPage);
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
    _pageController.dispose();
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
    if (mounted) {
      setState(() => _isLoadingSummary = true);
    }

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final startOfMonthStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endOfMonthStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

      // 1. Work diary entries this month
      final monthResponse = await supabase
          .from('workdiary')
          .select('date, minutes')
          .eq('staff_id', widget.currentStaff.staffId)
          .gte('date', startOfMonthStr)
          .lte('date', endOfMonthStr);

      final Set<String> uniqueDates = {};
      final Map<String, int> dailyMinutes = {};
      final Map<String, int> dailyLogCount = {};

      for (final entry in monthResponse) {
        if (entry['date'] != null) {
          final dateStr = entry['date'] as String;
          uniqueDates.add(dateStr);
          final mins = (entry['minutes'] as num?)?.toInt() ?? 0;
          dailyMinutes[dateStr] = (dailyMinutes[dateStr] ?? 0) + mins;
          dailyLogCount[dateStr] = (dailyLogCount[dateStr] ?? 0) + 1;
        }
      }

      // 2. Approved leave requests overlapping this month
      final leaveResponse = await supabase
          .from('learequest')
          .select('fromdate, todate, approval_status')
          .eq('staff_id', widget.currentStaff.staffId)
          .eq('approval_status', 'A')
          .lte('fromdate', endOfMonthStr)
          .gte('todate', startOfMonthStr);

      int leaveDays = 0;
      final Set<String> leaveDates = {};

      for (final leave in leaveResponse) {
        final fromDate = DateTime.parse(leave['fromdate']);
        final toDate = DateTime.parse(leave['todate']);
        DateTime day =
            fromDate.isBefore(startOfMonth) ? startOfMonth : fromDate;
        final lastDay = toDate.isAfter(endOfMonth) ? endOfMonth : toDate;
        while (!day.isAfter(lastDay)) {
          if (day.weekday != DateTime.sunday) {
            leaveDays++;
            leaveDates.add(DateFormat('yyyy-MM-dd').format(day));
          }
          day = day.add(const Duration(days: 1));
        }
      }

      if (mounted) {
        setState(() {
          _loggedDaysThisMonth = uniqueDates.length;
          _leaveDaysThisMonth = leaveDays;
          _dailyMinutes = dailyMinutes;
          _dailyLogCount = dailyLogCount;
          _leaveDates = leaveDates;
          _isLoadingSummary = false;
        });

        // Send notification if user hasn't logged today (and not on leave)
        if (!hasLoggedToday && !isOnLeaveToday) {
          NotificationService().showWorkLogReminderNotification(
            staffName: widget.currentStaff.name,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) {
        setState(() => _isLoadingSummary = false);
      }
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

                                // Monthly Calendar
                                _buildMonthlyCalendar(),

                                const SizedBox(height: 16),

                                // Summary Cards (Logged Days / Leave Days + Day Status)
                                _buildSummarySection(),

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

  // ---------- Summary Section ----------

  Widget _buildSummarySection() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final monthName = DateFormat('MMMM').format(DateTime.now());

    return Column(
      children: [
        // Row 1: Logged Days & Leave Days stat tiles
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                icon: Icons.calendar_month_rounded,
                title: 'Logged Days',
                value: _isLoadingSummary ? '…' : '$_loggedDaysThisMonth',
                gradient: const [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                badge: monthName,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatTile(
                icon: Icons.event_busy_rounded,
                title: 'Leave Days',
                value: _isLoadingSummary ? '…' : '$_leaveDaysThisMonth',
                gradient: const [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
                badge: monthName,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Row 2: Swipeable Day Status (full width)
        _buildSwipeableDayStatus(isDarkMode),
      ],
    );
  }

  /// Handle tap on day status card based on current status
  void _onDayStatusTapped(DateTime date, String status, bool isDarkMode) {
    if (status == 'Not Logged') {
      // Navigate directly to work log entry form
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkLogEntryFormPage(
            selectedDate: date,
            staffId: widget.currentStaff.staffId,
          ),
        ),
      ).then((_) => _fetchDashboardStats());
    } else {
      // Active or On Leave — show bottom sheet with details
      _showDayDetails(date, isDarkMode);
    }
  }

  /// Show bottom sheet with day details and work log entries
  void _showDayDetails(DateTime date, bool isDarkMode) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayInfo = _getDayInfo(date);
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final sheetBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // Date header
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
                child: Row(
                  children: [
                    // Date circle
                    Container(
                      width: 52.w,
                      height: 52.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: dayInfo.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(date).toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 14.w),
                    // Date text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday
                                ? 'Today, ${DateFormat('d MMMM yyyy').format(date)}'
                                : DateFormat('EEEE, d MMMM yyyy').format(date),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(dayInfo.icon, size: 14.sp, color: dayInfo.gradient[1]),
                              SizedBox(width: 6.w),
                              Text(
                                dayInfo.status,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: dayInfo.gradient[1],
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Icon(Icons.access_time_rounded, size: 14.sp, color: subtitleColor),
                              SizedBox(width: 4.w),
                              Text(
                                _formatWorkingHours(dayInfo.minutes),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // "+New" button for Active days
                    if (dayInfo.status == 'Active')
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkLogEntryFormPage(
                                selectedDate: date,
                                staffId: widget.currentStaff.staffId,
                              ),
                            ),
                          ).then((_) => _fetchDashboardStats());
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16.sp, color: Colors.white),
                              SizedBox(width: 4.w),
                              Text(
                                'New',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Divider(color: dividerColor, height: 1),

              // Entries list
              Flexible(
                child: _DayEntriesList(
                  dateStr: dateStr,
                  staffId: widget.currentStaff.staffId,
                  isDarkMode: isDarkMode,
                  cardBgColor: cardBgColor,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  dividerColor: dividerColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDarkMode,
    bool isHighlighted = false,
  }) {
    final isDisabled = onTap == null;
    final bgColor = isHighlighted
        ? const Color(0xFF2563EB)
        : isDarkMode
            ? const Color(0xFF1E293B)
            : const Color(0xFFF1F5F9);
    final fgColor = isDisabled
        ? (isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
        : isHighlighted
            ? Colors.white
            : (isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF475569));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label == 'Prev') Icon(icon, size: 16.sp, color: fgColor),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
            if (label != 'Prev') Icon(icon, size: 16.sp, color: fgColor),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
    required String badge,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        height: 140.h,
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Watermark icon (clipped by parent ClipRRect)
            Positioned(
              right: -20.w,
              bottom: -20.h,
              child: Icon(
                icon,
                size: 90.sp,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            // Foreground content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + month badge
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        icon,
                        size: 18.sp,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Day Status Card ----------

  ({String status, Color accent, int minutes, int logCount}) _getDayInfo(
      DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final isLeave = _leaveDates.contains(dateStr);
    final logCount = _dailyLogCount[dateStr] ?? 0;
    final minutes = _dailyMinutes[dateStr] ?? 0;
    final hasLogged = logCount > 0;

    if (isLeave) {
      return (
        status: 'On Leave',
        accent: const Color(0xFFF59E0B),
        minutes: minutes,
        logCount: logCount,
      );
    } else if (hasLogged) {
      return (
        status: 'Active',
        accent: const Color(0xFF10B981),
        minutes: minutes,
        logCount: logCount,
      );
    } else {
      return (
        status: 'Not Logged',
        accent: const Color(0xFF64748B),
        minutes: 0,
        logCount: 0,
      );
    }
  }

  DateTime _dateFromPageIndex(int index) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return todayOnly.subtract(Duration(days: _initialPage - index));
  }

  Widget _buildSwipeableDayStatus(bool isDarkMode) {
    final today = DateTime.now();
    final canGoNext = _selectedDate
        .isBefore(DateTime(today.year, today.month, today.day));

    return SizedBox(
      height: 190.h,
      child: Stack(
        children: [
          // Full-width PageView card
          PageView.builder(
            controller: _pageController,
            itemCount: _initialPage + 1,
            onPageChanged: (index) {
              setState(() {
                _selectedDate = _dateFromPageIndex(index);
              });
            },
            itemBuilder: (context, index) {
              final date = _dateFromPageIndex(index);
              final dayInfo = _getDayInfo(date);
              final now = DateTime.now();
              final isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final dateLabel =
                  isToday ? 'Today' : DateFormat('EEE, d MMM').format(date);

              return GestureDetector(
                onTap: () =>
                    _onDayStatusTapped(date, dayInfo.status),
                child: _buildDayStatusCard(
                  dateLabel: dateLabel,
                  status: dayInfo.status,
                  accent: dayInfo.accent,
                  minutes: dayInfo.minutes,
                  logCount: dayInfo.logCount,
                  isDarkMode: isDarkMode,
                ),
              );
            },
          ),
          // Overlay arrows
          Positioned(
            left: 8.w,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildOverlayArrow(
                icon: Icons.chevron_left_rounded,
                isDarkMode: isDarkMode,
                enabled: true,
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8.w,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildOverlayArrow(
                icon: Icons.chevron_right_rounded,
                isDarkMode: isDarkMode,
                enabled: canGoNext,
                onTap: canGoNext
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                        )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayArrow({
    required IconData icon,
    required bool isDarkMode,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final iconColor = enabled
        ? (isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A))
        : (isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1));

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20.sp, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildDayStatusCard({
    required String dateLabel,
    required String status,
    required Color accent,
    required int minutes,
    required int logCount,
    required bool isDarkMode,
  }) {
    final cardBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      height: 190.h,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  size: 22.sp,
                  color: accent,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Work log summary',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusPill(status: status, accent: accent),
            ],
          ),
          // Center the divider vertically so it runs through the middle of
          // the overlay arrow buttons (arrows sit on the divider line).
          const Spacer(),
          Container(height: 1, color: dividerColor),
          const Spacer(),
          // Stats row: HOURS | ENTRIES
          Row(
            children: [
              Expanded(
                child: _buildStatBlock(
                  label: 'HOURS',
                  value: _formatMinutes(minutes),
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                ),
              ),
              Container(width: 1, height: 36.h, color: dividerColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 16.w),
                  child: _buildStatBlock(
                    label: 'ENTRIES',
                    value:
                        '$logCount ${logCount == 1 ? 'entry' : 'entries'}',
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({required String status, required Color accent}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            status,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock({
    required String label,
    required String value,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: subtitleColor,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  void _onDayStatusTapped(DateTime date, String status) {
    if (status == 'Not Logged') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkLogEntryFormPage(
            selectedDate: date,
            staffId: widget.currentStaff.staffId,
          ),
        ),
      ).then((_) => _fetchDashboardStats());
    }
  }
}

class _DayEntriesListState extends State<_DayEntriesList> {
  List<Map<String, dynamic>> _entries = [];
  final Map<int, String> _jobNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('workdiary')
          .select()
          .eq('staff_id', widget.staffId)
          .eq('date', widget.dateStr)
          .order('timefrom', ascending: true);

      final entries = List<Map<String, dynamic>>.from(response);

      // Fetch job names
      final jobIds = entries
          .map((e) => e['job_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (jobIds.isNotEmpty) {
        final jobResponse = await supabase
            .from('jobshead')
            .select('job_id, work_desc')
            .inFilter('job_id', jobIds);

        for (var job in jobResponse) {
          _jobNames[job['job_id']] = job['work_desc'] ?? 'Unknown';
        }
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching day entries: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(dynamic timeValue) {
    if (timeValue == null) return '--:--';
    String timeStr = timeValue.toString();
    if (timeStr.contains('T')) timeStr = timeStr.split('T')[1];
    timeStr = timeStr.split('+')[0].split('Z')[0].split('.')[0];
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      int hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour = hour - 12;
      }
      return '$hour:$minute $period';
    }
    return timeStr;
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m}m';
    return '0m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.all(32.w),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 40.sp,
              color: widget.subtitleColor,
            ),
            SizedBox(height: 12.h),
            Text(
              'No work entries for this day',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: widget.subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final jobId = entry['job_id'];
        final jobName = jobId != null ? _jobNames[jobId] : null;
        final minutes = (entry['minutes'] as num?)?.toInt() ?? 0;
        final timeFrom = entry['timefrom'];
        final timeTo = entry['timeto'];
        final notes = entry['tasknotes'] ?? '';
        final hasTimeRange = timeFrom != null && timeTo != null;

        const accentColor = Color(0xFF3B82F6);
        final timeBgColor = widget.isDarkMode
            ? const Color(0xFF1E3A5F)
            : const Color(0xFFEFF6FF);

        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: widget.cardBgColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: widget.dividerColor, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry number
              Container(
                width: 30.w,
                height: 30.h,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              // Entry details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job name
                    Text(
                      jobName ?? 'Job #$jobId',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: widget.titleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    // Time range
                    Row(
                      children: [
                        if (hasTimeRange) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: timeBgColor,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 12.sp,
                                  color: accentColor,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${_formatTime(timeFrom)} - ${_formatTime(timeTo)}',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                        ],
                      ],
                    ),
                    // Notes
                    if (notes.toString().isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(
                        notes.toString(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: widget.subtitleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Duration badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _formatMinutes(minutes),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
