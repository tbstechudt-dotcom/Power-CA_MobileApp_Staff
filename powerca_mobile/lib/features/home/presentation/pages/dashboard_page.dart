import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/injection.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/services/tab_data_cache.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/update_dialog.dart';
import '../../../appointments/presentation/appointments_card.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import 'work_log_entry_form_page.dart';
import 'work_log_list_page.dart';

final _dateKey = DateFormat('yyyy-MM-dd');

String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Status of one day in the work log.
enum DayStatus {
  logged('Logged', 'Work entries recorded for the day', Icons.check_rounded),
  leave('On leave', 'Approved leave', Icons.beach_access_rounded),
  pending('Today', 'Today, nothing logged yet', Icons.edit_rounded),
  missed('Missed', 'Past working day with no entries', Icons.priority_high_rounded),
  off('Sunday', 'Weekly off', Icons.weekend_rounded),
  upcoming('Upcoming', 'A day that has not happened yet', Icons.more_horiz_rounded);

  final String label;
  final String description;
  final IconData icon;
  const DayStatus(this.label, this.description, this.icon);

  Color color(SoftPalette p) => switch (this) {
        DayStatus.logged => p.success,
        DayStatus.leave => p.leave,
        DayStatus.pending => p.accent,
        DayStatus.missed => p.warning,
        DayStatus.off => p.muted,
        DayStatus.upcoming => p.muted,
      };
}

/// Dashboard page - Home
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isCheckingSession = false;
  bool _isSessionDialogShowing = false;
  bool _isLoginRequestDialogShowing = false;
  static const int _initialPage = 10000;
  late PageController _pageController;

  // Work log summary state
  static const int _weeksBack = 8;
  bool _isLoadingSummary = true;
  String? _summaryError;
  Map<String, int> _dailyLogCount = {};
  Set<String> _leaveDates = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Show the last loaded summary instantly; the fetch refreshes quietly.
    final cached = TabDataCache.read<(Map<String, int>, Set<String>)>(_cacheKey);
    if (cached != null) {
      _dailyLogCount = cached.$1;
      _leaveDates = cached.$2;
      _isLoadingSummary = false;
    }
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
    final p = SoftPalette.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            SoftIconBadge(icon: Icons.phone_android_rounded, color: p.warning, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text('Login request', style: SoftText.heading(p, size: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$deviceName is trying to sign in to your account.',
              style: SoftText.body(p),
            ),
            const SizedBox(height: 12),
            Text(
              'If you allow, you will be logged out from this device.',
              style: SoftText.body(p, size: 13, color: p.danger)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SoftPillButton(
                  label: 'Deny',
                  variant: SoftPillVariant.outline,
                  height: 46,
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    _isLoginRequestDialogShowing = false;
                    // Deny the request
                    await _sessionService.denyLoginRequest(requestId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Login request denied')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoftPillButton(
                  label: 'Allow',
                  height: 46,
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
    final p = SoftPalette.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            SoftIconBadge(icon: Icons.devices_other_rounded, color: p.danger, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text('Signed in elsewhere', style: SoftText.heading(p, size: 18))),
          ],
        ),
        content: Text(message, style: SoftText.body(p)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SoftPillButton(
            label: 'OK',
            height: 46,
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

  /// First day (Monday) of the week containing [d].
  static DateTime _weekStart(DateTime d) =>
      _dayOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));

  String get _cacheKey => 'home:${widget.currentStaff.staffId}';

  Future<void> _fetchDashboardStats() async {
    // Spinner only when there's nothing to show yet.
    final hasCache =
        TabDataCache.read<(Map<String, int>, Set<String>)>(_cacheKey) != null;
    if (mounted) {
      setState(() {
        _isLoadingSummary = !hasCache;
        _summaryError = null;
      });
    }

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      // Range covers this month and every week shown in the carousel.
      final firstWeek =
          _weekStart(now).subtract(const Duration(days: 7 * (_weeksBack - 1)));
      final rangeStart = firstWeek.isBefore(startOfMonth) ? firstWeek : startOfMonth;
      final rangeEnd = _weekStart(now).add(const Duration(days: 6)).isAfter(endOfMonth)
          ? _weekStart(now).add(const Duration(days: 6))
          : endOfMonth;
      final rangeStartStr = _dateKey.format(rangeStart);
      final rangeEndStr = _dateKey.format(rangeEnd);
      // 1. Work diary entries in range (count per day)
      final diaryResponse = await supabase
          .from('workdiary')
          .select('date')
          .eq('staff_id', widget.currentStaff.staffId)
          .gte('date', rangeStartStr)
          .lte('date', rangeEndStr);

      final Map<String, int> dailyLogCount = {};
      for (final entry in diaryResponse) {
        if (entry['date'] != null) {
          final dateStr = (entry['date'] as String).substring(0, 10);
          dailyLogCount[dateStr] = (dailyLogCount[dateStr] ?? 0) + 1;
        }
      }

      // 2. Approved leave requests overlapping the range
      final leaveResponse = await supabase
          .from('learequest')
          .select('fromdate, todate, approval_status')
          .eq('staff_id', widget.currentStaff.staffId)
          .eq('approval_status', 'A')
          .lte('fromdate', rangeEndStr)
          .gte('todate', rangeStartStr);

      final Set<String> leaveDates = {};

      for (final leave in leaveResponse) {
        final fromDate = DateTime.parse(leave['fromdate']);
        final toDate = DateTime.parse(leave['todate']);
        DateTime day = fromDate.isBefore(rangeStart) ? rangeStart : _dayOnly(fromDate);
        final lastDay = toDate.isAfter(rangeEnd) ? rangeEnd : _dayOnly(toDate);
        while (!day.isAfter(lastDay)) {
          if (day.weekday != DateTime.sunday) {
            leaveDates.add(_dateKey.format(day));
          }
          day = day.add(const Duration(days: 1));
        }
      }

      TabDataCache.write(_cacheKey, (dailyLogCount, leaveDates));
      if (mounted) {
        setState(() {
          _dailyLogCount = dailyLogCount;
          _leaveDates = leaveDates;
          _isLoadingSummary = false;
        });
        _updateWorkLogReminder();
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _summaryError = ErrorMessages.friendly(e);
        });
      }
    }
  }

  /// Show the daily "log your work" reminder (at most once a day, from
  /// 5 PM on working days) or clear it once today has entries.
  void _updateWorkLogReminder() {
    final now = DateTime.now();
    final status = _statusFor(now);
    final notifications = NotificationService();
    if (status == DayStatus.logged || status == DayStatus.leave) {
      notifications.cancelWorkLogReminder();
    } else if (status == DayStatus.pending && now.hour >= 17) {
      notifications.showWorkLogReminder();
    }
  }

  DayStatus _statusFor(DateTime date) {
    final today = _dayOnly(DateTime.now());
    final day = _dayOnly(date);
    final key = _dateKey.format(day);
    if (_leaveDates.contains(key)) return DayStatus.leave;
    if ((_dailyLogCount[key] ?? 0) > 0) return DayStatus.logged;
    if (day.isAfter(today)) return DayStatus.upcoming;
    if (day.weekday == DateTime.sunday) return DayStatus.off;
    if (day == today) return DayStatus.pending;
    return DayStatus.missed;
  }

  Future<void> _openDay(DateTime date) async {
    final status = _statusFor(date);
    if (status == DayStatus.upcoming) return;

    if ((_dailyLogCount[_dateKey.format(date)] ?? 0) > 0) {
      // Load the day's entries, then show the list.
      try {
        final entries = await supabase
            .from('workdiary')
            .select('*')
            .eq('staff_id', widget.currentStaff.staffId)
            .eq('date', _dateKey.format(date));
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkLogListPage(
              selectedDate: date,
              entries: List<Map<String, dynamic>>.from(entries),
              staffId: widget.currentStaff.staffId,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorMessages.friendly(e))),
          );
        }
        return;
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkLogEntryFormPage(
            selectedDate: date,
            staffId: widget.currentStaff.staffId,
          ),
        ),
      );
    }
    _fetchDashboardStats();
  }

  void _openMyWorkLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyWorkLogPage(currentStaff: widget.currentStaff)),
    ).then((_) => _fetchDashboardStats());
  }

  void _openTodayLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLogEntryFormPage(
          selectedDate: _dayOnly(DateTime.now()),
          staffId: widget.currentStaff.staffId,
        ),
      ),
    ).then((_) => _fetchDashboardStats());
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    _updateStatusBarStyle(p.isDark);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Back with the drawer open closes the drawer. (canPop: false also
        // blocks the drawer's own back handling, so do it here.)
        final scaffold = _scaffoldKey.currentState;
        if (scaffold != null && scaffold.isDrawerOpen) {
          scaffold.closeDrawer();
          return;
        }
        // Otherwise minimize the app instead of logging out
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: p.background,
        extendBody: true,
        drawer: AppDrawer(currentStaff: widget.currentStaff),
        body: HomeBackground(
          child: Builder(
            builder: (scaffoldContext) => Column(
              children: [
                AppHeader(
                  currentStaff: widget.currentStaff,
                  homeStyle: true,
                  onMenuTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchDashboardStats,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                      children: [
                        HomeInlineHeadline(parts: _headlineParts()),
                        const SizedBox(height: 26),
                        _buildWorkLogSection(p),
                        const SizedBox(height: 22),
                        AppointmentsCard(currentStaff: widget.currentStaff),
                      ],
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
          onAddPressed: _openTodayLog,
        ),
      ),
    );
  }

  List<({String text, bool strong})> _headlineParts() {
    if (_isLoadingSummary) {
      return const [
        (text: 'Loading your ', strong: false),
        (text: 'work log', strong: true),
        (text: '...', strong: false),
      ];
    }
    return switch (_statusFor(DateTime.now())) {
      DayStatus.logged => const [
          (text: "Today's work is ", strong: false),
          (text: 'logged', strong: true),
          (text: '.', strong: false),
        ],
      DayStatus.leave => const [
          (text: "You're ", strong: false),
          (text: 'on leave', strong: true),
          (text: ' today.', strong: false),
        ],
      DayStatus.off => const [
          (text: "It's ", strong: false),
          (text: 'Sunday', strong: true),
          (text: ', enjoy your day off.', strong: false),
        ],
      _ => const [
          (text: "Today's work is ", strong: false),
          (text: 'not logged', strong: true),
          (text: ' yet.', strong: false),
        ],
    };
  }

  // ---------- My work log (week carousel, Mon - Sat) ----------

  Widget _buildWorkLogSection(SoftPalette p) {
    final now = DateTime.now();
    // Mon - Sat of the last [_weeksBack] weeks, oldest first.
    final firstWeek =
        _weekStart(now).subtract(const Duration(days: 7 * (_weeksBack - 1)));
    final days = [
      for (int w = 0; w < _weeksBack; w++)
        for (int i = 0; i < 6; i++) firstWeek.add(Duration(days: 7 * w + i)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('My work log', style: SoftText.heading(p, size: 18)),
                      const SizedBox(width: 2),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showLegend(p),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(Icons.info_outline_rounded, size: 18, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                  Text('Tap a day to see or add your work', style: SoftText.caption(p, size: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            HomeOutlinePill(
              label: 'View entries',
              icon: Icons.format_list_bulleted_rounded,
              onTap: _openMyWorkLog,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Touch-scrollable day strip with week navigation
        _DayStrip(
          days: days,
          statusFor: (d) => _isLoadingSummary ? DayStatus.upcoming : _statusFor(d),
          isHighlighted: (d) => d == _dayOnly(now),
          onTap: _openDay,
        ),
        if (_summaryError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: p.tint(p.danger),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, size: 18, color: p.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_summaryError!, style: SoftText.caption(p).copyWith(color: p.danger)),
                ),
                TextButton(onPressed: _fetchDashboardStats, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showLegend(SoftPalette p) => showDayStatusLegend(context);
}

class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _WeekArrow({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 22),
      color: p.ink,
      disabledColor: p.border,
    );
  }
}

/// Horizontally scrollable strip of day capsules with a date-range label
/// and week arrows above it.
///
/// Six days fill the width; the strip scrolls freely by touch and snaps to
/// whole days when the finger lifts. It opens on the newest week. The
/// label always shows the six days currently in view, and the arrows
/// scroll by a week.
class _DayStrip extends StatefulWidget {
  /// Days in order, oldest first (Mon - Sat of each week).
  final List<DateTime> days;
  final DayStatus Function(DateTime) statusFor;
  final bool Function(DateTime) isHighlighted;
  final ValueChanged<DateTime> onTap;

  const _DayStrip({
    required this.days,
    required this.statusFor,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  static const int _visible = 6;
  ScrollController? _controller;
  double _extent = 0;
  int _first = 0;
  bool _snapping = false;

  int get _maxFirst => (widget.days.length - _visible).clamp(0, widget.days.length);

  @override
  void initState() {
    super.initState();
    _first = _maxFirst;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Creates the controller once the item width is known, or keeps the
  /// same first day in view when the width changes (rotation, resize).
  void _ensureController(double extent) {
    if (_controller == null) {
      _extent = extent;
      _controller = ScrollController(initialScrollOffset: _first * extent)
        ..addListener(_onScroll);
    } else if ((extent - _extent).abs() > 0.5) {
      _extent = extent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller!.hasClients) _controller!.jumpTo(_first * _extent);
      });
    }
  }

  void _onScroll() {
    if (_extent <= 0) return;
    final i = (_controller!.offset / _extent).round().clamp(0, _maxFirst);
    if (i != _first) setState(() => _first = i);
  }

  void _scrollTo(int index) {
    final c = _controller;
    if (c == null || !c.hasClients) return;
    c.animateTo(
      index.clamp(0, _maxFirst) * _extent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// After a fling or drag ends, settle on the nearest whole day.
  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollEndNotification && !_snapping && _extent > 0) {
      final c = _controller!;
      final target = (c.offset / _extent).round() * _extent;
      if ((target - c.offset).abs() > 0.5) {
        _snapping = true;
        Future.microtask(() async {
          if (c.hasClients) {
            await c.animateTo(
              target.clamp(0.0, c.position.maxScrollExtent),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
          _snapping = false;
        });
      }
    }
    return false;
  }

  String _rangeLabel() {
    if (widget.days.isEmpty) return '';
    final start = widget.days[_first];
    final end = widget.days[(_first + _visible - 1).clamp(0, widget.days.length - 1)];
    return start.month == end.month
        ? '${start.day} – ${DateFormat('d MMM yyyy').format(end)}'
        : '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _WeekArrow(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous week',
              onTap: _first > 0 ? () => _scrollTo(_first - _visible) : null,
            ),
            const SizedBox(width: 8),
            Text(_rangeLabel(), style: SoftText.heading(p, size: 15)),
            const SizedBox(width: 8),
            _WeekArrow(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next week',
              onTap: _first < _maxFirst ? () => _scrollTo(_first + _visible) : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _DayCapsule.rowHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final extent = constraints.maxWidth / _visible;
              _ensureController(extent);
              return NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: ListView.builder(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  // Don't clip: lets the capsule shadows draw past the strip.
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  itemExtent: extent,
                  itemCount: widget.days.length,
                  itemBuilder: (context, i) {
                    final date = widget.days[i];
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: _DayCapsule(
                        date: date,
                        status: widget.statusFor(date),
                        isToday: widget.isHighlighted(date),
                        onTap: () => widget.onTap(date),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Small round status badge shown under a day's date. Uses the same icons
/// and colours as the day status legend.
class _StatusBadge extends StatelessWidget {
  final DayStatus status;
  final double size;
  final Color? ring;

  /// True when drawn on the filled (navy) today capsule.
  final bool onPill;

  const _StatusBadge({required this.status, this.size = 18, this.ring, this.onPill = false});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final shown = switch (status) {
      DayStatus.logged || DayStatus.leave || DayStatus.pending || DayStatus.missed => true,
      _ => false,
    };
    if (!shown) return SizedBox(width: size, height: size);

    // "Nothing logged yet" on the navy today capsule: an accent-blue dot on
    // navy has too little contrast, so invert it (white dot, navy icon).
    final inverted = onPill && status == DayStatus.pending;
    final fill = inverted ? p.onPill : status.color(p);
    final iconColor = inverted ? p.pill : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.all(color: ring!, width: 1.5),
      ),
      child: Icon(status.icon, size: size * 0.6, color: iconColor),
    );
  }
}

/// One day of the week: weekday label above a tall rounded capsule with the
/// date and a status badge. Today is a filled navy capsule.
class _DayCapsule extends StatelessWidget {
  final DateTime date;
  final DayStatus status;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCapsule({
    required this.date,
    required this.status,
    required this.isToday,
    required this.onTap,
  });

  static const double width = 46;
  static const double height = 64;
  static const double todayHeight = 74;
  static const double labelHeight = 18;
  static const double labelGap = 8;

  /// Weekday label + gap + today's (tallest) capsule, plus 2px slack.
  static const double rowHeight = labelHeight + labelGap + todayHeight + 2;

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final upcoming = status == DayStatus.upcoming;
    final fill = isToday ? p.pill : p.surface;
    final dateColor = isToday ? p.onPill : (upcoming ? p.muted : p.ink);

    return Semantics(
      button: !upcoming,
      label: '${DateFormat('EEEE d MMMM').format(date)}, ${status.label}',
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed-height label so large system font sizes can't push the
            // capsule past rowHeight.
            SizedBox(
              height: labelHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormat('EEE').format(date),
                  style: isToday
                      ? SoftText.heading(p, size: 13)
                      : SoftText.caption(p, size: 12.5),
                ),
              ),
            ),
            const SizedBox(height: labelGap),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: p.isDark
                    ? const []
                    : [
                        BoxShadow(
                          color: const Color(0xFF0B1A30)
                              .withValues(alpha: isToday ? 0.22 : 0.06),
                          blurRadius: isToday ? 16 : 10,
                          offset: Offset(0, isToday ? 8 : 4),
                        ),
                      ],
              ),
              child: Material(
                color: fill,
                shape: StadiumBorder(
                  side: isToday ? BorderSide.none : BorderSide(color: p.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: upcoming ? null : onTap,
                  child: SizedBox(
                    width: width,
                    height: isToday ? todayHeight : height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: SoftText.heading(p, size: 17).copyWith(color: dateColor),
                        ),
                        const SizedBox(height: 6),
                        _StatusBadge(
                          status: status,
                          ring: isToday ? p.pill : p.surface,
                          onPill: isToday,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Shared work log data + legend
// =====================================================================

/// Bottom sheet explaining the day status badges.
void showDayStatusLegend(BuildContext context) {
  final p = SoftPalette.of(context);
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Day status', style: SoftText.title(p, size: 20)),
            const SizedBox(height: 4),
            Text(
              'Tap a day to see its entries, or to add work if nothing is logged.',
              style: SoftText.body(p, size: 13),
            ),
            const SizedBox(height: 14),
            for (final s in DayStatus.values)
              if (s != DayStatus.off)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Center(
                          child: s == DayStatus.upcoming
                              ? Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: p.border, width: 1.5),
                                  ),
                                )
                              : _StatusBadge(status: s, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.label, style: SoftText.heading(p, size: 14)),
                            Text(s.description, style: SoftText.caption(p)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

/// Work diary rows and approved leave days for a date range.
class _LogData {
  final Map<String, List<Map<String, dynamic>>> byDate;
  final Set<String> leaveDates;

  const _LogData(this.byDate, this.leaveDates);

  static const empty = _LogData({}, {});

  List<Map<String, dynamic>> entries(DateTime d) => byDate[_dateKey.format(d)] ?? const [];

  int minutes(DateTime d) => entries(d)
      .fold<int>(0, (sum, e) => sum + ((e['minutes'] as num?)?.toInt() ?? 0));

  DayStatus statusFor(DateTime date) {
    final today = _dayOnly(DateTime.now());
    final day = _dayOnly(date);
    if (leaveDates.contains(_dateKey.format(day))) return DayStatus.leave;
    if (entries(day).isNotEmpty) return DayStatus.logged;
    if (day.isAfter(today)) return DayStatus.upcoming;
    if (day.weekday == DateTime.sunday) return DayStatus.off;
    if (day == today) return DayStatus.pending;
    return DayStatus.missed;
  }

  static Future<_LogData> load(int staffId, DateTime from, DateTime to) async {
    final supabase = Supabase.instance.client;
    final fromStr = _dateKey.format(from);
    final toStr = _dateKey.format(to);

    final rows = await supabase
        .from('workdiary')
        .select('*')
        .eq('staff_id', staffId)
        .gte('date', fromStr)
        .lte('date', toStr)
        .order('timefrom');
    final byDate = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final d = r['date'];
      if (d == null) continue;
      byDate.putIfAbsent((d as String).substring(0, 10), () => []).add(r);
    }

    final leaves = await supabase
        .from('learequest')
        .select('fromdate, todate')
        .eq('staff_id', staffId)
        .eq('approval_status', 'A')
        .lte('fromdate', toStr)
        .gte('todate', fromStr);
    final leaveDates = <String>{};
    for (final l in leaves) {
      var day = _dayOnly(DateTime.parse(l['fromdate']));
      final last = _dayOnly(DateTime.parse(l['todate']));
      while (!day.isAfter(last)) {
        if (day.weekday != DateTime.sunday) leaveDates.add(_dateKey.format(day));
        day = day.add(const Duration(days: 1));
      }
    }
    return _LogData(byDate, leaveDates);
  }
}

/// Header row used by the work log sub pages: back button, title and
/// subtitle, then optional trailing widgets.
class _WorkLogHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> trailing;

  const _WorkLogHeader({required this.title, required this.subtitle, this.trailing = const []});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          SoftIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: SoftText.heading(p, size: 19), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: SoftText.caption(p, size: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

String _weekRangeLabel(DateTime weekStart) {
  final end = weekStart.add(const Duration(days: 5));
  return weekStart.month == end.month
      ? '${weekStart.day} – ${DateFormat('d MMM yyyy').format(end)}'
      : '${DateFormat('d MMM').format(weekStart)} – ${DateFormat('d MMM yyyy').format(end)}';
}

DateTime _mondayOf(DateTime d) =>
    _dayOnly(d).subtract(Duration(days: d.weekday - DateTime.monday));

// =====================================================================
// My work log page - pick a day, see its entries
// =====================================================================

/// Week strip (Mon - Sat) with a selectable day and that day's entries.
class MyWorkLogPage extends StatefulWidget {
  final Staff currentStaff;
  const MyWorkLogPage({super.key, required this.currentStaff});

  @override
  State<MyWorkLogPage> createState() => _MyWorkLogPageState();
}

class _MyWorkLogPageState extends State<MyWorkLogPage> {
  static const int _weeksBack = 8;
  late final PageController _weekController = PageController(initialPage: _weeksBack - 1);
  int _weekPage = _weeksBack - 1;
  late DateTime _selected;

  bool _loading = true;
  String? _error;
  _LogData _data = _LogData.empty;
  Map<int, String> _clientNames = {};
  Map<int, String> _jobNames = {};

  @override
  void initState() {
    super.initState();
    final today = _dayOnly(DateTime.now());
    // Sunday is not shown in the strip; select Saturday instead.
    _selected = today.weekday == DateTime.sunday
        ? today.subtract(const Duration(days: 1))
        : today;
    _load();
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  DateTime _weekStartFor(int page) => _mondayOf(DateTime.now())
      .subtract(Duration(days: 7 * (_weeksBack - 1 - page)));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _weekStartFor(0);
      final to = _weekStartFor(_weeksBack - 1).add(const Duration(days: 6));
      final data = await _LogData.load(widget.currentStaff.staffId, from, to);

      // Resolve client and job names for the entry rows.
      final clientIds = <int>{};
      final jobIds = <int>{};
      for (final list in data.byDate.values) {
        for (final e in list) {
          final c = (e['client_id'] as num?)?.toInt();
          final j = (e['job_id'] as num?)?.toInt();
          if (c != null) clientIds.add(c);
          if (j != null) jobIds.add(j);
        }
      }
      final supabase = Supabase.instance.client;
      final clients = <int, String>{};
      final jobs = <int, String>{};
      if (clientIds.isNotEmpty) {
        final rows = await supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', clientIds.toList());
        for (final r in rows) {
          final id = (r['client_id'] as num?)?.toInt();
          if (id != null) clients[id] = (r['clientname'] ?? '').toString().trim();
        }
      }
      if (jobIds.isNotEmpty) {
        final rows = await supabase
            .from('jobshead')
            .select('job_id, work_desc')
            .inFilter('job_id', jobIds.toList());
        for (final r in rows) {
          final id = (r['job_id'] as num?)?.toInt();
          if (id != null) jobs[id] = (r['work_desc'] ?? '').toString().trim();
        }
      }

      if (!mounted) return;
      setState(() {
        _data = data;
        _clientNames = clients;
        _jobNames = jobs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessages.friendly(e);
        _loading = false;
      });
    }
  }

  Future<void> _addWork() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLogEntryFormPage(
          selectedDate: _selected,
          staffId: widget.currentStaff.staffId,
        ),
      ),
    );
    _load();
  }

  Future<void> _openEntries() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLogListPage(
          selectedDate: _selected,
          entries: List<Map<String, dynamic>>.from(_data.entries(_selected)),
          staffId: widget.currentStaff.staffId,
        ),
      ),
    );
    _load();
  }

  void _openOverview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLogOverviewPage(currentStaff: widget.currentStaff),
      ),
    ).then((_) => _load());
  }

  String _time(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    final t = DateTime.tryParse(s) ?? DateTime.tryParse('1970-01-01 $s');
    return t == null ? s : DateFormat('h:mm a').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final weekStart = _weekStartFor(_weekPage);
    final isCurrentWeek = _weekPage == _weeksBack - 1;

    return Scaffold(
      backgroundColor: p.background,
      body: HomeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _WorkLogHeader(
                title: 'My work log',
                subtitle: 'Pick a day to see its entries',
                trailing: [
                  IconButton(
                    tooltip: 'Day status',
                    onPressed: () => showDayStatusLegend(context),
                    icon: Icon(Icons.info_outline_rounded, size: 20, color: p.muted),
                  ),
                  HomeOutlinePill(
                    label: 'Overview',
                    icon: Icons.calendar_month_rounded,
                    onTap: _openOverview,
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      // Week navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _WeekArrow(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Previous week',
                            onTap: _weekPage > 0
                                ? () => _weekController.previousPage(
                                      duration: const Duration(milliseconds: 260),
                                      curve: Curves.easeOut,
                                    )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(_weekRangeLabel(weekStart), style: SoftText.heading(p, size: 15)),
                          const SizedBox(width: 8),
                          _WeekArrow(
                            icon: Icons.chevron_right_rounded,
                            tooltip: 'Next week',
                            onTap: !isCurrentWeek
                                ? () => _weekController.nextPage(
                                      duration: const Duration(milliseconds: 260),
                                      curve: Curves.easeOut,
                                    )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: _DayCapsule.rowHeight,
                        child: PageView.builder(
                          controller: _weekController,
                          // Don't clip: lets the capsule shadows draw past the strip.
                          clipBehavior: Clip.none,
                          itemCount: _weeksBack,
                          onPageChanged: (i) => setState(() => _weekPage = i),
                          itemBuilder: (context, page) {
                            final start = _weekStartFor(page);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (int i = 0; i < 6; i++)
                                  _DayCapsule(
                                    date: start.add(Duration(days: i)),
                                    status: _loading
                                        ? DayStatus.upcoming
                                        : _data.statusFor(start.add(Duration(days: i))),
                                    isToday: start.add(Duration(days: i)) == _selected,
                                    onTap: () => setState(
                                      () => _selected = start.add(Duration(days: i)),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null)
                        SoftMessage(
                          icon: Icons.wifi_off_rounded,
                          title: "Couldn't load your work log",
                          message: _error,
                          actionLabel: 'Retry',
                          onAction: _load,
                          color: p.danger,
                        )
                      else
                        _buildDayCard(p),
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

  Widget _buildDayCard(SoftPalette p) {
    final entries = _data.entries(_selected);
    final status = _data.statusFor(_selected);
    final minutes = _data.minutes(_selected);
    final subtitle = _loading
        ? 'Loading...'
        : status == DayStatus.leave
            ? 'On leave'
            : entries.isEmpty
                ? 'No work logged'
                : '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'} · ${_formatMinutes(minutes)}';

    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(_selected),
                      style: SoftText.heading(p, size: 17.5),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: SoftText.caption(p, size: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              HomeBluePill(label: 'Add work', onTap: _addWork),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: p.border),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined, size: 34, color: p.muted),
                  const SizedBox(height: 10),
                  Text(
                    status == DayStatus.leave
                        ? 'You were on leave this day'
                        : 'No work entries for this day',
                    style: SoftText.body(p, size: 14, color: p.inkSoft),
                  ),
                ],
              ),
            )
          else
            for (int i = 0; i < entries.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.border),
              _buildEntryRow(p, entries[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildEntryRow(SoftPalette p, Map<String, dynamic> e) {
    final client = _clientNames[(e['client_id'] as num?)?.toInt()] ?? 'Client';
    final job = _jobNames[(e['job_id'] as num?)?.toInt()];
    final notes = (e['tasknotes'] ?? '').toString().trim();
    final from = _time(e['timefrom']);
    final to = _time(e['timeto']);
    final mins = (e['minutes'] as num?)?.toInt() ?? 0;
    return InkWell(
      onTap: _openEntries,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client, maxLines: 1, overflow: TextOverflow.ellipsis, style: SoftText.heading(p, size: 14.5)),
                  if ((job ?? '').isNotEmpty || notes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      (job ?? '').isNotEmpty ? job! : notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftText.caption(p, size: 12.5),
                    ),
                  ],
                  if (from.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      to.isEmpty ? from : '$from – $to',
                      style: SoftText.caption(p, size: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(_formatMinutes(mins), style: SoftText.heading(p, size: 14.5)),
            Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Work log overview page - month calendar, today and this month
// =====================================================================

/// Month calendar of the work log, today's summary and this month's totals.
class WorkLogOverviewPage extends StatefulWidget {
  final Staff currentStaff;
  const WorkLogOverviewPage({super.key, required this.currentStaff});

  @override
  State<WorkLogOverviewPage> createState() => _WorkLogOverviewPageState();
}

class _WorkLogOverviewPageState extends State<WorkLogOverviewPage> {
  late DateTime _month; // first day of the month shown in the calendar
  _LogData _monthData = _LogData.empty; // data for [_month]
  _LogData _currentData = _LogData.empty; // data for the current month
  bool _loading = true;
  String? _error;

  DateTime get _thisMonth => DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _month = _thisMonth;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staffId = widget.currentStaff.staffId;
      final monthData = await _LogData.load(
        staffId,
        _month,
        DateTime(_month.year, _month.month + 1, 0),
      );
      final currentData = _month == _thisMonth
          ? monthData
          : await _LogData.load(
              staffId,
              _thisMonth,
              DateTime(_thisMonth.year, _thisMonth.month + 1, 0),
            );
      if (!mounted) return;
      setState(() {
        _monthData = monthData;
        _currentData = currentData;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessages.friendly(e);
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    if (next.isAfter(_thisMonth)) return;
    setState(() => _month = next);
    _load();
  }

  Future<void> _openDate(DateTime date) async {
    final entries = _monthData.entries(date);
    if (entries.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkLogListPage(
            selectedDate: date,
            entries: List<Map<String, dynamic>>.from(entries),
            staffId: widget.currentStaff.staffId,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkLogEntryFormPage(
            selectedDate: date,
            staffId: widget.currentStaff.staffId,
          ),
        ),
      );
    }
    _load();
  }

  void _openMyWorkLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MyWorkLogPage(currentStaff: widget.currentStaff)),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final today = _dayOnly(DateTime.now());

    // Days logged in the shown month
    final loggedInMonth = _monthData.byDate.keys.length;

    // Today
    final todayStatus = _currentData.statusFor(today);
    final todayEntries = _currentData.entries(today).length;
    final todayLabel = switch (todayStatus) {
      DayStatus.logged => 'Logged',
      DayStatus.leave => 'On leave',
      DayStatus.off => 'Sunday',
      _ => 'Not Logged',
    };

    // This month so far (Mon - Sat up to today)
    int working = 0, logged = 0, leave = 0, missed = 0;
    for (var d = _thisMonth; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      if (d.weekday == DateTime.sunday) continue;
      working++;
      switch (_currentData.statusFor(d)) {
        case DayStatus.logged:
          logged++;
        case DayStatus.leave:
          leave++;
        case DayStatus.missed:
          missed++;
        default:
          break;
      }
    }
    String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
    String v(String s) => _loading ? '...' : s;

    return Scaffold(
      backgroundColor: p.background,
      body: HomeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _WorkLogHeader(
                title: 'Work log overview',
                subtitle: 'Month calendar, today and this month',
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SoftCard(
                            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                            child: Row(
                              children: [
                                Icon(Icons.wifi_off_rounded, color: p.danger, size: 20),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_error!, style: SoftText.body(p, size: 13))),
                                TextButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        ),

                      // Work log calendar
                      HomeSectionCard(
                        title: 'Work log',
                        subtitle: _loading
                            ? 'Loading...'
                            : '${days(loggedInMonth)} logged • Tap a date to open',
                        trailing: HomeRoundAction(
                          icon: Icons.north_east_rounded,
                          tooltip: 'My work log',
                          onTap: _openMyWorkLog,
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                        child: _MonthCalendar(
                          month: _month,
                          data: _monthData,
                          canGoNext: _month.isBefore(_thisMonth),
                          onPrev: () => _changeMonth(-1),
                          onNext: () => _changeMonth(1),
                          onTapDate: _openDate,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Today
                      HomeSectionCard(
                        title: 'Today',
                        subtitle: DateFormat('EEEE, d MMMM').format(today),
                        trailing: HomeBluePill(
                          label: 'Log work',
                          onTap: () => _openDate(today),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Expanded(child: HomeStat(label: 'Status', value: v(todayLabel))),
                              Expanded(
                                child: HomeStat(
                                  label: 'Hours',
                                  value: v(_formatHoursMinutes(_currentData.minutes(today))),
                                ),
                              ),
                              Expanded(child: HomeStat(label: 'Entries', value: v('$todayEntries'))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // This month
                      HomeSectionCard(
                        title: 'This month',
                        subtitle:
                            '${DateFormat('MMMM').format(today)} • ${days(working).replaceFirst('day', 'working day')} so far',
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: HomeStat(label: 'Logged', value: v(days(logged)), dot: p.success)),
                                Expanded(child: HomeStat(label: 'Leave', value: v(days(leave)), dot: p.leave)),
                                Expanded(
                                  child: HomeStat(
                                    label: 'Missed',
                                    value: v(days(missed)),
                                    dot: p.muted.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (logged + leave == 0)
                              const _StripedBar()
                            else
                              HomeSegmentBar(
                                segments: [
                                  (value: logged.toDouble(), color: p.success),
                                  (value: leave.toDouble(), color: p.leave),
                                  (value: missed.toDouble(), color: p.border),
                                ],
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(DateFormat('d MMM').format(_thisMonth), style: SoftText.caption(p, size: 12)),
                                const Spacer(),
                                Text('Today', style: SoftText.caption(p, size: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
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

String _formatHoursMinutes(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';

/// Month grid (Sun - Sat) with work log state on each date.
class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final _LogData data;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onTapDate;

  const _MonthCalendar({
    required this.month,
    required this.data,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onTapDate,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final today = _dayOnly(DateTime.now());
    final weekendColor = p.isDark ? const Color(0xFFF87171) : const Color(0xFFE5484D);
    // Grid starts on the Sunday on or before the 1st.
    final first = DateTime(month.year, month.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((first.weekday % 7) + daysInMonth + 6) ~/ 7 * 7;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: onPrev,
              icon: Icon(Icons.chevron_left_rounded, color: p.accent),
            ),
            Expanded(
              child: Text(
                DateFormat('MMM yyyy').format(month),
                textAlign: TextAlign.center,
                style: SoftText.heading(p, size: 16),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: canGoNext ? onNext : null,
              icon: Icon(Icons.chevron_right_rounded, color: canGoNext ? p.accent : p.border),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final d in const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: SoftText.heading(p, size: 12.5).copyWith(color: p.accent),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, i) {
            final date = gridStart.add(Duration(days: i));
            final inMonth = date.month == month.month;
            final isToday = date == today;
            final weekend = date.weekday == DateTime.sunday || date.weekday == DateTime.saturday;
            final status = data.statusFor(date);
            final future = date.isAfter(today);

            Color text;
            Color? fill;
            if (!inMonth) {
              text = p.muted.withValues(alpha: 0.6);
            } else if (isToday) {
              text = Colors.white;
              fill = p.accent;
            } else if (status == DayStatus.logged) {
              text = p.success;
              fill = p.tint(p.success);
            } else if (status == DayStatus.leave) {
              text = p.leave;
              fill = p.tint(p.leave);
            } else {
              text = weekend ? weekendColor : p.ink;
            }

            return Center(
              child: InkResponse(
                onTap: inMonth && !future ? () => onTapDate(date) : null,
                radius: 22,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: isToday && weekend
                        ? Border.all(color: weekendColor, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    '${date.day}',
                    style: SoftText.body(p, size: 15, color: text).copyWith(
                      fontWeight: isToday || fill != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Empty progress bar drawn with light diagonal stripes.
class _StripedBar extends StatelessWidget {
  const _StripedBar();

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 22,
        child: CustomPaint(
          painter: _StripePainter(background: p.surfaceAlt, stripe: p.border),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color background;
  final Color stripe;
  _StripePainter({required this.background, required this.stripe});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = 4;
    for (double x = -size.height; x < size.width + size.height; x += 10) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) =>
      old.background != background || old.stripe != stripe;
}
