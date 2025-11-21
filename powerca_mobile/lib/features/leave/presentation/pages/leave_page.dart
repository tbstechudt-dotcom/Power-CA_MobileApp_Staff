import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../auth/domain/entities/staff.dart';
import 'leave_detail_page.dart';

class LeavePage extends StatefulWidget {
  final Staff currentStaff;

  const LeavePage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Leave balance - calculated from actual data
  int _totalLeaves = 24; // Annual leave allocation
  double _usedLeaves = 0;
  int _pendingRequests = 0; // Number of pending leave requests

  // Leave requests from database
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoadingLeaveRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
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
        final status = statusMap[record['approval_status']] ??
            {'name': 'Unknown', 'color': AppTheme.warningColor};

        // Calculate days including half-day support
        double days = toDate.difference(fromDate).inDays + 1.0;
        String displayReason = remarks;

        // Parse half-day info from remarks
        if (remarks.contains('[First Half]') || remarks.contains('[Second Half]')) {
          days = 0.5;
          displayReason = remarks.replaceAll(RegExp(r'\s*\[(First Half|Second Half)\]'), '').trim();
        } else if (remarks.contains('[Start:') || remarks.contains('[End:')) {
          // Multi-day with half days
          double adjustment = 0;
          if (remarks.contains('[Start: First Half]') || remarks.contains('[Start: Second Half]')) {
            adjustment += 0.5;
          }
          if (remarks.contains('[End: First Half]') || remarks.contains('[End: Second Half]')) {
            adjustment += 0.5;
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

      // Calculate used leaves and count pending requests
      double usedDays = 0;
      int pendingCount = 0;

      for (final leave in leaveRequests) {
        final days = leave['days'] as double;
        final status = leave['status'] as String;

        if (status == 'Approved') {
          usedDays += days;
        } else if (status == 'Pending') {
          pendingCount++;
        }
      }

      setState(() {
        _leaveRequests = leaveRequests;
        _usedLeaves = usedDays;
        _pendingRequests = pendingCount;
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: SafeArea(
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

            // Leave Balance Cards
            _buildLeaveBalanceCards(),

            // Tab Bar
            _buildTabBar(),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaveHistoryTab(),
                  _buildApplyLeaveTab(),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 2,
        currentStaff: widget.currentStaff,
      ),
    );
  }

  Widget _buildLeaveBalanceCards() {
    final availableLeaves = _totalLeaves - _usedLeaves;

    // Format display values
    String formatDays(double days) {
      return days == days.toInt() ? days.toInt().toString() : days.toStringAsFixed(1);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          // Available Leaves
          Expanded(
            child: _buildBalanceCard(
              title: 'Available',
              count: formatDays(availableLeaves),
              icon: Icons.beach_access,
              gradientColors: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ),
          ),
          SizedBox(width: 12.w),
          // Used Leaves
          Expanded(
            child: _buildBalanceCard(
              title: 'Used',
              count: formatDays(_usedLeaves),
              icon: Icons.event_busy,
              gradientColors: const [Color(0xFF2196F3), Color(0xFF42A5F5)],
            ),
          ),
          SizedBox(width: 12.w),
          // Pending Requests (count of requests, not days)
          Expanded(
            child: _buildBalanceCard(
              title: 'Pending',
              count: _pendingRequests.toString(),
              icon: Icons.pending_actions,
              gradientColors: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required String count,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    final baseColor = gradientColors[0];
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: baseColor,
            size: 22.sp,
          ),
          SizedBox(height: 6.h),
          Text(
            count,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(10.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8F8E90),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Leave History'),
          Tab(text: 'Apply Leave'),
        ],
      ),
    );
  }

  Widget _buildLeaveHistoryTab() {
    if (_isLoadingLeaveRequests) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_leaveRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64.sp,
              color: const Color(0xFFE0E0E0),
            ),
            SizedBox(height: 16.h),
            Text(
              'No leave requests yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF8F8E90),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      itemCount: _leaveRequests.length,
      itemBuilder: (context, index) {
        final leave = _leaveRequests[index];
        return GestureDetector(
          onTap: () => _navigateToLeaveDetail(leave),
          child: _buildLeaveRequestCard(leave),
        );
      },
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

  Widget _buildLeaveRequestCard(Map<String, dynamic> leave) {
    final fromDate = leave['fromDate'] as DateTime;
    final toDate = leave['toDate'] as DateTime;
    final days = leave['days'] as double;
    final daysDisplay = days == days.toInt() ? days.toInt().toString() : days.toStringAsFixed(1);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type and Status
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 14.sp,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      leave['type'],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: (leave['statusColor'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  leave['status'],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: leave['statusColor'],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Date Range
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16.sp,
                color: const Color(0xFF8F8E90),
              ),
              SizedBox(width: 8.w),
              Text(
                fromDate == toDate
                    ? DateFormat('dd MMM yyyy').format(fromDate)
                    : '${DateFormat('dd MMM yyyy').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF080E29),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '$daysDisplay ${days == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // Reason
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.description_outlined,
                size: 16.sp,
                color: const Color(0xFF8F8E90),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  leave['displayReason'] ?? leave['reason'],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // Applied Date
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14.sp,
                color: const Color(0xFFA8A8A8),
              ),
              SizedBox(width: 6.w),
              Text(
                'Applied on ${DateFormat('dd MMM yyyy').format(leave['appliedDate'])}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFA8A8A8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplyLeaveTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions Card
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Fill in the form below to submit a new leave request',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Apply Leave Form
          _buildLeaveApplicationForm(),
        ],
      ),
    );
  }

  Widget _buildDayTypeSelector({
    required String selectedType,
    required Function(String) onChanged,
    required bool enabled,
  }) {
    final options = [
      {'value': 'full', 'label': 'Full Day'},
      {'value': 'first_half', 'label': 'First Half'},
      {'value': 'second_half', 'label': 'Second Half'},
    ];

    return Row(
      children: options.map((option) {
        final isSelected = selectedType == option['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w),
            child: InkWell(
              onTap: enabled ? () => onChanged(option['value']!) : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : enabled
                          ? Colors.white
                          : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : const Color(0xFFE9F0F8),
                  ),
                ),
                child: Center(
                  child: Text(
                    option['label']!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : enabled
                              ? const Color(0xFF080E29)
                              : const Color(0xFFA8A8A8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveApplicationForm() {
    DateTime? fromDate;
    DateTime? toDate;
    String? leaveType;
    String fromDayType = 'full';
    String toDayType = 'full';
    bool isMultiDay = false; // Default to single day leave
    final reasonController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setFormState) {
        // For single day, toDate is same as fromDate
        DateTime? effectiveToDate = isMultiDay ? toDate : fromDate;

        // Calculate number of days with half-day support
        double? numberOfDays;
        if (fromDate != null && effectiveToDate != null) {
          if (fromDate == effectiveToDate) {
            // Same day leave
            numberOfDays = fromDayType == 'full' ? 1.0 : 0.5;
          } else {
            // Multi-day leave
            int fullDays = effectiveToDate!.difference(fromDate!).inDays - 1;
            if (fullDays < 0) fullDays = 0;

            double firstDayValue = fromDayType == 'full' ? 1.0 : 0.5;
            double lastDayValue = toDayType == 'full' ? 1.0 : 0.5;

            numberOfDays = firstDayValue + fullDays + lastDayValue;
          }
        }

        String daysDisplay = numberOfDays != null
            ? (numberOfDays == numberOfDays.toInt()
                ? numberOfDays.toInt().toString()
                : numberOfDays.toStringAsFixed(1))
            : '';

        // Build detailed breakdown string
        String leaveDetailsBreakdown = '';
        if (fromDate != null && effectiveToDate != null) {
          String fromDayLabel = fromDayType == 'full'
              ? 'Full Day'
              : (fromDayType == 'first_half' ? 'First Half' : 'Second Half');

          if (fromDate == effectiveToDate) {
            // Same day
            leaveDetailsBreakdown = '${DateFormat('dd MMM yyyy').format(fromDate!)} - $fromDayLabel';
          } else {
            // Multi-day - show each date separately
            String toDayLabel = toDayType == 'full'
                ? 'Full Day'
                : (toDayType == 'first_half' ? 'First Half' : 'Second Half');

            // Calculate middle days if any
            int daysBetween = effectiveToDate!.difference(fromDate!).inDays;

            if (daysBetween == 1) {
              // Just two consecutive days
              leaveDetailsBreakdown = '${DateFormat('dd MMM').format(fromDate!)} - $fromDayLabel\n${DateFormat('dd MMM').format(effectiveToDate!)} - $toDayLabel';
            } else {
              // Multiple days with days in between
              String middleDaysText = daysBetween > 2
                  ? '\n${DateFormat('dd MMM').format(fromDate!.add(const Duration(days: 1)))} to ${DateFormat('dd MMM').format(effectiveToDate!.subtract(const Duration(days: 1)))} - Full Days'
                  : '';
              leaveDetailsBreakdown = '${DateFormat('dd MMM').format(fromDate!)} - $fromDayLabel$middleDaysText\n${DateFormat('dd MMM').format(effectiveToDate!)} - $toDayLabel';
            }
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leave Type Dropdown
            Text(
              'Leave Type',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFE9F0F8)),
              ),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select leave type',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    color: const Color(0xFFA8A8A8),
                  ),
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
                items: ['Sick Leave', 'Casual Leave', 'Earned Leave', 'Emergency Leave']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.sp,
                            ),
                          ),
                        ),)
                    .toList(),
                onChanged: (value) {
                  setFormState(() {
                    leaveType = value;
                  });
                },
              ),
            ),

            SizedBox(height: 20.h),

            // Leave Duration Toggle
            Text(
              'Leave Duration',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setFormState(() {
                        isMultiDay = false;
                        toDate = null; // Clear toDate when switching to single day
                        toDayType = 'full';
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: !isMultiDay
                            ? AppTheme.primaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: !isMultiDay
                              ? AppTheme.primaryColor
                              : const Color(0xFFE9F0F8),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Single Day',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: !isMultiDay
                                ? Colors.white
                                : const Color(0xFF080E29),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setFormState(() {
                        isMultiDay = true;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: isMultiDay
                            ? AppTheme.primaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: isMultiDay
                              ? AppTheme.primaryColor
                              : const Color(0xFFE9F0F8),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Multiple Days',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isMultiDay
                                ? Colors.white
                                : const Color(0xFF080E29),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20.h),

            // From Date (or just "Date" for single day)
            Text(
              isMultiDay ? 'From Date' : 'Date',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            InkWell(
              onTap: () async {
                // Find next available date (skip Sundays)
                DateTime initialDate = DateTime.now();
                if (initialDate.weekday == DateTime.sunday) {
                  initialDate = initialDate.add(const Duration(days: 1));
                }

                final date = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  selectableDayPredicate: (DateTime day) {
                    // Disable Sundays
                    return day.weekday != DateTime.sunday;
                  },
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppTheme.primaryColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setFormState(() {
                    fromDate = date;
                    // Reset toDate if it's before fromDate
                    if (toDate != null && toDate!.isBefore(fromDate!)) {
                      toDate = null;
                    }
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFFE9F0F8)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20.sp,
                      color: const Color(0xFF8F8E90),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        fromDate != null
                            ? DateFormat('dd MMM yyyy').format(fromDate!)
                            : 'Select start date',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          color: fromDate != null
                              ? const Color(0xFF080E29)
                              : const Color(0xFFA8A8A8),
                        ),
                      ),
                    ),
                    if (fromDate != null)
                      GestureDetector(
                        onTap: () {
                          setFormState(() {
                            fromDate = null;
                            toDate = null; // Also clear toDate since it depends on fromDate
                            fromDayType = 'full';
                            toDayType = 'full';
                          });
                        },
                        child: Icon(
                          Icons.cancel,
                          size: 20.sp,
                          color: const Color(0xFFA8A8A8),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // From Day Type Selector
            if (fromDate != null) ...[
              SizedBox(height: 8.h),
              Text(
                isMultiDay ? 'From Date - Day Type' : 'Day Type',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 4.h),
              _buildDayTypeSelector(
                selectedType: fromDayType,
                onChanged: (value) {
                  setFormState(() {
                    fromDayType = value;
                    // If same day, sync the to day type
                    if (fromDate != null && toDate != null && fromDate == toDate) {
                      toDayType = value;
                    }
                  });
                },
                enabled: true,
              ),
            ],

            // To Date (only show for multi-day leave)
            if (isMultiDay) ...[
              SizedBox(height: 20.h),

              // To Date
              Text(
                'To Date',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF080E29),
                ),
              ),
              SizedBox(height: 8.h),
              InkWell(
                onTap: fromDate == null
                    ? null
                    : () async {
                      // Find next available date from fromDate (skip Sundays)
                      DateTime initialDate = fromDate!;
                      if (initialDate.weekday == DateTime.sunday) {
                        initialDate = initialDate.add(const Duration(days: 1));
                      }

                      final date = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: fromDate!,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        selectableDayPredicate: (DateTime day) {
                          // Disable Sundays
                          return day.weekday != DateTime.sunday;
                        },
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppTheme.primaryColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setFormState(() {
                          toDate = date;
                        });
                      }
                    },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: fromDate == null
                        ? const Color(0xFFF5F7FA)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFE9F0F8)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20.sp,
                        color: fromDate == null
                            ? const Color(0xFFA8A8A8)
                            : const Color(0xFF8F8E90),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          toDate != null
                              ? DateFormat('dd MMM yyyy').format(toDate!)
                              : 'Select end date',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            color: toDate != null
                                ? const Color(0xFF080E29)
                                : const Color(0xFFA8A8A8),
                          ),
                        ),
                      ),
                      if (toDate != null)
                        GestureDetector(
                          onTap: () {
                            setFormState(() {
                              toDate = null;
                              toDayType = 'full';
                            });
                          },
                          child: Icon(
                            Icons.cancel,
                            size: 20.sp,
                            color: const Color(0xFFA8A8A8),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // To Day Type Selector (only show for multi-day leaves)
            if (isMultiDay && fromDate != null && toDate != null && fromDate != toDate) ...[
              SizedBox(height: 8.h),
              Text(
                'To Date - Day Type',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: 4.h),
              _buildDayTypeSelector(
                selectedType: toDayType,
                onChanged: (value) {
                  setFormState(() {
                    toDayType = value;
                  });
                },
                enabled: true,
              ),
            ],

            // Number of Days Display with Details
            if (numberOfDays != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 18.sp,
                          color: AppTheme.successColor,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Total: $daysDisplay ${numberOfDays == 1 ? 'day' : 'days'}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    if (leaveDetailsBreakdown.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Padding(
                        padding: EdgeInsets.only(left: 26.w),
                        child: Text(
                          leaveDetailsBreakdown,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.successColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            SizedBox(height: 20.h),

            // Reason
            Text(
              'Reason',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFE9F0F8)),
              ),
              child: TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter reason for leave...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    color: const Color(0xFFA8A8A8),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16.w),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  color: const Color(0xFF080E29),
                ),
              ),
            ),

            SizedBox(height: 32.h),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () async {
                  // Validate form
                  if (leaveType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select leave type'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  // For single day, effectiveToDate is fromDate
                  final submitToDate = isMultiDay ? toDate : fromDate;

                  if (fromDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select date'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (isMultiDay && toDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select end date'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter reason'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // Check for date conflicts with existing leave requests
                  List<String> conflictingDates = [];

                  // Normalize selected dates (remove time component)
                  final normalizedFromDate = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
                  final normalizedToDate = DateTime(submitToDate!.year, submitToDate!.month, submitToDate!.day);

                  // Determine half-day info for new request
                  String newStartHalf = fromDayType; // 'full', 'first_half', 'second_half'
                  String newEndHalf = (fromDate == submitToDate) ? fromDayType : toDayType;

                  print('DEBUG: Checking date conflicts');
                  print('DEBUG: Selected dates: $normalizedFromDate to $normalizedToDate');
                  print('DEBUG: New request half-day: start=$newStartHalf, end=$newEndHalf');
                  print('DEBUG: Total leave requests to check: ${_leaveRequests.length}');

                  for (final leave in _leaveRequests) {
                    // Only check against Pending and Approved leaves (not Rejected)
                    final status = leave['status'] as String;
                    if (status == 'Rejected') continue;

                    final existingFromRaw = leave['fromDate'] as DateTime;
                    final existingToRaw = leave['toDate'] as DateTime;
                    final existingReason = leave['reason'] as String? ?? '';

                    // Normalize existing dates
                    final existingFrom = DateTime(existingFromRaw.year, existingFromRaw.month, existingFromRaw.day);
                    final existingTo = DateTime(existingToRaw.year, existingToRaw.month, existingToRaw.day);

                    // Extract half-day info from existing leave remarks
                    String existingStartHalf = 'full';
                    String existingEndHalf = 'full';

                    if (existingFrom == existingTo) {
                      // Same day leave - check for single half-day tag
                      if (existingReason.contains('[First Half]')) {
                        existingStartHalf = 'first_half';
                        existingEndHalf = 'first_half';
                      } else if (existingReason.contains('[Second Half]')) {
                        existingStartHalf = 'second_half';
                        existingEndHalf = 'second_half';
                      }
                    } else {
                      // Multi-day leave - check for start/end tags
                      if (existingReason.contains('[Start: First Half]')) {
                        existingStartHalf = 'first_half';
                      } else if (existingReason.contains('[Start: Second Half]')) {
                        existingStartHalf = 'second_half';
                      }
                      if (existingReason.contains('[End: First Half]')) {
                        existingEndHalf = 'first_half';
                      } else if (existingReason.contains('[End: Second Half]')) {
                        existingEndHalf = 'second_half';
                      }
                    }

                    print('DEBUG: Checking against leave: $existingFrom to $existingTo (status: $status)');
                    print('DEBUG: Existing half-day: start=$existingStartHalf, end=$existingEndHalf');

                    // Check if date ranges overlap
                    // Overlap condition: newFrom <= existingTo AND newTo >= existingFrom
                    if (normalizedFromDate.compareTo(existingTo) <= 0 && normalizedToDate.compareTo(existingFrom) >= 0) {
                      print('DEBUG: DATE OVERLAP FOUND - checking half-day compatibility');
                      // Find the overlapping dates
                      DateTime overlapStart = normalizedFromDate.isAfter(existingFrom) ? normalizedFromDate : existingFrom;
                      DateTime overlapEnd = normalizedToDate.isBefore(existingTo) ? normalizedToDate : existingTo;

                      // Add each overlapping date to the list (with half-day awareness)
                      DateTime current = overlapStart;
                      while (current.compareTo(overlapEnd) <= 0) {
                        bool isConflict = true;

                        // Determine the half-day type for this specific date in new request
                        String newHalfForDate = 'full';
                        if (current == normalizedFromDate && current == normalizedToDate) {
                          // Single day request
                          newHalfForDate = newStartHalf;
                        } else if (current == normalizedFromDate) {
                          newHalfForDate = newStartHalf;
                        } else if (current == normalizedToDate) {
                          newHalfForDate = newEndHalf;
                        }

                        // Determine the half-day type for this specific date in existing leave
                        String existingHalfForDate = 'full';
                        if (current == existingFrom && current == existingTo) {
                          // Existing is single day
                          existingHalfForDate = existingStartHalf;
                        } else if (current == existingFrom) {
                          existingHalfForDate = existingStartHalf;
                        } else if (current == existingTo) {
                          existingHalfForDate = existingEndHalf;
                        }

                        // Check if the halves are complementary (can coexist)
                        // first_half + second_half = OK (no conflict)
                        // first_half + first_half = CONFLICT
                        // full + anything = CONFLICT
                        if (newHalfForDate != 'full' && existingHalfForDate != 'full') {
                          // Both are half days - check if they're complementary
                          if (newHalfForDate != existingHalfForDate) {
                            isConflict = false; // Complementary half-days, no conflict
                            print('DEBUG: Complementary half-days for ${DateFormat('dd MMM').format(current)}: new=$newHalfForDate, existing=$existingHalfForDate');
                          }
                        }

                        if (isConflict) {
                          String dateStr = DateFormat('dd MMM yyyy').format(current);
                          if (!conflictingDates.contains(dateStr)) {
                            conflictingDates.add(dateStr);
                            print('DEBUG: Conflict on $dateStr: new=$newHalfForDate, existing=$existingHalfForDate');
                          }
                        }
                        current = current.add(const Duration(days: 1));
                      }
                    }
                  }

                  print('DEBUG: Conflicting dates found: $conflictingDates');

                  if (conflictingDates.isNotEmpty) {
                    // Show error with conflicting dates
                    String message = conflictingDates.length == 1
                        ? 'This date is already taken: ${conflictingDates[0]}\n\nPlease choose other dates.'
                        : 'These dates are already taken:\n${conflictingDates.join(', ')}\n\nPlease choose other dates.';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                    return;
                  }

                  // Show loading indicator
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  try {
                    final supabase = Supabase.instance.client;

                    // Map leave type to code
                    final leaveTypeCode = {
                      'Sick Leave': 'SL',
                      'Casual Leave': 'CL',
                      'Earned Leave': 'EL',
                      'Emergency Leave': 'EM',
                    }[leaveType] ?? 'CL';

                    // Generate unique learequest_id (max 99999 due to numeric(5,0) precision)
                    // Use timestamp modulo to get a 5-digit number
                    final requestId = DateTime.now().millisecondsSinceEpoch % 100000;

                    // Build remarks with half-day info
                    String remarks = reasonController.text.trim();
                    if (fromDayType != 'full' || (submitToDate != fromDate && toDayType != 'full')) {
                      String halfDayInfo = '';
                      if (fromDate == submitToDate) {
                        // Same day half leave
                        halfDayInfo = fromDayType == 'first_half' ? ' [First Half]' : ' [Second Half]';
                      } else {
                        // Multi-day with potential half days
                        if (fromDayType != 'full') {
                          halfDayInfo += ' [Start: ${fromDayType == 'first_half' ? 'First Half' : 'Second Half'}]';
                        }
                        if (toDayType != 'full') {
                          halfDayInfo += ' [End: ${toDayType == 'first_half' ? 'First Half' : 'Second Half'}]';
                        }
                      }
                      remarks += halfDayInfo;
                    }

                    final leaveData = {
                      'org_id': widget.currentStaff.orgId,
                      'con_id': widget.currentStaff.conId,
                      'loc_id': widget.currentStaff.locId,
                      'learequest_id': requestId,
                      'staff_id': widget.currentStaff.staffId,
                      'requestdate': DateTime.now().toIso8601String(),
                      'fromdate': fromDate!.toIso8601String(),
                      'todate': submitToDate!.toIso8601String(),
                      'leavetype': leaveTypeCode,
                      'leaveremarks': remarks,
                      'createdby': widget.currentStaff.username,
                      'createddate': DateTime.now().toIso8601String(),
                      'approval_status': 'P', // P = Pending
                      'source': 'M', // M = Mobile
                    };

                    print('DEBUG: About to insert leave request');
                    print('DEBUG: Leave data = $leaveData');

                    // Insert leave request
                    final response = await supabase.from('learequest').insert(leaveData);

                    print('DEBUG: Insert completed');
                    print('DEBUG: Response = $response');

                    // Close loading dialog
                    if (!context.mounted) return;
                    Navigator.of(context).pop();

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Leave request submitted successfully!\n'
                          'Type: $leaveType\n'
                          'From: ${DateFormat('dd MMM yyyy').format(fromDate!)}\n'
                          'To: ${DateFormat('dd MMM yyyy').format(submitToDate!)}\n'
                          'Days: $daysDisplay',
                        ),
                        backgroundColor: AppTheme.successColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );

                    // Clear form
                    setFormState(() {
                      leaveType = null;
                      fromDate = null;
                      toDate = null;
                      isMultiDay = false;
                      fromDayType = 'full';
                      toDayType = 'full';
                      reasonController.clear();
                    });

                    // Reload leave requests to show the newly created one
                    await _loadLeaveRequests();

                    // Switch to history tab
                    _tabController.animateTo(0);
                  } catch (e) {
                    // Log full error to console
                    print('ERROR inserting leave request: $e');
                    print('ERROR details: ${e.runtimeType}');

                    // Close loading dialog
                    if (!context.mounted) return;
                    Navigator.of(context).pop();

                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating leave request: ${e.toString()}'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Submit Leave Request',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.h),
          ],
        );
      },
    );
  }
}
