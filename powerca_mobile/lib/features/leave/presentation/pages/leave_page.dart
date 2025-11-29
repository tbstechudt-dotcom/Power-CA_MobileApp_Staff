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
  int _totalLeaves = 24; // Annual leave allocation
  double _usedLeaves = 0;
  int _pendingRequests = 0; // Number of pending leave requests

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
    _loadLeaveRequests();
  }

  int _getLeaveCountByStatus(String status) {
    return _leaveRequests.where((leave) => leave['status'] == status).length;
  }

  List<Map<String, dynamic>> _getLeavesByStatus(String status) {
    return _leaveRequests.where((leave) => leave['status'] == status).toList();
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
  Widget build(BuildContext context) {
    final availableLeaves = _totalLeaves - _usedLeaves;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
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
                              'Manage your time off',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // Summary Cards Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Available',
                                    count: availableLeaves.toInt(),
                                    icon: Icons.beach_access_rounded,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Used',
                                    count: _usedLeaves.toInt(),
                                    icon: Icons.event_busy_rounded,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
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
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  icon,
                  size: 20.sp,
                  color: color,
                ),
              ),
              Icon(
                Icons.trending_up_rounded,
                size: 16.sp,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            count.toString(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$title Days',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
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


