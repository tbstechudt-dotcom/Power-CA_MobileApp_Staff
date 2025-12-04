import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../auth/domain/entities/staff.dart';
import 'leave_detail_page.dart';
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
  int _pendingRequests = 0; // Number of pending leave requests
  bool _allELUsed = false; // Track if all available EL is used

  // Financial year dates
  late DateTime _financialYearStart;
  late DateTime _financialYearEnd;

  // Leave requests from database
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoadingLeaveRequests = false;

  // Status configurations (matching jobs page style)
  final List<Map<String, dynamic>> _statusConfigs = [
    {
      'status': 'Pending',
      'icon': Icons.pending_actions_rounded,
      'color': const Color(0xFFF59E0B),
      'gradient': [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
    },
    {
      'status': 'Approved',
      'icon': Icons.check_circle_rounded,
      'color': const Color(0xFF10B981),
      'gradient': [const Color(0xFF34D399), const Color(0xFF10B981)],
    },
    {
      'status': 'Rejected',
      'icon': Icons.cancel_rounded,
      'color': const Color(0xFFEF4444),
      'gradient': [const Color(0xFFF87171), const Color(0xFFEF4444)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _calculateFinancialYear();
    _loadLeaveRequests();
    // Set status bar style for white background with dark icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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
    setState(() {
      _isLoadingLeaveRequests = true;
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
      int pendingCount = 0;

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
        } else if (status == 'Pending') {
          pendingCount++;
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

      setState(() {
        // Only show leaves from current financial year
        _leaveRequests = currentFYLeaves;
        _usedLeaves = usedEL;  // Total EL days used
        _lopDays = currentMonthLOP;  // Only show current month's LOP
        _currentMonthELUsed = currentMonthEL;  // EL used this month
        _pendingRequests = pendingCount;
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
    // Calculate available leaves
    // Available = Earned - Used EL (LOP is calculated separately per monthly limit)
    // Note: _usedLeaves only contains EL days (max 1 per month), not LOP
    final availableLeaves = (_earnedLeaves - _usedLeaves).clamp(0.0, _earnedLeaves);
    // _lopDays is already calculated in _loadLeaveRequests() based on monthly limit

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FC),
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: SafeArea(top: false,
        child: Column(
          children: [
            // Top App Bar with menu handler
            AppHeader(
              currentStaff: widget.currentStaff,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            // Content
            Expanded(
              child: _isLoadingLeaveRequests
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadLeaveRequests,
                      color: AppTheme.primaryColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(12.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Page Title
                            Text(
                              'My Leaves',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'FY ${DateFormat('MMM yyyy').format(_financialYearStart)} - ${DateFormat('MMM yyyy').format(_financialYearEnd)}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // Summary Cards Row - 3 cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Earned',
                                    value: _earnedLeaves,
                                    icon: Icons.calendar_month_rounded,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Used',
                                    value: _usedLeaves,
                                    icon: Icons.event_busy_rounded,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Available',
                                    value: availableLeaves,
                                    icon: Icons.beach_access_rounded,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),

                            // Current Month EL Info (show if any EL used this month)
                            if (_currentMonthELUsed > 0)
                              Container(
                                margin: EdgeInsets.only(top: 12.h),
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFF3B82F6),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 20.sp,
                                      color: const Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        '${DateFormat('MMMM').format(DateTime.now())}: ${_currentMonthELUsed == _currentMonthELUsed.toInt() ? _currentMonthELUsed.toInt() : _currentMonthELUsed.toStringAsFixed(1)} EL used. Available: ${availableLeaves == availableLeaves.toInt() ? availableLeaves.toInt() : availableLeaves.toStringAsFixed(1)} EL',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // All EL Used Warning
                            if (_allELUsed)
                              Container(
                                margin: EdgeInsets.only(top: 12.h),
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 20.sp,
                                      color: const Color(0xFFD97706),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'All EL used. Additional leave will be Loss of Pay.',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // LOP Warning (if any for current month)
                            if (_lopDays > 0)
                              Container(
                                margin: EdgeInsets.only(top: 12.h),
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFFEF4444),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 20.sp,
                                      color: const Color(0xFFEF4444),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'Loss of Pay this month: ${_lopDays == _lopDays.toInt() ? _lopDays.toInt() : _lopDays.toStringAsFixed(1)} days',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Section Title
                            Text(
                              'By Status',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Status List
                            ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _statusConfigs.length,
                              itemBuilder: (context, index) {
                                final config = _statusConfigs[index];
                                final status = config['status'] as String;
                                final icon = config['icon'] as IconData;
                                final gradient = config['gradient'] as List<Color>;
                                final count = _getLeaveCountByStatus(status);

                                return _buildStatusListItem(
                                  status: status,
                                  icon: icon,
                                  gradient: gradient,
                                  count: count,
                                  onTap: () => _navigateToFilteredLeaves(status),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToApplyLeave(),
        backgroundColor: AppTheme.primaryColor,
        elevation: 4,
        icon: Icon(Icons.add_rounded, size: 22.sp, color: Colors.white),
        label: Text(
          'Apply Leave',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
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

  void _navigateToLeaveDetail(Map<String, dynamic> leave) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LeaveDetailPage(
          leave: leave,
          onDeleted: () {
            _loadLeaveRequests();
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    // Format display: show decimal only if not a whole number
    final displayValue = value == value.toInt()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              size: 18.sp,
              color: color,
            ),
          ),
          SizedBox(height: 8.h),
          // Value
          Text(
            displayValue,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusListItem({
    required String status,
    required IconData icon,
    required List<Color> gradient,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: gradient[1].withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern icon
            Positioned(
              right: -15.w,
              top: -15.h,
              child: Icon(
                icon,
                size: 70.sp,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 44.w,
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      icon,
                      size: 22.sp,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  // Status name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Tap to view leaves',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16.sp,
                    color: Colors.white.withValues(alpha: 0.8),
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


