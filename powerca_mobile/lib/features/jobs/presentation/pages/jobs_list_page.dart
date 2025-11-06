import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../../auth/domain/entities/staff.dart';
import '../bloc/jobs_bloc.dart';
import '../bloc/jobs_event.dart';
import '../bloc/jobs_state.dart';
import '../widgets/job_card.dart';
import '../widgets/status_filter_tabs.dart';

class JobsListPage extends StatelessWidget {
  final Staff currentStaff;

  const JobsListPage({
    super.key,
    required this.currentStaff,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<JobsBloc>()
        ..add(LoadJobsEvent(staffId: currentStaff.staffId)),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              _buildTopNav(context),

              // Status Filter Tabs
              BlocBuilder<JobsBloc, JobsState>(
                builder: (context, state) {
                  if (state is JobsLoaded) {
                    return StatusFilterTabs(
                      selectedStatus: state.currentStatus,
                      statusCounts: state.statusCounts,
                      onStatusChanged: (status) {
                        context.read<JobsBloc>().add(
                              ChangeStatusFilterEvent(
                                staffId: currentStaff.staffId,
                                status: status,
                              ),
                            );
                      },
                    );
                  }
                  return SizedBox(height: 48.h);
                },
              ),

              SizedBox(height: 12.h),

              // Jobs List
              Expanded(
                child: BlocBuilder<JobsBloc, JobsState>(
                  builder: (context, state) {
                    if (state is JobsLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (state is JobsError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48.sp,
                              color: AppTheme.errorColor,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Error loading jobs',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              state.message,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: AppTheme.textSecondaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 24.h),
                            ElevatedButton(
                              onPressed: () {
                                context.read<JobsBloc>().add(
                                      LoadJobsEvent(
                                        staffId: currentStaff.staffId,
                                      ),
                                    );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is JobsLoaded || state is JobsLoadingMore) {
                      final jobs = state is JobsLoaded
                          ? state.jobs
                          : (state as JobsLoadingMore).currentJobs;

                      if (jobs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work_off_outlined,
                                size: 64.sp,
                                color: AppTheme.textSecondaryColor,
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'No jobs found',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Try changing the filter',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<JobsBloc>().add(
                                RefreshJobsEvent(
                                  staffId: currentStaff.staffId,
                                  status: state is JobsLoaded
                                      ? state.currentStatus
                                      : null,
                                ),
                              );
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (scrollInfo) {
                            // Load more when reaching bottom
                            if (state is JobsLoaded &&
                                state.hasMore &&
                                scrollInfo.metrics.pixels >=
                                    scrollInfo.metrics.maxScrollExtent - 200) {
                              context.read<JobsBloc>().add(
                                    LoadMoreJobsEvent(
                                      staffId: currentStaff.staffId,
                                      status: state.currentStatus,
                                      offset: jobs.length,
                                    ),
                                  );
                            }
                            return false;
                          },
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            itemCount: jobs.length +
                                (state is JobsLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == jobs.length) {
                                // Loading indicator for pagination
                                return Padding(
                                  padding: EdgeInsets.all(16.w),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final job = jobs[index];
                              return JobCard(
                                job: job,
                                onTap: () {
                                  // Navigate to work diary
                                  Navigator.pushNamed(
                                    context,
                                    '/work-diary',
                                    arguments: job,
                                  );
                                },
                                onMenuPressed: () {
                                  _showJobMenu(context, job);
                                },
                              );
                            },
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),

              // Bottom Navigation Bar
              _buildBottomNav(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNav(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE9F0F8),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Status bar (time, signal, battery)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.signal_cellular_4_bar, size: 12.sp),
                  SizedBox(width: 4.w),
                  Text(
                    '9:41',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF263238),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.wifi, size: 13.sp),
                  SizedBox(width: 4.w),
                  Icon(Icons.battery_full, size: 13.sp),
                ],
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Menu and notification buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 9,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              Container(
                width: 40.w,
                height: 40.h,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    IconButton(
                      onPressed: () {
                        // TODO: Open notifications
                      },
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    Positioned(
                      right: 6.w,
                      top: 6.h,
                      child: Container(
                        width: 9.w,
                        height: 9.h,
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
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 74.h,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE9F0F8),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            isSelected: false,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          _buildNavItem(
            icon: Icons.list_alt,
            label: 'Job List',
            isSelected: true,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.event_note,
            label: 'Leave Req',
            isSelected: false,
            onTap: () {
              Navigator.pushNamed(
                context,
                '/leave-requests',
                arguments: currentStaff,
              );
            },
          ),
          _buildNavItem(
            icon: Icons.push_pin_outlined,
            label: 'Pinboard',
            isSelected: false,
            onTap: () {
              // TODO: Navigate to pinboard
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? AppTheme.primaryColor : const Color(0xFFA3AAB7);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  size: 24.sp,
                  color: color,
                ),
                if (isSelected)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJobMenu(BuildContext context, job) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to job details
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Job'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to edit job
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt),
              title: const Text('View Tasks'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to tasks
              },
            ),
          ],
        ),
      ),
    );
  }
}
