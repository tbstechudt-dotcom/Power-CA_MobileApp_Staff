import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../core/services/priority_service.dart';
import '../../../auth/domain/entities/staff.dart';
import 'jobs_filtered_page.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Jobs from database
  List<Map<String, dynamic>> _allJobs = [];
  bool _isLoadingJobs = false;

  // Priority jobs
  Set<int> _priorityJobIds = {};
  int _priorityCount = 0;

  // Status configurations
  final List<Map<String, dynamic>> _statusConfigs = [
    {
      'status': 'Waiting',
      'icon': Icons.hourglass_empty_rounded,
      'color': const Color(0xFFF59E0B),
      'gradient': [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
    },
    {
      'status': 'Planning',
      'icon': Icons.architecture_rounded,
      'color': const Color(0xFF3B82F6),
      'gradient': [const Color(0xFF60A5FA), const Color(0xFF3B82F6)],
    },
    {
      'status': 'Progress',
      'icon': Icons.rocket_launch_rounded,
      'color': const Color(0xFF10B981),
      'gradient': [const Color(0xFF34D399), const Color(0xFF10B981)],
    },
    {
      'status': 'Work Done',
      'icon': Icons.task_alt_rounded,
      'color': const Color(0xFF0D9488),
      'gradient': [const Color(0xFF2DD4BF), const Color(0xFF0D9488)],
    },
    {
      'status': 'Delivery',
      'icon': Icons.local_shipping_rounded,
      'color': const Color(0xFF8B5CF6),
      'gradient': [const Color(0xFFA78BFA), const Color(0xFF8B5CF6)],
    },
    // Removed 'Closer' status - not displayed on jobs page
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _loadPriorityJobs();
  }

  Future<void> _loadPriorityJobs() async {
    final jobIds = await PriorityService.getPriorityJobIds();
    if (mounted) {
      setState(() {
        _priorityJobIds = jobIds;
        _priorityCount = jobIds.length;
      });
    }
  }

  // Get priority jobs from all jobs
  List<Map<String, dynamic>> _getPriorityJobs() {
    return _allJobs.where((job) => _priorityJobIds.contains(job['job_id'] as int)).toList();
  }

  Future<void> _loadJobs() async {
    if (!mounted) return;
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

      if (!mounted) return;
      setState(() {
        _allJobs = jobs;
        _isLoadingJobs = false;
      });
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingJobs = false;
      });
    }
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

  // Get jobs excluding 'Closer' status
  List<Map<String, dynamic>> get _activeJobs {
    return _allJobs.where((job) => job['status'] != 'Closer').toList();
  }

  int _getJobCountByStatus(String status) {
    return _allJobs.where((job) => job['status'] == status).length;
  }

  List<Map<String, dynamic>> _getJobsByStatus(String status) {
    return _allJobs.where((job) => job['status'] == status).toList();
  }

  void _navigateToFilteredJobs(String status) {
    final jobs = _getJobsByStatus(status);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobsFilteredPage(
          currentStaff: widget.currentStaff,
          statusFilter: status,
          jobs: jobs,
        ),
      ),
    ).then((_) {
      // Reload priority jobs when returning from filtered page
      _loadPriorityJobs();
    });
  }

  void _navigateToPriorityJobs() {
    final jobs = _getPriorityJobs();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobsFilteredPage(
          currentStaff: widget.currentStaff,
          statusFilter: 'Priority',
          jobs: jobs,
        ),
      ),
    ).then((_) {
      // Reload priority jobs when returning
      _loadPriorityJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with menu handler
            AppHeader(
              currentStaff: widget.currentStaff,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            // Content
            Expanded(
              child: _isLoadingJobs
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadJobs,
                      color: AppTheme.primaryColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Page Title
                            Text(
                              'My Jobs',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Track and manage your work',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            SizedBox(height: 20.h),

                            // Summary Cards Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Total',
                                    count: _activeJobs.length,
                                    icon: Icons.work_rounded,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _buildSummaryCard(
                                    title: 'Active',
                                    count: _getJobCountByStatus('Progress') + _getJobCountByStatus('Planning'),
                                    icon: Icons.pending_actions_rounded,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),

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
                            SizedBox(height: 12.h),

                            // Priority Status Item (at top)
                            _buildStatusListItem(
                              status: 'Priority',
                              icon: Icons.star_rounded,
                              gradient: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                              count: _priorityCount,
                              onTap: () => _navigateToPriorityJobs(),
                            ),

                            // Status List
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _statusConfigs.length,
                              itemBuilder: (context, index) {
                                final config = _statusConfigs[index];
                                final status = config['status'] as String;
                                final icon = config['icon'] as IconData;
                                final gradient = config['gradient'] as List<Color>;
                                final count = _getJobCountByStatus(status);

                                return _buildStatusListItem(
                                  status: status,
                                  icon: icon,
                                  gradient: gradient,
                                  count: count,
                                  onTap: () => _navigateToFilteredJobs(status),
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
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 1,
        currentStaff: widget.currentStaff,
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
            '$title Jobs',
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
                          'Tap to view jobs',
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
