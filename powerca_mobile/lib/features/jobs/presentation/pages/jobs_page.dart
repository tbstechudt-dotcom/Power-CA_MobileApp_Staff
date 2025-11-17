import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../auth/domain/entities/staff.dart';

class JobsPage extends StatefulWidget {
  final Staff currentStaff;

  const JobsPage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filterTabs = [
    'All',
    'Waiting',
    'Planning',
    'Progress',
    'Work Done',
  ];

  // Mock job data - replace with real data from API
  final List<Map<String, dynamic>> _mockJobs = [
    {
      'jobNo': 'REG53677',
      'status': 'Waiting',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
    {
      'jobNo': 'REG23659',
      'status': 'Planning',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
    {
      'jobNo': 'REG45654',
      'status': 'Planning',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
    {
      'jobNo': 'REG82574',
      'status': 'Progress',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
    {
      'jobNo': 'REG23947',
      'status': 'Work Done',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
    {
      'jobNo': 'REG23659',
      'status': 'Delivery',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
    {
      'jobNo': 'REG34165',
      'status': 'Delivery',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
    {
      'jobNo': 'REG98765',
      'status': 'Closer',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFF6B7FFF),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Menu and Notification
            _buildTopAppBar(context),

            // Filter Tabs
            _buildFilterTabs(),

            // Job List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                itemCount: _mockJobs.length,
                itemBuilder: (context, index) {
                  return _buildJobCard(_mockJobs[index]);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 1,
        currentStaff: widget.currentStaff,
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context) {
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
                widget.currentStaff.name.substring(0, 1).toUpperCase(),
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
                  widget.currentStaff.name.split(' ').first,
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

  Widget _buildFilterTabs() {
    return Container(
      height: 50.h,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _filterTabs.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilterIndex = index;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 16.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _filterTabs[index],
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFF080E29)
                          : const Color(0xFF8F8E90),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  if (isSelected)
                    Container(
                      width: 40.w,
                      height: 3.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2255FC),
                        borderRadius: BorderRadius.circular(1.5.r),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
          // Job Number, Status, and Menu
          Row(
            children: [
              // Lightning Icon + Job Number
              Icon(
                Icons.flash_on,
                size: 20.sp,
                color: const Color(0xFF080E29),
              ),
              SizedBox(width: 4.w),
              Text(
                'Job.No : ',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF080E29),
                ),
              ),
              Text(
                job['jobNo'],
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2255FC),
                ),
              ),
              const Spacer(),
              // Status Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: (job['statusColor'] as Color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  job['status'],
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: job['statusColor'],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Three Dot Menu
              Icon(
                Icons.more_vert,
                size: 20.sp,
                color: const Color(0xFF8F8E90),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Company Name
          Text(
            job['company'],
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF080E29),
            ),
          ),
          SizedBox(height: 4.h),
          // Job Description
          Row(
            children: [
              Text(
                'Job : ',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8F8E90),
                ),
              ),
              Text(
                job['job'],
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
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
