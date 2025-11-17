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

class _JobsPageState extends State<JobsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock job data - replace with real data from API
  final List<Map<String, dynamic>> _allJobs = [
    {
      'jobNo': 'REG53677',
      'status': 'Waiting',
      'company': 'Umbrella Corporation Private Limited',
      'job': 'Audit Planning',
      'statusColor': const Color(0xFFFFA726),
      'startDate': '2025-01-15',
      'deadline': '2025-02-28',
    },
    {
      'jobNo': 'REG23659',
      'status': 'Planning',
      'company': 'Tech Solutions Inc.',
      'job': 'Financial Review',
      'statusColor': const Color(0xFF42A5F5),
      'startDate': '2025-01-10',
      'deadline': '2025-03-15',
    },
    {
      'jobNo': 'REG45654',
      'status': 'Planning',
      'company': 'Global Industries Ltd.',
      'job': 'Tax Compliance',
      'statusColor': const Color(0xFF42A5F5),
      'startDate': '2025-01-20',
      'deadline': '2025-04-01',
    },
    {
      'jobNo': 'REG82574',
      'status': 'Progress',
      'company': 'Innovative Systems Corp.',
      'job': 'Annual Audit',
      'statusColor': const Color(0xFF66BB6A),
      'startDate': '2025-01-05',
      'deadline': '2025-02-20',
    },
    {
      'jobNo': 'REG23947',
      'status': 'Work Done',
      'company': 'Digital Enterprises LLC',
      'job': 'Quarterly Review',
      'statusColor': const Color(0xFF26A69A),
      'startDate': '2024-12-01',
      'deadline': '2025-01-15',
    },
    {
      'jobNo': 'REG23660',
      'status': 'Delivery',
      'company': 'Prime Corporation',
      'job': 'Compliance Audit',
      'statusColor': const Color(0xFF9C27B0),
      'startDate': '2024-11-15',
      'deadline': '2025-01-10',
    },
    {
      'jobNo': 'REG34165',
      'status': 'Delivery',
      'company': 'Strategic Partners Inc.',
      'job': 'Risk Assessment',
      'statusColor': const Color(0xFF9C27B0),
      'startDate': '2024-12-20',
      'deadline': '2025-01-25',
    },
    {
      'jobNo': 'REG98765',
      'status': 'Closer',
      'company': 'Fortune Enterprises',
      'job': 'Year-End Audit',
      'statusColor': const Color(0xFF78909C),
      'startDate': '2024-10-01',
      'deadline': '2024-12-31',
    },
    {
      'jobNo': 'REG11223',
      'status': 'Closer',
      'company': 'Mega Solutions Group',
      'job': 'Financial Statement Review',
      'statusColor': const Color(0xFF78909C),
      'startDate': '2024-11-01',
      'deadline': '2024-12-15',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getJobsByStatus(String status) {
    if (status == 'All') {
      return _allJobs;
    }
    return _allJobs.where((job) => job['status'] == status).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Waiting':
        return const Color(0xFFFFA726);
      case 'Planning':
        return const Color(0xFF42A5F5);
      case 'Progress':
        return const Color(0xFF66BB6A);
      case 'Work Done':
        return const Color(0xFF26A69A);
      case 'Delivery':
        return const Color(0xFF9C27B0);
      case 'Closer':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFF6B7FFF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Waiting':
        return Icons.schedule;
      case 'Planning':
        return Icons.edit_calendar;
      case 'Progress':
        return Icons.trending_up;
      case 'Work Done':
        return Icons.check_circle_outline;
      case 'Delivery':
        return Icons.local_shipping_outlined;
      case 'Closer':
        return Icons.done_all;
      default:
        return Icons.work_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(context),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: const Color(0xFF8F8E90),
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                labelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Waiting'),
                  Tab(text: 'Planning'),
                  Tab(text: 'Progress'),
                  Tab(text: 'Work Done'),
                  Tab(text: 'Delivery'),
                  Tab(text: 'Closer'),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _JobListView(jobs: _getJobsByStatus('All')),
                  _JobListView(jobs: _getJobsByStatus('Waiting')),
                  _JobListView(jobs: _getJobsByStatus('Planning')),
                  _JobListView(jobs: _getJobsByStatus('Progress')),
                  _JobListView(jobs: _getJobsByStatus('Work Done')),
                  _JobListView(jobs: _getJobsByStatus('Delivery')),
                  _JobListView(jobs: _getJobsByStatus('Closer')),
                ],
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
}

class _JobListView extends StatelessWidget {
  final List<Map<String, dynamic>> jobs;

  const _JobListView({required this.jobs});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Waiting':
        return const Color(0xFFFFA726);
      case 'Planning':
        return const Color(0xFF42A5F5);
      case 'Progress':
        return const Color(0xFF66BB6A);
      case 'Work Done':
        return const Color(0xFF26A69A);
      case 'Delivery':
        return const Color(0xFF9C27B0);
      case 'Closer':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFF6B7FFF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Waiting':
        return Icons.schedule;
      case 'Planning':
        return Icons.edit_calendar;
      case 'Progress':
        return Icons.trending_up;
      case 'Work Done':
        return Icons.check_circle_outline;
      case 'Delivery':
        return Icons.local_shipping_outlined;
      case 'Closer':
        return Icons.done_all;
      default:
        return Icons.work_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              'No jobs found',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final statusColor = _getStatusColor(job['status'] as String);
        final statusIcon = _getStatusIcon(job['status'] as String);

        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                  ),
                ),
                child: Row(
                  children: [
                    // Status Icon
                    Container(
                      width: 36.w,
                      height: 36.h,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        statusIcon,
                        size: 20.sp,
                        color: statusColor,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Job Number
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job No.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8F8E90),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            job['jobNo'] as String,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        job['status'] as String,
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
              ),

              // Content Section
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Name
                    Row(
                      children: [
                        Icon(
                          Icons.business,
                          size: 16.sp,
                          color: const Color(0xFF8F8E90),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            job['company'] as String,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF080E29),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Job Description
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16.sp,
                          color: const Color(0xFF8F8E90),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            job['job'] as String,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8F8E90),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Dates Row
                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 14.sp,
                                color: const Color(0xFF8F8E90),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF8F8E90),
                                      ),
                                    ),
                                    Text(
                                      job['startDate'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF080E29),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Deadline
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                size: 14.sp,
                                color: const Color(0xFFEF1E05),
                              ),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Deadline',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF8F8E90),
                                      ),
                                    ),
                                    Text(
                                      job['deadline'] as String,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEF1E05),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
