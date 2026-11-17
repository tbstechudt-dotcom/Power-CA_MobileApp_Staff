import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/tab_data_cache.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../auth/domain/entities/staff.dart';
import 'apply_leave_page.dart';
import 'leave_filtered_page.dart';

class LeavePage extends StatefulWidget {
  final Staff currentStaff;

  const LeavePage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Leave balance - calculated from actual data
  // CA Financial Year: April 1 to March 31
  // 1 Earned Leave per month (earned progressively)
  double _earnedLeaves = 0; // Earned leaves based on months passed
  double _usedLeaves = 0;
  double _lopDays = 0; // Loss of Pay days (when used > earned)
  double _currentMonthELUsed = 0; // EL days used in current month
  bool _allELUsed = false; // Track if all available EL is used

  // Financial year dates
  late DateTime _financialYearStart;
  late DateTime _financialYearEnd;

  // Leave requests from database
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoadingLeaveRequests = false;

  // Status rows shown on the page (tap opens the filtered list)
  static const List<(String, IconData)> _statusConfigs = [
    ('Pending', Icons.pending_actions_rounded),
    ('Approved', Icons.check_circle_rounded),
    ('Rejected', Icons.cancel_rounded),
  ];

  Color _statusColor(SoftPalette p, String status) {
    switch (status) {
      case 'Approved':
        return p.success;
      case 'Rejected':
        return p.danger;
      default:
        return p.warning;
    }
  }

  static String _fmt(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _calculateFinancialYear();
    // Show the last loaded leaves instantly; the load refreshes quietly.
    final cached = TabDataCache.read<Map<String, Object>>(_cacheKey);
    if (cached != null) {
      _leaveRequests = cached['leaveRequests'] as List<Map<String, dynamic>>;
      _usedLeaves = cached['usedLeaves'] as double;
      _lopDays = cached['lopDays'] as double;
      _currentMonthELUsed = cached['currentMonthELUsed'] as double;
      _allELUsed = cached['allELUsed'] as bool;
    }
    _loadLeaveRequests();
  }

  String get _cacheKey => 'leave:${widget.currentStaff.staffId}';

  /// Check for leave status changes and trigger notifications
  Future<void> _checkLeaveStatusChanges(List<Map<String, dynamic>> leaves) async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    // Skip if notifications are disabled
    if (!notificationProvider.leaveNotificationsEnabled) return;

    final lastKnownStatuses = notificationProvider.lastKnownLeaveStatuses;
    final newStatuses = <int, String>{};

    for (final leave in leaves) {
      final leaveId = leave['id'] as int;
      final status = leave['status'] as String;
      newStatuses[leaveId] = status;

      // Check if this is a status change we should notify about
      final previousStatus = lastKnownStatuses[leaveId];

      // Only notify if status changed FROM Pending TO Approved/Rejected
      if (previousStatus == 'Pending' && (status == 'Approved' || status == 'Rejected')) {
        final fromDate = leave['fromDate'] as DateTime;
        final toDate = leave['toDate'] as DateTime;
        final leaveType = leave['type'] as String? ?? 'Leave';
        final dateRange = fromDate == toDate
            ? DateFormat('dd MMM').format(fromDate)
            : '${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM').format(toDate)}';

        await NotificationService().showLeaveStatusNotification(
          leaveId: leaveId,
          status: status,
          leaveType: leaveType,
          dateRange: dateRange,
        );
      }
    }

    // Update stored statuses
    await notificationProvider.updateLeaveStatuses(newStatuses);
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

  /// Calculate financial year dates (April 1 to March 31)
  /// For Chartered Accountants, the financial year starts April 1
  void _calculateFinancialYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // If current month is April (4) or later, FY starts this year
    // If current month is Jan-Mar, FY started last year
    if (currentMonth >= 4) {
      // April to December: FY is currentYear to currentYear+1
      _financialYearStart = DateTime(currentYear, 4, 1); // April 1 of current year
      _financialYearEnd = DateTime(currentYear + 1, 3, 31, 23, 59, 59); // March 31 of next year
    } else {
      // January to March: FY is previousYear to currentYear
      _financialYearStart = DateTime(currentYear - 1, 4, 1); // April 1 of last year
      _financialYearEnd = DateTime(currentYear, 3, 31, 23, 59, 59); // March 31 of current year
    }

    // Calculate earned leaves based on months passed since FY start
    // 1 Earned Leave per month (earned at start of each month)
    _calculateEarnedLeaves();
  }

  /// Calculate earned leaves based on months passed in current FY
  /// April = 1 EL, May = 2 EL, June = 3 EL, ... March = 12 EL
  void _calculateEarnedLeaves() {
    final now = DateTime.now();

    // Calculate months from April 1 to current date
    int monthsFromApril;
    if (now.month >= 4) {
      // April(4)=1, May(5)=2, ... Dec(12)=9
      monthsFromApril = now.month - 3;
    } else {
      // Jan(1)=10, Feb(2)=11, Mar(3)=12
      monthsFromApril = now.month + 9;
    }

    // Earned leaves = months passed (max 12)
    _earnedLeaves = monthsFromApril.toDouble();
  }

  int _getLeaveCountByStatus(String status) {
    return _leaveRequests.where((leave) => leave['status'] == status).length;
  }

  List<Map<String, dynamic>> _getLeavesByStatus(String status) {
    return _leaveRequests.where((leave) => leave['status'] == status).toList();
  }

  /// Count working days between two dates (excluding Sundays)
  /// Sunday is always a holiday and should not be counted as leave
  double _countWorkingDays(DateTime fromDate, DateTime toDate) {
    double count = 0;
    DateTime current = fromDate;
    while (!current.isAfter(toDate)) {
      // Skip Sundays (weekday 7 in Dart)
      if (current.weekday != DateTime.sunday) {
        count += 1;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  /// Check if a single date is Sunday
  bool _isSunday(DateTime date) {
    return date.weekday == DateTime.sunday;
  }

  void _navigateToFilteredLeaves(String status) {
    final leaves = _getLeavesByStatus(status);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveFilteredPage(
          currentStaff: widget.currentStaff,
          statusFilter: status,
          leaves: leaves,
        ),
      ),
    ).then((_) {
      // Reload leave requests when returning from filtered page
      _loadLeaveRequests();
    });
  }

  Future<void> _loadLeaveRequests() async {
    if (!mounted) return;
    // Spinner only when there's nothing to show yet.
    final hasCache = TabDataCache.read<Map<String, Object>>(_cacheKey) != null;
    setState(() {
      _isLoadingLeaveRequests = !hasCache;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch leave requests for current staff
      final response = await supabase
          .from('learequest')
          .select()
          .eq('staff_id', widget.currentStaff.staffId)
          .order('requestdate', ascending: false);

      // Map leave type codes to display names
      final leaveTypeNames = {
        'SL': 'Sick Leave',
        'CL': 'Casual Leave',
        'EL': 'Earned Leave',
        'EM': 'Emergency Leave',
      };

      // Map approval status to display names and colors
      final statusMap = {
        'P': {'name': 'Pending', 'color': AppTheme.warningColor},
        'A': {'name': 'Approved', 'color': AppTheme.successColor},
        'R': {'name': 'Rejected', 'color': AppTheme.errorColor},
      };

      // Transform database records to UI format
      final leaveRequests = response.map<Map<String, dynamic>>((record) {
        final fromDate = DateTime.parse(record['fromdate']);
        final toDate = DateTime.parse(record['todate']);
        final remarks = record['leaveremarks'] ?? '';
        final approvalStatus = record['approval_status'];

        // Get status from database - Pending, Approved, or Rejected
        final status = statusMap[approvalStatus] ??
            {'name': 'Unknown', 'color': AppTheme.warningColor};

        // Calculate days excluding Sundays (Sunday is always holiday)
        double days = _countWorkingDays(fromDate, toDate);
        String displayReason = remarks;

        // Parse half-day info from remarks
        if (remarks.contains('[First Half]') || remarks.contains('[Second Half]')) {
          // Half-day leave - check if it's a Sunday
          if (_isSunday(fromDate)) {
            days = 0; // Sunday doesn't count
          } else {
            days = 0.5;
          }
          displayReason = remarks.replaceAll(RegExp(r'\s*\[(First Half|Second Half)\]'), '').trim();
        } else if (remarks.contains('[Start:') || remarks.contains('[End:')) {
          // Multi-day with half days - adjust for half days (only if not Sunday)
          double adjustment = 0;
          if (remarks.contains('[Start: First Half]') || remarks.contains('[Start: Second Half]')) {
            if (!_isSunday(fromDate)) {
              adjustment += 0.5;
            }
          }
          if (remarks.contains('[End: First Half]') || remarks.contains('[End: Second Half]')) {
            if (!_isSunday(toDate)) {
              adjustment += 0.5;
            }
          }
          days = days - adjustment;
          displayReason = remarks.replaceAll(RegExp(r'\s*\[Start: (First Half|Second Half)\]'), '')
              .replaceAll(RegExp(r'\s*\[End: (First Half|Second Half)\]'), '').trim();
        }

        return {
          'id': record['learequest_id'],
          'fromDate': fromDate,
          'toDate': toDate,
          'days': days,
          'type': leaveTypeNames[record['leavetype']] ?? 'Unknown',
          'reason': remarks,  // Pass original remarks with half-day tags for detail page parsing
          'displayReason': displayReason,  // Cleaned reason for card display
          'status': status['name'],
          'statusColor': status['color'],
          'appliedDate': record['requestdate'] != null
              ? DateTime.parse(record['requestdate'])
              : DateTime.now(),
        };
      }).toList();

      // Filter leaves to only show current financial year (April 1 - March 31)
      final currentFYLeaves = leaveRequests.where((leave) {
        final fromDate = leave['fromDate'] as DateTime;
        // Check if leave falls within current financial year
        return !fromDate.isBefore(_financialYearStart) &&
               !fromDate.isAfter(_financialYearEnd);
      }).toList();

      // Calculate used EL and LOP (only for current FY)
      // Rule: Use Available EL first, then LOP
      // You EARN 1 EL per month, but can USE as many as Available
      double totalUsedDays = 0;
      double currentMonthUsedDays = 0;  // Track current month usage for display

      // Current month key for display
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month}';

      for (final leave in currentFYLeaves) {
        final days = leave['days'] as double;
        final status = leave['status'] as String;
        final fromDate = leave['fromDate'] as DateTime;

        if (status == 'Approved') {
          totalUsedDays += days;

          // Track current month's usage separately for display
          final monthKey = '${fromDate.year}-${fromDate.month}';
          if (monthKey == currentMonthKey) {
            currentMonthUsedDays += days;
          }
        }
      }

      // Calculate EL used vs LOP
      // EL = min(totalUsedDays, earnedLeaves) - use available EL first
      final usedEL = totalUsedDays.clamp(0.0, _earnedLeaves);

      // For current month LOP display: only show if this month's usage exceeds available
      // Available at start of month = earned - (used before this month)
      final usedBeforeThisMonth = totalUsedDays - currentMonthUsedDays;
      final availableAtMonthStart = (_earnedLeaves - usedBeforeThisMonth).clamp(0.0, _earnedLeaves);
      final currentMonthLOP = (currentMonthUsedDays - availableAtMonthStart).clamp(0.0, double.infinity);

      // Check if all available EL is used (no more EL available)
      final allELUsed = totalUsedDays >= _earnedLeaves;

      // Calculate current month's EL usage (not LOP)
      final currentMonthEL = currentMonthUsedDays.clamp(0.0, availableAtMonthStart);

      // Check for status changes and trigger notifications
      await _checkLeaveStatusChanges(currentFYLeaves);

      TabDataCache.write(_cacheKey, <String, Object>{
        'leaveRequests': currentFYLeaves,
        'usedLeaves': usedEL,
        'lopDays': currentMonthLOP,
        'currentMonthELUsed': currentMonthEL,
        'allELUsed': allELUsed,
      });
      if (!mounted) return;
      setState(() {
        // Only show leaves from current financial year
        _leaveRequests = currentFYLeaves;
        _usedLeaves = usedEL;  // Total EL days used
        _lopDays = currentMonthLOP;  // Only show current month's LOP
        _currentMonthELUsed = currentMonthEL;  // EL used this month
        _allELUsed = allELUsed;  // True if no more EL available
        _isLoadingLeaveRequests = false;
      });
    } catch (e) {
      print('Error loading leave requests: $e');
      setState(() {
        _isLoadingLeaveRequests = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    // Update status bar style based on theme
    _updateStatusBarStyle(p.isDark);

    // Calculate available leaves
    // Available = Earned - Used EL (LOP is calculated separately per monthly limit)
    // Note: _usedLeaves only contains EL days (max 1 per month), not LOP
    final availableLeaves = (_earnedLeaves - _usedLeaves).clamp(0.0, _earnedLeaves);
    // _lopDays is already calculated in _loadLeaveRequests() based on monthly limit

    final fyLabel =
        'FY ${DateFormat('MMM yyyy').format(_financialYearStart)} – ${DateFormat('MMM yyyy').format(_financialYearEnd)}';
    String days(double v) => '${_fmt(v)} ${v == 1 ? 'day' : 'days'}';
    final requestCount = _leaveRequests.length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: p.background,
      extendBody: true,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: HomeBackground(
        child: Column(
          children: [
            AppHeader(
              currentStaff: widget.currentStaff,
              homeStyle: true,
              showPlace: false,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            // Content
            Expanded(
              child: _isLoadingLeaveRequests
                  ? Center(child: CircularProgressIndicator(color: p.accent))
                  : RefreshIndicator(
                      onRefresh: _loadLeaveRequests,
                      color: p.accent,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        children: [
                          HomeEyebrow('My leave · $fyLabel'),
                          HomeInlineHeadline(
                            parts: [
                              (text: 'You have ', strong: false),
                              (text: days(availableLeaves), strong: true),
                              (text: ' of leave ', strong: false),
                              (text: 'available', strong: true),
                              (text: '.', strong: false),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Leave balance
                          HomeSectionCard(
                            title: 'Leave balance',
                            subtitle: '$fyLabel • 1 earned leave per month',
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: HomeStat(
                                        label: 'Earned',
                                        value: days(_earnedLeaves),
                                        dot: p.accent,
                                      ),
                                    ),
                                    Expanded(
                                      child: HomeStat(
                                        label: 'Used',
                                        value: days(_usedLeaves),
                                        dot: p.warning,
                                      ),
                                    ),
                                    Expanded(
                                      child: HomeStat(
                                        label: 'Available',
                                        value: days(availableLeaves),
                                        dot: p.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                HomeSegmentBar(
                                  segments: [
                                    (value: _usedLeaves, color: p.warning),
                                    (value: availableLeaves, color: p.success),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('MMM yyyy').format(_financialYearStart),
                                      style: SoftText.caption(p, size: 12),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat('MMM yyyy').format(_financialYearEnd),
                                      style: SoftText.caption(p, size: 12),
                                    ),
                                  ],
                                ),

                                // Current Month EL Info (show if any EL used this month)
                                if (_currentMonthELUsed > 0)
                                  _NoticeBanner(
                                    icon: Icons.info_outline_rounded,
                                    color: p.accent,
                                    text:
                                        '${DateFormat('MMMM').format(DateTime.now())}: ${_fmt(_currentMonthELUsed)} EL used. Available: ${_fmt(availableLeaves)} EL',
                                  ),

                                // All EL Used Warning
                                if (_allELUsed)
                                  _NoticeBanner(
                                    icon: Icons.warning_amber_rounded,
                                    color: p.warning,
                                    text: 'All EL used. Additional leave will be Loss of Pay.',
                                  ),

                                // LOP Warning (if any for current month)
                                if (_lopDays > 0)
                                  _NoticeBanner(
                                    icon: Icons.warning_amber_rounded,
                                    color: p.danger,
                                    text: 'Loss of Pay this month: ${_fmt(_lopDays)} days',
                                    strong: true,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Requests by status
                          HomeSectionCard(
                            title: 'Requests',
                            subtitle:
                                '$requestCount ${requestCount == 1 ? 'request' : 'requests'} this financial year',
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                            child: Column(
                              children: [
                                for (int i = 0; i < _statusConfigs.length; i++)
                                  HomeStatusRow(
                                    first: i == 0,
                                    color: _statusColor(p, _statusConfigs[i].$1),
                                    label: _statusConfigs[i].$1,
                                    count: '${_getLeaveCountByStatus(_statusConfigs[i].$1)}',
                                    onTap: () => _navigateToFilteredLeaves(_statusConfigs[i].$1),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Apply leave
                          SoftCard(
                            radius: 26,
                            padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Need time off?', style: SoftText.heading(p, size: 17.5)),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Send a leave request to your office',
                                        style: SoftText.caption(p, size: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                HomeBluePill(
                                  label: 'Apply leave',
                                  icon: Icons.add_rounded,
                                  onTap: _navigateToApplyLeave,
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
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 2,
        currentStaff: widget.currentStaff,
      ),
    );
  }

  void _navigateToApplyLeave() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ApplyLeavePage(
          currentStaff: widget.currentStaff,
          existingLeaveRequests: _leaveRequests,
          onLeaveCreated: () {
            _loadLeaveRequests();
          },
        ),
      ),
    );
  }
}

/// Tinted info / warning banner.
class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool strong;

  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.tint(color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: SoftText.body(p, size: 13, color: color).copyWith(
                fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
