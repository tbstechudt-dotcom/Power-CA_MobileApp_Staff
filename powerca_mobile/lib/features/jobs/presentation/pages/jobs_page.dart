import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../auth/domain/entities/staff.dart';
import 'job_detail_page.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  // Jobs from database
  List<Map<String, dynamic>> _allJobs = [];
  bool _isLoadingJobs = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoadingJobs = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch jobs for current staff (filtered by sporg_id)
      final jobsResponse = await supabase
          .from('jobshead')
          .select('job_id, job_uid, job_status, jobdate, targetdate, work_desc, client_id')
          .eq('sporg_id', widget.currentStaff.staffId)
          .order('job_id', ascending: false);

      // Get unique client IDs
      final clientIds = jobsResponse
          .map((job) => job['client_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // Fetch client names for all client IDs
      Map<int, String> clientNames = {};
      if (clientIds.isNotEmpty) {
        final clientsResponse = await supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', clientIds);

        for (var client in clientsResponse) {
          clientNames[client['client_id'] as int] = client['clientname'] ?? 'Unknown Client';
        }
      }

      // Map job status codes to display names
      final statusMap = {
        'W': 'Waiting',
        'P': 'Progress',
        'D': 'Delivery',
        'C': 'Closer',
        'A': 'Planning',
        'G': 'Work Done',
        'L': 'Planning',
      };

      // Transform database records to UI format
      final jobs = jobsResponse.map<Map<String, dynamic>>((record) {
        final statusCode = record['job_status']?.toString().trim() ?? 'W';
        final status = statusMap[statusCode] ?? 'Waiting';
        final clientId = record['client_id'] as int?;
        final clientName = clientId != null ? (clientNames[clientId] ?? 'Unknown Client') : 'Unknown Client';

        return {
          'job_id': record['job_id'],
          'jobNo': record['job_uid'] ?? 'N/A',
          'status': status,
          'company': clientName,
          'job': record['work_desc'] ?? 'No description',
          'statusColor': _getStatusColor(status),
          'startDate': record['jobdate'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(record['jobdate']))
              : '',
          'deadline': record['targetdate'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(record['targetdate']))
              : '',
        };
      }).toList();

      setState(() {
        _allJobs = jobs;
        _isLoadingJobs = false;
      });
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      setState(() {
        _isLoadingJobs = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getJobsByStatus(String status) {
    List<Map<String, dynamic>> filtered;
    if (status == 'All') {
      filtered = _allJobs;
    } else {
      filtered = _allJobs.where((job) => job['status'] == status).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((job) {
        final jobNo = (job['jobNo'] as String).toLowerCase();
        final company = (job['company'] as String).toLowerCase();
        final jobDesc = (job['job'] as String).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return jobNo.contains(query) || company.contains(query) || jobDesc.contains(query);
      }).toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Waiting':
        return const Color(0xFFF59E0B);
      case 'Planning':
        return const Color(0xFF3B82F6);
      case 'Progress':
        return const Color(0xFF10B981);
      case 'Work Done':
        return const Color(0xFF0D9488);
      case 'Delivery':
        return const Color(0xFF8B5CF6);
      case 'Closer':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7FFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with menu handler
            AppHeader(
              currentStaff: widget.currentStaff,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            // Search/Filter Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search jobs...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    color: const Color(0xFF9CA3AF),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20.sp,
                    color: const Color(0xFF9CA3AF),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18.sp, color: const Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: const Color(0xFF6B7280),
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
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
              child: _isLoadingJobs
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _JobListView(jobs: _getJobsByStatus('All'), onRefresh: _loadJobs, currentStaff: widget.currentStaff),
                        _JobListView(jobs: _getJobsByStatus('Waiting'), onRefresh: _loadJobs, currentStaff: widget.currentStaff),
                        _JobListView(jobs: _getJobsByStatus('Planning'), onRefresh: _loadJobs, currentStaff: widget.currentStaff),
                        _JobListView(jobs: _getJobsByStatus('Progress'), onRefresh: _loadJobs, currentStaff: widget.currentStaff),
                        _JobListView(jobs: _getJobsByStatus('Work Done'), onRefresh: _loadJobs, currentStaff: widget.currentStaff),
                        _JobListView(jobs: _getJobsByStatus('Delivery'), onRefresh: _loadJobs, currentStaff: widget.currentStaff),
                        _JobListView(jobs: _getJobsByStatus('Closer'), onRefresh: _loadJobs, currentStaff: widget.currentStaff),
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
}

class _JobListView extends StatelessWidget {
  final List<Map<String, dynamic>> jobs;
  final Future<void> Function() onRefresh;
  final Staff currentStaff;

  const _JobListView({required this.jobs, required this.onRefresh, required this.currentStaff});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Waiting':
        return const Color(0xFFF59E0B);
      case 'Planning':
        return const Color(0xFF3B82F6);
      case 'Progress':
        return const Color(0xFF10B981);
      case 'Work Done':
        return const Color(0xFF0D9488);
      case 'Delivery':
        return const Color(0xFF8B5CF6);
      case 'Closer':
        return const Color(0xFF6B7280);
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
            Container(
              width: 80.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.work_outline,
                size: 40.sp,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No jobs found',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Jobs will appear here when available',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          final statusColor = _getStatusColor(job['status'] as String);
          final statusIcon = _getStatusIcon(job['status'] as String);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JobDetailPage(
                    currentStaff: currentStaff,
                    job: job,
                  ),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
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
                // Header with Job Number and Status
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.r),
                      topRight: Radius.circular(12.r),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status Icon
                      Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          statusIcon,
                          size: 18.sp,
                          color: statusColor,
                        ),
                      ),
                      SizedBox(width: 8.w),
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
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            Text(
                              job['jobNo'] as String,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          job['status'] as String,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.sp,
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
                  padding: EdgeInsets.all(10.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Name
                      Row(
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 14.sp,
                            color: const Color(0xFF6B7280),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              job['company'] as String,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),

                      // Job Description
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 14.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              job['job'] as String,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF6B7280),
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),

                      // Divider
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      SizedBox(height: 6.h),

                      // Dates Row
                      Row(
                        children: [
                          // Start Date
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14.sp,
                                  color: const Color(0xFF10B981),
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    job['startDate'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Deadline
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  size: 14.sp,
                                  color: const Color(0xFFEF4444),
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    job['deadline'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFEF4444),
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
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}
