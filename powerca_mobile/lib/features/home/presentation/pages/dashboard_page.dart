import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../auth/domain/entities/staff.dart';
import '../widgets/modern_work_calendar.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';

/// Dashboard page - Static version for development/testing
class DashboardPage extends StatelessWidget {
  final Staff currentStaff;

  const DashboardPage({
    super.key,
    required this.currentStaff,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Top App Bar
            _buildModernAppBar(context),

            // Content - Show static UI
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Hero Section with Stats
                    _buildHeroSection(),

                    // Main Content Area
                    Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Monthly Calendar (Moved to second section)
                          _buildMonthlyCalendar(),

                          SizedBox(height: 24.h),

                          // Statistics Grid (4 cards in 2x2)
                          _buildStatisticsGrid(),

                          SizedBox(height: 24.h),

                          // Today's Overview Section
                          _buildTodayOverview(),

                          SizedBox(height: 24.h),

                          // Recent Activities Timeline
                          _buildActivitiesTimeline(),

                          SizedBox(height: 24.h),

                          // Quick Access Actions Grid
                          _buildQuickAccessGrid(context),

                          SizedBox(height: 24.h),

                          // Performance Summary Card
                          _buildPerformanceSummary(),

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
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 0,
        currentStaff: currentStaff,
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
          children: [
            // Profile Avatar
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0846B1), Color(0xFF2255FC)],
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0846B1).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  currentStaff.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Name and role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentStaff.name.split(' ').first,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF080E29),
                    ),
                  ),
                  Text(
                    'Staff Member',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8F8E90),
                    ),
                  ),
                ],
              ),
            ),
            // Notifications
            Container(
              width: 40.w,
              height: 40.h,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 20.sp,
                      color: const Color(0xFF080E29),
                    ),
                  ),
                  Positioned(
                    right: 10.w,
                    top: 10.h,
                    child: Container(
                      width: 8.w,
                      height: 8.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF1E05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    IconData greetingIcon = Icons.wb_sunny;

    if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_cloudy;
    } else if (hour >= 17) {
      greeting = 'Good Evening';
      greetingIcon = Icons.nights_stay;
    }

    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0846B1), Color(0xFF2255FC)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0846B1).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(greetingIcon, size: 20.sp, color: Colors.white70),
                        SizedBox(width: 8.w),
                        Text(
                          greeting,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      currentStaff.name,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Let\'s make today productive!',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '64h',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Hours Logged',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '12',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Entries',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
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
    );
  }

  Widget _buildMonthlyCalendar() {
    // Use the new ModernWorkCalendar widget with flutter_calendar_carousel
    return ModernWorkCalendar(
      staffId: currentStaff.staffId,
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16.h,
      crossAxisSpacing: 16.w,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          icon: Icons.schedule,
          title: 'Hours Logged',
          value: '64h',
          color: const Color(0xFF2196F3),
          trend: 'This Week',
        ),
        _buildStatCard(
          icon: Icons.edit_calendar,
          title: 'Diary Entries',
          value: '12',
          color: const Color(0xFF4CAF50),
          trend: 'This Month',
        ),
        _buildStatCard(
          icon: Icons.trending_up,
          title: 'Avg Hours/Day',
          value: '7.5h',
          color: const Color(0xFFFF9800),
          trend: '+0.5h',
        ),
        _buildStatCard(
          icon: Icons.calendar_month,
          title: 'Days Active',
          value: '18',
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 20.sp, color: color),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontFamily: 'Poppins',
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
                  fontFamily: 'Poppins',
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF080E29),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
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

  Widget _buildTodayOverview() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Overview',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF080E29),
                ),
              ),
              Text(
                DateFormat('EEE, MMM d').format(DateTime.now()),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8F8E90),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildOverviewItem(
            icon: Icons.access_time,
            title: 'Hours Logged Today',
            value: '6.5 hrs',
            color: const Color(0xFF4CAF50),
          ),
          SizedBox(height: 12.h),
          _buildOverviewItem(
            icon: Icons.edit_note,
            title: 'Diary Entries',
            value: '3 entries',
            color: const Color(0xFF2196F3),
          ),
          SizedBox(height: 12.h),
          _buildOverviewItem(
            icon: Icons.trending_up,
            title: 'Week Progress',
            value: '80% complete',
            color: const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 18.sp, color: color),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF080E29),
          ),
        ),
      ],
    );
  }

  Widget _buildActivitiesTimeline() {
    final activities = [
      {'icon': Icons.edit_calendar, 'title': 'Work entry added', 'subtitle': 'Logged 4.5 hours', 'time': '2h ago', 'color': const Color(0xFF4CAF50)},
      {'icon': Icons.access_time, 'title': 'Work logged', 'subtitle': 'Updated diary entry', 'time': '3h ago', 'color': const Color(0xFFFF9800)},
      {'icon': Icons.schedule, 'title': 'Time tracked', 'subtitle': '8 hours completed', 'time': '1d ago', 'color': const Color(0xFF2196F3)},
      {'icon': Icons.calendar_today, 'title': 'Weekly summary', 'subtitle': '38.5 hours total', 'time': '2d ago', 'color': const Color(0xFF9C27B0)},
    ];

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF080E29),
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                ),
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...activities.map((activity) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: (activity['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      size: 18.sp,
                      color: activity['color'] as Color,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'] as String,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF080E29),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          activity['subtitle'] as String,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF8F8E90),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity['time'] as String,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFA8A8A8),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF080E29),
          ),
        ),
        SizedBox(height: 16.h),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
          childAspectRatio: 1.8,
          children: [
            _buildQuickAccessCard(
              icon: Icons.add,
              title: 'New Entry',
              color: const Color(0xFF2196F3),
              onTap: () {},
            ),
            _buildQuickAccessCard(
              icon: Icons.access_time_filled,
              title: 'Log Hours',
              color: const Color(0xFF4CAF50),
              onTap: () {},
            ),
            _buildQuickAccessCard(
              icon: Icons.calendar_month,
              title: 'View Calendar',
              color: const Color(0xFFFF9800),
              onTap: () {},
            ),
            _buildQuickAccessCard(
              icon: Icons.bar_chart,
              title: 'Time Stats',
              color: const Color(0xFF9C27B0),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, size: 18.sp, color: Colors.white),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF080E29),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F7FA), Color(0xFFE8EDF5)],
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Month\'s Performance',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF080E29),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'Great!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completion Rate',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF8F8E90),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '75%',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF080E29),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80.w,
                height: 80.h,
                child: const CircularProgressIndicator(
                  value: 0.75,
                  strokeWidth: 8,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
