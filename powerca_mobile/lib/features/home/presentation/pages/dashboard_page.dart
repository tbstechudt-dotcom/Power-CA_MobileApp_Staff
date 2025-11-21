import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../auth/domain/entities/staff.dart';
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

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  double _hoursLoggedThisWeek = 0.0;
  int _entriesThisMonth = 0;
  double _avgHoursPerDay = 0.0;
  int _daysActive = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final now = DateTime.now();

      // Calculate start of this week (Monday)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekStr = DateFormat('yyyy-MM-dd').format(
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day)
      );

      // Calculate start of this month
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfMonthStr = DateFormat('yyyy-MM-dd').format(startOfMonth);

      // Fetch hours logged this week
      final weekResponse = await supabase
          .from('workdiary')
          .select('minutes')
          .eq('staff_id', widget.currentStaff.staffId)
          .gte('date', startOfWeekStr);

      double totalHours = 0.0;
      for (final entry in weekResponse) {
        final minutes = entry['minutes'];
        if (minutes != null) {
          final minutesValue = minutes is int ? minutes.toDouble() : minutes as double;
          totalHours += minutesValue / 60.0; // Convert minutes to hours
        }
      }

      // Fetch all entries this month (with date and minutes for calculations)
      final monthResponse = await supabase
          .from('workdiary')
          .select('wd_id, date, minutes')
          .eq('staff_id', widget.currentStaff.staffId)
          .gte('date', startOfMonthStr);

      // Calculate days active and average hours per day
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

      // Calculate average hours per day (only for days that have entries)
      final daysActive = uniqueDates.length;
      final avgHoursPerDay = daysActive > 0 ? totalMonthHours / daysActive : 0.0;

      if (mounted) {
        setState(() {
          _hoursLoggedThisWeek = totalHours;
          _entriesThisMonth = monthResponse.length;
          _avgHoursPerDay = avgHoursPerDay;
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

            // Content - Show static UI
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Main Content Area
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Staff Profile Card
                          _buildStaffProfileCard(),

                          SizedBox(height: 16.h),

                          // Monthly Calendar (Moved to second section)
                          _buildMonthlyCalendar(),

                          SizedBox(height: 24.h),

                          // Statistics Grid (4 cards in 2x2)
                          _buildStatisticsGrid(),

                          SizedBox(height: 20.h),
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
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 0,
        currentStaff: widget.currentStaff,
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
    final staffRole = _getStaffRole(widget.currentStaff.staffType);
    final initials = widget.currentStaff.name
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar with Initials
          Container(
            width: 48.w,
            height: 48.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2563EB),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
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
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  staffRole,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          // Staff ID Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              '#${widget.currentStaff.staffId}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
              ),
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
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          icon: Icons.schedule,
          title: 'Hours Logged',
          value: _isLoading ? '...' : _formatHours(_hoursLoggedThisWeek),
          color: const Color(0xFF2196F3),
          trend: 'This Week',
        ),
        _buildStatCard(
          icon: Icons.edit_calendar,
          title: 'Diary Entries',
          value: _isLoading ? '...' : '$_entriesThisMonth',
          color: const Color(0xFF4CAF50),
          trend: 'This Month',
        ),
        _buildStatCard(
          icon: Icons.trending_up,
          title: 'Avg Hours/Day',
          value: _isLoading ? '...' : _formatHours(_avgHoursPerDay),
          color: const Color(0xFFFF9800),
          trend: 'This Month',
        ),
        _buildStatCard(
          icon: Icons.calendar_month,
          title: 'Days Active',
          value: _isLoading ? '...' : '$_daysActive',
          color: const Color(0xFF9C27B0),
          trend: 'This Month',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 20.sp, color: color),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
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
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF080E29),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8F8E90),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
