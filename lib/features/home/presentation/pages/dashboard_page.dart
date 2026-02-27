import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../shared/widgets/update_dialog.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../widgets/modern_work_calendar.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/rating_review_dialog.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'work_log_entry_form_page.dart';
import 'work_log_detail_page.dart';
import 'work_log_list_page.dart';
import 'monthly_work_log_summary_page.dart';
import '../../../leave/presentation/pages/leave_history_page.dart';

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
  RealtimeChannel? _leaveStatusChannel;

  int _loggedDaysThisMonth = 0;
  int _leaveDaysThisMonth = 0;
  bool _isLoading = true;
  double _currentMonthWorkingDays = 0;
  double _currentMonthEarnedLeaveDays = 0;
  double _currentMonthLopDays = 0;
  double _currentMonthHalfDayLeaveDays = 0;

  // Per-day data for swipeable status card
  late DateTime _selectedDate = DateTime.now();
  Map<String, int> _dailyMinutes = {};
  Map<String, int> _dailyLogCount = {};
  bool _isCheckingSession = false;
  bool _isSessionDialogShowing = false;
  bool _isLoginRequestDialogShowing = false;
  static const int _initialPage = 10000;
  late PageController _pageController;

  // Rating & back press tracking
  DateTime? _lastBackPressTime;
  bool _hasReviewed = false;
  bool _isRatingDialogShowing = false;

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
    // Start listening for leave status changes (approved/rejected)
    _startLeaveStatusListener();
    // Load whether user has already submitted a review
    _loadReviewStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _sessionService.stopSessionListener();
    _sessionService.stopLoginRequestListener();
    _stopLeaveStatusListener();
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

  /// Start listening for leave status changes in real-time
  /// When a leave request is approved or rejected, show a notification
  void _startLeaveStatusListener() {
    final staffId = widget.currentStaff.staffId;

    _leaveStatusChannel = supabase
        .channel('leave_status_$staffId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'learequest',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'staff_id',
            value: staffId,
          ),
          callback: (payload) {
            debugPrint('LeaveStatusListener: Received update: ${payload.newRecord}');
            _handleLeaveStatusUpdate(payload.newRecord);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('LeaveStatusListener: subscription status: $status');
          if (error != null) {
            debugPrint('LeaveStatusListener: error: $error');
          }
        });
  }

  /// Stop listening for leave status changes
  void _stopLeaveStatusListener() {
    if (_leaveStatusChannel != null) {
      supabase.removeChannel(_leaveStatusChannel!);
      _leaveStatusChannel = null;
    }
  }

  /// Load whether this staff has already submitted a review
  Future<void> _loadReviewStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasReviewed = prefs.getBool(
        '${StorageConstants.keyHasReviewed}${widget.currentStaff.staffId}',
      ) ?? false;
      if (mounted) {
        setState(() {
          _hasReviewed = hasReviewed;
        });
      }
    } catch (e) {
      debugPrint('Error loading review status: $e');
    }
  }

  /// Handle back button press with double-tap detection and rating dialog
  void _handleBackPress() {
    final now = DateTime.now();

    // Double-tap detection: if pressed within 500ms, exit immediately
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < const Duration(milliseconds: 500)) {
      SystemNavigator.pop();
      return;
    }

    // Record this press time
    _lastBackPressTime = now;

    // If already reviewed or dialog is showing, exit normally
    if (_hasReviewed || _isRatingDialogShowing) {
      SystemNavigator.pop();
      return;
    }

    // Show rating dialog
    _showRatingDialog();
  }

  /// Show the rating dialog bottom sheet
  Future<void> _showRatingDialog() async {
    if (_isRatingDialogShowing) return;

    setState(() {
      _isRatingDialogShowing = true;
    });

    final result = await RatingReviewBottomSheet.show(
      context,
      staffId: widget.currentStaff.staffId,
    );

    if (mounted) {
      setState(() {
        _isRatingDialogShowing = false;
      });
    }

    if (result == true) {
      // Review submitted - update local state
      if (mounted) {
        setState(() {
          _hasReviewed = true;
        });
      }
    }

    // Exit the app after dialog closes (whether submitted or skipped)
    SystemNavigator.pop();
  }

  /// Handle a leave status update from Supabase Realtime
  Future<void> _handleLeaveStatusUpdate(Map<String, dynamic> newRecord) async {
    final approvalStatus = newRecord['approval_status'] as String?;

    // Only care about Approved or Rejected
    if (approvalStatus != 'A' && approvalStatus != 'R') return;

    final leaveId = newRecord['learequest_id'];
    if (leaveId == null) return;
    final leaveIdInt = leaveId is int ? leaveId : int.tryParse(leaveId.toString()) ?? 0;
    if (leaveIdInt == 0) return;

    // Check notification preferences
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    if (!notificationProvider.leaveNotificationsEnabled) return;

    // Check if we already notified for this status
    final statusName = approvalStatus == 'A' ? 'Approved' : 'Rejected';
    final lastKnown = notificationProvider.lastKnownLeaveStatuses[leaveIdInt];
    if (lastKnown == statusName) return; // Already notified

    // Map leave type code to display name
    const leaveTypeNames = {
      'SL': 'Sick Leave',
      'CL': 'Casual Leave',
      'EL': 'Earned Leave',
      'EM': 'Emergency Leave',
    };
    final leaveType = leaveTypeNames[newRecord['leavetype']] ?? 'Leave';

    // Format date range
    String dateRange = '';
    try {
      final fromDate = DateTime.parse(newRecord['fromdate']);
      final toDate = DateTime.parse(newRecord['todate']);
      dateRange = fromDate.year == toDate.year &&
              fromDate.month == toDate.month &&
              fromDate.day == toDate.day
          ? DateFormat('dd MMM').format(fromDate)
          : '${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM').format(toDate)}';
    } catch (_) {
      dateRange = '';
    }

    // Show notification in the system notification bar
    await NotificationService().showLeaveStatusNotification(
      leaveId: leaveIdInt,
      status: statusName,
      leaveType: leaveType,
      dateRange: dateRange,
    );

    // Update stored status so we don't notify again
    final updatedStatuses = Map<int, String>.from(notificationProvider.lastKnownLeaveStatuses);
    updatedStatuses[leaveIdInt] = statusName;
    await notificationProvider.updateLeaveStatuses(updatedStatuses);

    debugPrint('LeaveStatusListener: Notified - $leaveType $dateRange $statusName');
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

      // Calculate start and end of this month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfMonthStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final endOfMonthStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

      // 1. Fetch work diary entries this month (for logged days count + today's hours)
      final monthResponse = await supabase
          .from('workdiary')
          .select('date, minutes')
          .eq('staff_id', widget.currentStaff.staffId)
          .gte('date', startOfMonthStr)
          .lte('date', endOfMonthStr);

      final Set<String> uniqueDates = {};
      bool hasLoggedToday = false;
      final Map<String, int> dailyMinutes = {};
      final Map<String, int> dailyLogCount = {};

      for (final entry in monthResponse) {
        if (entry['date'] != null) {
          final dateStr = entry['date'] as String;
          uniqueDates.add(dateStr);
          final mins = (entry['minutes'] as num?)?.toInt() ?? 0;
          dailyMinutes[dateStr] = (dailyMinutes[dateStr] ?? 0) + mins;
          dailyLogCount[dateStr] = (dailyLogCount[dateStr] ?? 0) + 1;
          if (dateStr == todayStr) {
            hasLoggedToday = true;
          }
        }
      }

      // 2. Fetch approved leave requests that overlap this month
      final leaveResponse = await supabase
          .from('learequest')
          .select('fromdate, todate, approval_status, leaveremarks')
          .eq('staff_id', widget.currentStaff.staffId)
          .eq('approval_status', 'A')
          .lte('fromdate', endOfMonthStr)
          .gte('todate', startOfMonthStr);

      int leaveDays = 0;
      double approvedLeaveDaysThisMonth = 0;
      double halfDayLeaveDaysThisMonth = 0;
      bool isOnLeaveToday = false;
      final Set<String> leaveDates = {};
      final totalWorkingDaysThisMonth = _countWorkingDays(startOfMonth, endOfMonth).toDouble();

      for (final leave in leaveResponse) {
        final fromDate = DateTime.parse(leave['fromdate']);
        final toDate = DateTime.parse(leave['todate']);
        final remarks = (leave['leaveremarks'] as String?) ?? '';

        // Count leave days that fall within this month (excluding Sundays)
        final clippedFrom = fromDate.isBefore(startOfMonth) ? startOfMonth : fromDate;
        final lastDay = toDate.isAfter(endOfMonth) ? endOfMonth : toDate;
        DateTime day = clippedFrom;

        approvedLeaveDaysThisMonth += _calculateLeaveDaysInRange(
          originalFrom: fromDate,
          originalTo: toDate,
          clippedFrom: clippedFrom,
          clippedTo: lastDay,
          remarks: remarks,
        );
        halfDayLeaveDaysThisMonth += _calculateHalfDayDaysInRange(
          originalFrom: fromDate,
          originalTo: toDate,
          clippedFrom: clippedFrom,
          clippedTo: lastDay,
          remarks: remarks,
        );

        while (!day.isAfter(lastDay)) {
          if (day.weekday != DateTime.sunday) {
            leaveDays++;
            leaveDates.add(DateFormat('yyyy-MM-dd').format(day));
          }
          // Check if today falls in this leave range
          if (DateFormat('yyyy-MM-dd').format(day) == todayStr) {
            isOnLeaveToday = true;
          }
          day = day.add(const Duration(days: 1));
        }
      }

      // Per-month EL logic used in Leave page: 1 earned leave per month
      final fullDayLeaveDaysThisMonth = (approvedLeaveDaysThisMonth - halfDayLeaveDaysThisMonth).clamp(
        0.0,
        approvedLeaveDaysThisMonth,
      );
      final earnedLeaveDaysThisMonth = fullDayLeaveDaysThisMonth.clamp(0.0, 1.0);
      final lopDaysThisMonth = (fullDayLeaveDaysThisMonth - earnedLeaveDaysThisMonth).clamp(
        0.0,
        double.infinity,
      );
      final workingDaysThisMonth = (totalWorkingDaysThisMonth - approvedLeaveDaysThisMonth).clamp(
        0.0,
        totalWorkingDaysThisMonth,
      );

      if (mounted) {
        setState(() {
          _loggedDaysThisMonth = uniqueDates.length;
          _leaveDaysThisMonth = leaveDays;
          _currentMonthWorkingDays = workingDaysThisMonth;
          _currentMonthEarnedLeaveDays = earnedLeaveDaysThisMonth;
          _currentMonthLopDays = lopDaysThisMonth;
          _currentMonthHalfDayLeaveDays = halfDayLeaveDaysThisMonth;
          _dailyMinutes = dailyMinutes;
          _dailyLogCount = dailyLogCount;
          _isLoading = false;
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
        setState(() {
          _isLoading = false;
        });
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
        _handleBackPress();
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final monthName = DateFormat('MMMM').format(DateTime.now());

    return Column(
      children: [
        // Row 1: Logged Days & Leave Days
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                icon: Icons.calendar_month_rounded,
                title: 'Logged Days',
                value: _isLoading ? '...' : '$_loggedDaysThisMonth',
                gradient: [const Color(0xFF60A5FA), const Color(0xFF3B82F6)],
                badge: monthName,
                onTap: _showLoggedDaysLineGraph,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildStatTile(
                icon: Icons.event_busy_rounded,
                title: 'Leave Days',
                value: _isLoading ? '...' : '$_leaveDaysThisMonth',
                gradient: [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)],
                badge: monthName,
                onTap: _showLeaveDaysPieChart,
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

  /// Get status info for a given date from stored data
  /// Only shows log details (Active / Not Logged) — leave status is not shown here
  ({String status, IconData icon, List<Color> gradient, int minutes, int logCount}) _getDayInfo(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final logCount = _dailyLogCount[dateStr] ?? 0;
    final minutes = _dailyMinutes[dateStr] ?? 0;
    final hasLogged = logCount > 0;

    if (hasLogged) {
      return (
        status: 'Active',
        icon: Icons.check_circle_rounded,
        gradient: [const Color(0xFF34D399), const Color(0xFF10B981)],
        minutes: minutes,
        logCount: logCount,
      );
    } else {
      return (
        status: 'Not Logged',
        icon: Icons.schedule_rounded,
        gradient: [const Color(0xFF94A3B8), const Color(0xFF64748B)],
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

  void _goToToday() {
    _pageController.animateToPage(
      _initialPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _isSelectedDateToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Widget _buildSwipeableDayStatus(bool isDarkMode) {
    final today = DateTime.now();
    final canGoNext = _selectedDate.isBefore(DateTime(today.year, today.month, today.day));

    return Column(
      children: [
        // Full-width card with floating arrow buttons
        Stack(
          children: [
            // Full-width PageView
            SizedBox(
              height: 190.h,
              width: double.infinity,
              child: PageView.builder(
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
                  final dateLabel = isToday
                      ? 'Today'
                      : DateFormat('EEE, d MMM').format(date);

                  return GestureDetector(
                    onTap: () => _onDayStatusTapped(date, dayInfo.status, isDarkMode),
                    child: _buildDayStatusCard(
                      key: ValueKey(DateFormat('yyyy-MM-dd').format(date)),
                      dateLabel: dateLabel,
                      status: dayInfo.status,
                      icon: dayInfo.icon,
                      gradient: dayInfo.gradient,
                      minutes: dayInfo.minutes,
                      logCount: dayInfo.logCount,
                      isDarkMode: isDarkMode,
                    ),
                  );
                },
              ),
            ),

            // Floating left arrow
            Positioned(
              left: 8.w,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 24.sp,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),

            // Floating right arrow
            Positioned(
              right: 8.w,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: canGoNext
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: canGoNext
                          ? (isDarkMode
                              ? Colors.black.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.7))
                          : (isDarkMode
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.3)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 24.sp,
                      color: canGoNext
                          ? (isDarkMode ? Colors.white70 : Colors.grey[700])
                          : (isDarkMode ? Colors.white24 : Colors.grey[300]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 10.h),

        // Today button centered below
        Center(
          child: _buildNavButton(
            icon: Icons.today_rounded,
            label: 'Today',
            onTap: _isSelectedDateToday ? null : _goToToday,
            isDarkMode: isDarkMode,
            isHighlighted: true,
          ),
        ),
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
                    // "New" action for Active days
                    if (dayInfo.status == 'Active')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
              if (dayInfo.status == 'Active')
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                  child: Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        // Fetch entries for this date before navigating
                        final supabase = Supabase.instance.client;
                        final response = await supabase
                            .from('workdiary')
                            .select()
                            .eq('staff_id', widget.currentStaff.staffId)
                            .eq('date', dateStr)
                            .order('timefrom', ascending: true);
                        final entries = List<Map<String, dynamic>>.from(response);
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkLogListPage(
                              selectedDate: date,
                              entries: entries,
                              staffId: widget.currentStaff.staffId,
                            ),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        textStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View all',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '->',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140.h,
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
                          badge,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
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
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22.sp,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ],
                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the list of financial year months (April to March).
  /// Returns list of DateTime representing the 1st of each month.
  List<DateTime> _getFinancialYearMonths() {
    final now = DateTime.now();
    final int fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    // April of fyStartYear through March of fyStartYear+1
    return List.generate(12, (i) {
      final month = ((4 + i - 1) % 12) + 1; // 4,5,6,...12,1,2,3
      final year = (4 + i) > 12 ? fyStartYear + 1 : fyStartYear;
      return DateTime(year, month, 1);
    });
  }

  /// Fetch daily log counts for a given month from Supabase.
  Future<Map<String, int>> _fetchMonthLogCount(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
    final endStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

    final response = await supabase
        .from('workdiary')
        .select('date')
        .eq('staff_id', widget.currentStaff.staffId)
        .gte('date', startStr)
        .lte('date', endStr);

    final Map<String, int> logCount = {};
    for (final entry in response) {
      if (entry['date'] != null) {
        final dateStr = entry['date'] as String;
        logCount[dateStr] = (logCount[dateStr] ?? 0) + 1;
      }
    }
    return logCount;
  }

  void _showLoggedDaysLineGraph() {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final now = DateTime.now();
    final fyMonths = _getFinancialYearMonths();

    // State managed inside the bottom sheet
    DateTime selectedMonth = DateTime(now.year, now.month, 1);
    Map<String, int> sheetLogCount = Map<String, int>.from(_dailyLogCount);
    bool isLoadingMonth = false;

    final sheetBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final axisColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final gridColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const lineColor = Color(0xFFFF5A5F);
    const dotColor = Color(0xFF1E3A8A);
    final dropdownBgColor = isDarkMode ? const Color(0xFF293548) : const Color(0xFFF1F5F9);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

            final spots = List<FlSpot>.generate(daysInMonth, (index) {
              final day = index + 1;
              final key = DateFormat('yyyy-MM-dd').format(
                DateTime(selectedMonth.year, selectedMonth.month, day),
              );
              final count = (sheetLogCount[key] ?? 0).toDouble();
              return FlSpot(day.toDouble(), count);
            });

            const chartMaxY = 10.0;

            return Container(
              height: 470.h,
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
              decoration: BoxDecoration(
                color: sheetBgColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: gridColor,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  // Title row with month picker on the right
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logged Count - ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Date-wise log entries for selected month',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: axisColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Month picker dropdown
                      PopupMenuButton<DateTime>(
                        onSelected: (value) async {
                          setSheetState(() {
                            selectedMonth = value;
                            isLoadingMonth = true;
                          });
                          if (value.year == now.year && value.month == now.month) {
                            setSheetState(() {
                              sheetLogCount = Map<String, int>.from(_dailyLogCount);
                              isLoadingMonth = false;
                            });
                          } else {
                            try {
                              final data = await _fetchMonthLogCount(value);
                              setSheetState(() {
                                sheetLogCount = data;
                                isLoadingMonth = false;
                              });
                            } catch (_) {
                              setSheetState(() {
                                sheetLogCount = {};
                                isLoadingMonth = false;
                              });
                            }
                          }
                        },
                        color: sheetBgColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(color: gridColor),
                        ),
                        constraints: BoxConstraints(maxHeight: 300.h),
                        position: PopupMenuPosition.under,
                        itemBuilder: (_) => fyMonths.map((m) {
                          final isCurrent = m.year == now.year && m.month == now.month;
                          final isSelected = m.year == selectedMonth.year && m.month == selectedMonth.month;
                          return PopupMenuItem<DateTime>(
                            value: m,
                            height: 36.h,
                            child: Row(
                              children: [
                                if (isSelected)
                                  Icon(Icons.check, size: 14.sp, color: const Color(0xFFFF5A5F))
                                else
                                  SizedBox(width: 14.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  DateFormat('MMM yyyy').format(m),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13.sp,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFFFF5A5F) : titleColor,
                                  ),
                                ),
                                if (isCurrent) ...[
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5A5F).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFFF5A5F),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: dropdownBgColor,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: gridColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMM yyyy').format(selectedMonth),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(Icons.arrow_drop_down, size: 18.sp, color: axisColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: isLoadingMonth
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Logged Entry Count',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: axisColor,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Expanded(
                                child: LineChart(
                                  LineChartData(
                                    minX: 1,
                                    maxX: daysInMonth.toDouble(),
                                    minY: 0,
                                    maxY: chartMaxY,
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      horizontalInterval: 1,
                                      verticalInterval: 1,
                                      getDrawingHorizontalLine: (_) => FlLine(
                                        color: gridColor.withValues(alpha: 0.75),
                                        strokeWidth: 1,
                                      ),
                                      getDrawingVerticalLine: (_) => FlLine(
                                        color: gridColor.withValues(alpha: 0.55),
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(
                                        color: gridColor.withValues(alpha: 0.95),
                                        width: 1,
                                      ),
                                    ),
                                    lineTouchData: LineTouchData(
                                      enabled: true,
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipColor: (_) => isDarkMode
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF1F2937),
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((spot) {
                                            return LineTooltipItem(
                                              'Date ${spot.x.toInt()}\nCount: ${spot.y.toInt()}',
                                              TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 32.w,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) => Text(
                                            value.toInt().toString(),
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w500,
                                              color: axisColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          reservedSize: 28.h,
                                          getTitlesWidget: (value, meta) {
                                            if (value < 1 || value > daysInMonth) {
                                              return const SizedBox.shrink();
                                            }
                                            return Text(
                                              value.toInt().toString(),
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w500,
                                                color: axisColor,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: false,
                                        color: lineColor,
                                        barWidth: 2,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                            radius: 2.8,
                                            color: dotColor,
                                            strokeColor: dotColor,
                                            strokeWidth: 0,
                                          ),
                                        ),
                                        belowBarData: BarAreaData(show: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Date of Month',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: axisColor,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context); // close bottom sheet
                                    Navigator.push(
                                      this.context,
                                      MaterialPageRoute(
                                        builder: (_) => MonthlyWorkLogSummaryPage(
                                          month: selectedMonth,
                                          staffId: widget.currentStaff.staffId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5A5F),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.list_alt_rounded, size: 16.sp, color: Colors.white),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'Show Details',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _countWorkingDays(DateTime fromDate, DateTime toDate) {
    int count = 0;
    DateTime current = fromDate;
    while (!current.isAfter(toDate)) {
      if (current.weekday != DateTime.sunday) {
        count += 1;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  double _calculateLeaveDaysInRange({
    required DateTime originalFrom,
    required DateTime originalTo,
    required DateTime clippedFrom,
    required DateTime clippedTo,
    required String remarks,
  }) {
    double days = _countWorkingDays(clippedFrom, clippedTo).toDouble();

    if (remarks.contains('[First Half]') || remarks.contains('[Second Half]')) {
      if (originalFrom.weekday != DateTime.sunday &&
          !clippedFrom.isAfter(originalFrom) &&
          !clippedTo.isBefore(originalFrom)) {
        days = 0.5;
      } else {
        days = 0;
      }
      return days;
    }

    double adjustment = 0;
    final includesOriginalStart =
        !clippedFrom.isAfter(originalFrom) && !clippedTo.isBefore(originalFrom);
    final includesOriginalEnd =
        !clippedFrom.isAfter(originalTo) && !clippedTo.isBefore(originalTo);

    if ((remarks.contains('[Start: First Half]') || remarks.contains('[Start: Second Half]')) &&
        includesOriginalStart &&
        originalFrom.weekday != DateTime.sunday) {
      adjustment += 0.5;
    }
    if ((remarks.contains('[End: First Half]') || remarks.contains('[End: Second Half]')) &&
        includesOriginalEnd &&
        originalTo.weekday != DateTime.sunday) {
      adjustment += 0.5;
    }

    return (days - adjustment).clamp(0.0, days);
  }

  double _calculateHalfDayDaysInRange({
    required DateTime originalFrom,
    required DateTime originalTo,
    required DateTime clippedFrom,
    required DateTime clippedTo,
    required String remarks,
  }) {
    if (remarks.isEmpty) return 0;

    final includesOriginalStart =
        !clippedFrom.isAfter(originalFrom) && !clippedTo.isBefore(originalFrom);
    final includesOriginalEnd =
        !clippedFrom.isAfter(originalTo) && !clippedTo.isBefore(originalTo);

    if (remarks.contains('[First Half]') || remarks.contains('[Second Half]')) {
      if (originalFrom.weekday != DateTime.sunday && includesOriginalStart) {
        return 0.5;
      }
      return 0;
    }

    double half = 0;
    if ((remarks.contains('[Start: First Half]') || remarks.contains('[Start: Second Half]')) &&
        includesOriginalStart &&
        originalFrom.weekday != DateTime.sunday) {
      half += 0.5;
    }
    if ((remarks.contains('[End: First Half]') || remarks.contains('[End: Second Half]')) &&
        includesOriginalEnd &&
        originalTo.weekday != DateTime.sunday) {
      half += 0.5;
    }

    return half;
  }

  /// Fetch leave split data for a given month from Supabase.
  Future<Map<String, double>> _fetchMonthLeaveSplit(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
    final endStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

    final leaveResponse = await supabase
        .from('learequest')
        .select('fromdate, todate, approval_status, leaveremarks')
        .eq('staff_id', widget.currentStaff.staffId)
        .eq('approval_status', 'A')
        .lte('fromdate', endStr)
        .gte('todate', startStr);

    double approvedLeave = 0;
    double halfDayLeave = 0;
    final totalWorkingDays = _countWorkingDays(startOfMonth, endOfMonth).toDouble();

    for (final leave in leaveResponse) {
      final fromDate = DateTime.parse(leave['fromdate']);
      final toDate = DateTime.parse(leave['todate']);
      final remarks = (leave['leaveremarks'] as String?) ?? '';

      final clippedFrom = fromDate.isBefore(startOfMonth) ? startOfMonth : fromDate;
      final lastDay = toDate.isAfter(endOfMonth) ? endOfMonth : toDate;

      approvedLeave += _calculateLeaveDaysInRange(
        originalFrom: fromDate,
        originalTo: toDate,
        clippedFrom: clippedFrom,
        clippedTo: lastDay,
        remarks: remarks,
      );
      halfDayLeave += _calculateHalfDayDaysInRange(
        originalFrom: fromDate,
        originalTo: toDate,
        clippedFrom: clippedFrom,
        clippedTo: lastDay,
        remarks: remarks,
      );
    }

    final fullDayLeave = (approvedLeave - halfDayLeave).clamp(0.0, approvedLeave);
    final earned = fullDayLeave.clamp(0.0, 1.0);
    final lop = (fullDayLeave - earned).clamp(0.0, double.infinity);
    final working = (totalWorkingDays - approvedLeave).clamp(0.0, totalWorkingDays);

    return {
      'working': working,
      'earned': earned,
      'lop': lop,
      'halfDay': halfDayLeave,
    };
  }

  /// Fetch leave requests for the current FY and navigate to LeaveHistoryPage.
  Future<void> _navigateToLeaveHistory() async {
    final now = DateTime.now();
    final int fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    final fyStart = DateTime(fyStartYear, 4, 1);
    final fyEnd = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);

    final response = await supabase
        .from('learequest')
        .select()
        .eq('staff_id', widget.currentStaff.staffId)
        .order('requestdate', ascending: false);

    final leaveTypeNames = {
      'SL': 'Sick Leave',
      'CL': 'Casual Leave',
      'EL': 'Earned Leave',
      'EM': 'Emergency Leave',
    };
    final statusMap = {
      'P': {'name': 'Pending', 'color': AppTheme.warningColor},
      'A': {'name': 'Approved', 'color': AppTheme.successColor},
      'R': {'name': 'Rejected', 'color': AppTheme.errorColor},
    };

    bool isSunday(DateTime d) => d.weekday == DateTime.sunday;

    final leaves = response.map<Map<String, dynamic>>((record) {
      final fromDate = DateTime.parse(record['fromdate']);
      final toDate = DateTime.parse(record['todate']);
      final remarks = record['leaveremarks'] ?? '';
      final approvalStatus = record['approval_status'];
      final status = statusMap[approvalStatus] ??
          {'name': 'Unknown', 'color': AppTheme.warningColor};

      double days = _countWorkingDays(fromDate, toDate).toDouble();
      String displayReason = remarks;

      if (remarks.contains('[First Half]') || remarks.contains('[Second Half]')) {
        days = isSunday(fromDate) ? 0 : 0.5;
        displayReason = remarks.replaceAll(RegExp(r'\s*\[(First Half|Second Half)\]'), '').trim();
      } else if (remarks.contains('[Start:') || remarks.contains('[End:')) {
        double adjustment = 0;
        if (remarks.contains('[Start: First Half]') || remarks.contains('[Start: Second Half]')) {
          if (!isSunday(fromDate)) adjustment += 0.5;
        }
        if (remarks.contains('[End: First Half]') || remarks.contains('[End: Second Half]')) {
          if (!isSunday(toDate)) adjustment += 0.5;
        }
        days = days - adjustment;
        displayReason = remarks
            .replaceAll(RegExp(r'\s*\[Start: (First Half|Second Half)\]'), '')
            .replaceAll(RegExp(r'\s*\[End: (First Half|Second Half)\]'), '')
            .trim();
      }

      return {
        'id': record['learequest_id'],
        'fromDate': fromDate,
        'toDate': toDate,
        'days': days,
        'type': leaveTypeNames[record['leavetype']] ?? 'Unknown',
        'reason': remarks,
        'displayReason': displayReason,
        'status': status['name'],
        'statusColor': status['color'],
        'appliedDate': record['requestdate'] != null
            ? DateTime.parse(record['requestdate'])
            : DateTime.now(),
      };
    }).toList();

    final fyLeaves = leaves.where((l) {
      final fromDate = l['fromDate'] as DateTime;
      return !fromDate.isBefore(fyStart) && !fromDate.isAfter(fyEnd);
    }).toList();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeaveHistoryPage(
          currentStaff: widget.currentStaff,
          leaves: fyLeaves,
          financialYearStart: fyStart,
          financialYearEnd: fyEnd,
        ),
      ),
    );
  }

  void _showLeaveDaysPieChart() {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final now = DateTime.now();
    final fyMonths = _getFinancialYearMonths();

    // Sheet-local state
    DateTime selectedMonth = DateTime(now.year, now.month, 1);
    double working = _currentMonthWorkingDays;
    double earned = _currentMonthEarnedLeaveDays;
    double lop = _currentMonthLopDays;
    double halfDay = _currentMonthHalfDayLeaveDays;
    bool isLoadingMonth = false;

    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final chartBg = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final gridColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dropdownBgColor = isDarkMode ? const Color(0xFF293548) : const Color(0xFFF1F5F9);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final total = working + earned + lop + halfDay;

            return Container(
              height: 470.h,
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: subtitleColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  // Title row with month picker
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leave Split - ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Working (Green), Earned Leave (Blue), LOP (Red), Half Day (Yellow)',
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
                      SizedBox(width: 8.w),
                      // Month picker dropdown
                      PopupMenuButton<DateTime>(
                        onSelected: (value) async {
                          setSheetState(() {
                            selectedMonth = value;
                            isLoadingMonth = true;
                          });
                          if (value.year == now.year && value.month == now.month) {
                            setSheetState(() {
                              working = _currentMonthWorkingDays;
                              earned = _currentMonthEarnedLeaveDays;
                              lop = _currentMonthLopDays;
                              halfDay = _currentMonthHalfDayLeaveDays;
                              isLoadingMonth = false;
                            });
                          } else {
                            try {
                              final data = await _fetchMonthLeaveSplit(value);
                              setSheetState(() {
                                working = data['working']!;
                                earned = data['earned']!;
                                lop = data['lop']!;
                                halfDay = data['halfDay']!;
                                isLoadingMonth = false;
                              });
                            } catch (_) {
                              setSheetState(() {
                                working = 0;
                                earned = 0;
                                lop = 0;
                                halfDay = 0;
                                isLoadingMonth = false;
                              });
                            }
                          }
                        },
                        color: cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          side: BorderSide(color: gridColor),
                        ),
                        constraints: BoxConstraints(maxHeight: 300.h),
                        position: PopupMenuPosition.under,
                        itemBuilder: (_) => fyMonths.map((m) {
                          final isCurrent = m.year == now.year && m.month == now.month;
                          final isSelected = m.year == selectedMonth.year && m.month == selectedMonth.month;
                          return PopupMenuItem<DateTime>(
                            value: m,
                            height: 36.h,
                            child: Row(
                              children: [
                                if (isSelected)
                                  Icon(Icons.check, size: 14.sp, color: const Color(0xFF3B82F6))
                                else
                                  SizedBox(width: 14.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  DateFormat('MMM yyyy').format(m),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13.sp,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF3B82F6) : titleColor,
                                  ),
                                ),
                                if (isCurrent) ...[
                                  SizedBox(width: 6.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'Current',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: dropdownBgColor,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: gridColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMM yyyy').format(selectedMonth),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(Icons.arrow_drop_down, size: 18.sp, color: subtitleColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Expanded(
                    child: isLoadingMonth
                        ? const Center(child: CircularProgressIndicator())
                        : total == 0
                            ? Center(
                                child: Text(
                                  'No leave/working data for this month',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: chartBg,
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: PieChart(
                                        PieChartData(
                                          sectionsSpace: 2,
                                          centerSpaceRadius: 28.r,
                                          sections: [
                                            PieChartSectionData(
                                              value: working,
                                              color: const Color(0xFF10B981),
                                              radius: 72.r,
                                              title: working.toStringAsFixed(1),
                                              titleStyle: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            PieChartSectionData(
                                              value: earned,
                                              color: const Color(0xFF3B82F6),
                                              radius: 72.r,
                                              title: earned.toStringAsFixed(1),
                                              titleStyle: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            PieChartSectionData(
                                              value: lop,
                                              color: const Color(0xFFEF4444),
                                              radius: 72.r,
                                              title: lop.toStringAsFixed(1),
                                              titleStyle: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            PieChartSectionData(
                                              value: halfDay,
                                              color: const Color(0xFFFACC15),
                                              radius: 72.r,
                                              title: halfDay.toStringAsFixed(1),
                                              titleStyle: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 14.w),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildPieLegendItem(
                                          color: const Color(0xFF10B981),
                                          label: 'Working Days',
                                          value: working,
                                          textColor: titleColor,
                                        ),
                                        SizedBox(height: 10.h),
                                        _buildPieLegendItem(
                                          color: const Color(0xFF3B82F6),
                                          label: 'Earned Leave',
                                          value: earned,
                                          textColor: titleColor,
                                        ),
                                        SizedBox(height: 10.h),
                                        _buildPieLegendItem(
                                          color: const Color(0xFFEF4444),
                                          label: 'LOP',
                                          value: lop,
                                          textColor: titleColor,
                                        ),
                                        SizedBox(height: 10.h),
                                        _buildPieLegendItem(
                                          color: const Color(0xFFFACC15),
                                          label: 'Half Day Leave',
                                          value: halfDay,
                                          textColor: titleColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                  ),
                  SizedBox(height: 10.h),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context); // close bottom sheet
                        _navigateToLeaveHistory();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded, size: 16.sp, color: Colors.white),
                            SizedBox(width: 6.w),
                            Text(
                              'History',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPieLegendItem({
    required Color color,
    required String label,
    required double value,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          width: 10.w,
          height: 10.h,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            '$label: ${value.toStringAsFixed(1)}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Format minutes into "Xh Ym" display
  String _formatWorkingHours(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h 0m';
    if (minutes > 0) return '0h ${minutes}m';
    return '0h 0m';
  }

  Widget _buildDayStatusCard({
    required Key key,
    required String dateLabel,
    required String status,
    required IconData icon,
    required List<Color> gradient,
    required int minutes,
    required int logCount,
    required bool isDarkMode,
  }) {
    final workingHours = _formatWorkingHours(minutes);

    return Container(
      key: key,
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Main title row: Icon + Date
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24.sp,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 14.w),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // Status tag
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),

            SizedBox(height: 10.h),

            // Bottom info bar with time and log count
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 16.sp, color: Colors.white),
                  SizedBox(width: 5.w),
                  Text(
                    workingHours,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    width: 1,
                    height: 16.h,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  SizedBox(width: 10.w),
                  Icon(Icons.list_alt_rounded, size: 16.sp, color: Colors.white),
                  SizedBox(width: 5.w),
                  Text(
                    '$logCount ${logCount == 1 ? 'log' : 'logs'}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Stateful widget that fetches and displays work log entries for a given date
class _DayEntriesList extends StatefulWidget {
  final String dateStr;
  final int staffId;
  final bool isDarkMode;
  final Color cardBgColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color dividerColor;

  const _DayEntriesList({
    required this.dateStr,
    required this.staffId,
    required this.isDarkMode,
    required this.cardBgColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.dividerColor,
  });

  @override
  State<_DayEntriesList> createState() => _DayEntriesListState();
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

        return GestureDetector(
          onTap: () {
            final selectedDate =
                DateTime.tryParse(widget.dateStr) ?? DateTime.now();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkLogDetailPage(
                  entry: entry,
                  entryIndex: index,
                  selectedDate: selectedDate,
                  staffId: widget.staffId,
                  jobName: jobName,
                ),
              ),
            );
          },
          child: Container(
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
          ),
        );
      },
    );
  }
}
