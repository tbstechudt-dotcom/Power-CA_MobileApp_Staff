import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../core/services/priority_service.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../../home/presentation/pages/work_log_entry_form_page.dart';
import 'job_detail_page.dart';

class JobsFilteredPage extends StatefulWidget {
  final Staff currentStaff;
  final String statusFilter;
  final List<Map<String, dynamic>> jobs;

  const JobsFilteredPage({
    super.key,
    required this.currentStaff,
    required this.statusFilter,
    required this.jobs,
  });

  @override
  State<JobsFilteredPage> createState() => _JobsFilteredPageState();
}

class _JobsFilteredPageState extends State<JobsFilteredPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<int> _priorityJobIds = {};

  @override
  void initState() {
    super.initState();
    _loadPriorityJobs();
  }

  /// Update status bar style based on theme
  void _updateStatusBarStyle(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Future<void> _loadPriorityJobs() async {
    final jobIds = await PriorityService.getPriorityJobIds();
    if (mounted) {
      setState(() {
        _priorityJobIds = jobIds;
      });
    }
  }

  Future<void> _removeFromPriority(int jobId) async {
    await PriorityService.removePriorityJob(jobId);
    if (mounted) {
      setState(() {
        _priorityJobIds.remove(jobId);
        // Also remove from the jobs list for Priority page
        widget.jobs.removeWhere((job) => job['job_id'] == jobId);
      });
    }
  }

  // Check if this is the Priority page
  bool get _isPriorityPage => widget.statusFilter == 'Priority';

  Future<void> _togglePriority(int jobId) async {
    final isPriority = await PriorityService.togglePriorityJob(jobId);
    if (mounted) {
      setState(() {
        if (isPriority) {
          _priorityJobIds.add(jobId);
        } else {
          _priorityJobIds.remove(jobId);
        }
      });
    }
  }

  List<Map<String, dynamic>> get _filteredJobs {
    List<Map<String, dynamic>> filtered = widget.jobs;

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
      case 'Priority':
        return const Color(0xFFEF4444);
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
      default:
        return const Color(0xFF6B7FFF);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Priority':
        return Icons.star_rounded;
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
      default:
        return Icons.work_outline;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;
    final backButtonBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backButtonBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final searchFillColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC);
    final listBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);

    // Update status bar style based on theme
    _updateStatusBarStyle(isDarkMode);

    final statusColor = _getStatusColor(widget.statusFilter);
    final statusIcon = _getStatusIcon(widget.statusFilter);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBgColor,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: Column(
        children: [
          // Custom Header with Back Button - extends into status bar area
          Container(
            padding: EdgeInsets.only(
              left: 16.w,
              right: 16.w,
              top: MediaQuery.of(context).padding.top + 12.h,
              bottom: 12.h,
            ),
              decoration: BoxDecoration(
                color: headerBgColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back Button - styled like hamburger menu button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42.w,
                      height: 42.h,
                      decoration: BoxDecoration(
                        color: backButtonBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: backButtonBorderColor,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 18.sp,
                          color: textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Status Icon and Title
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      statusIcon,
                      size: 20.sp,
                      color: statusColor,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.statusFilter,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: textPrimaryColor,
                          ),
                        ),
                        Text(
                          '${widget.jobs.length} jobs',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              color: headerBgColor,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by job no, client, description...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    color: textSecondaryColor,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20.sp,
                    color: textSecondaryColor,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18.sp, color: textSecondaryColor),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: searchFillColor,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  color: textPrimaryColor,
                ),
              ),
            ),

            // Jobs List
            Expanded(
              child: Container(
                color: listBgColor,
                child: _filteredJobs.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        itemCount: _filteredJobs.length,
                        itemBuilder: (context, index) {
                          final job = _filteredJobs[index];
                          return _buildJobCard(job, context);
                        },
                      ),
              ),
            ),
          ],
        ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 1,
        currentStaff: widget.currentStaff,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final emptyStateBgColor = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8F9FC);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: emptyStateBgColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              Icons.work_outline,
              size: 40.sp,
              color: textSecondaryColor,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No jobs found',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textSecondaryColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'No ${widget.statusFilter.toLowerCase()} jobs available',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

    final statusColor = _getStatusColor(job['status'] as String);
    final statusIcon = _getStatusIcon(job['status'] as String);
    final jobId = job['job_id'] as int;
    final isPriority = _priorityJobIds.contains(jobId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailPage(
              currentStaff: widget.currentStaff,
              job: job,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isPriority
                ? const Color(0xFFEF4444)
                : borderColor,
            width: isPriority ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPriority
                  ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.08),
              blurRadius: 10,
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
                  topLeft: Radius.circular(isPriority ? 10.r : 11.r),
                  topRight: Radius.circular(isPriority ? 10.r : 11.r),
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
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: textSecondaryColor,
                          ),
                        ),
                        Text(
                          job['jobNo'] as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
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
                        fontFamily: 'Inter',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Quick Priority Toggle Button (one-click star) - positioned after status badge
                  if (!_isPriorityPage) ...[
                    SizedBox(width: 8.w),
                    GestureDetector(
                      onTap: () => _togglePriority(jobId),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: isPriority
                              ? const Color(0xFFFEE2E2)
                              : (isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC)),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: isPriority
                                ? const Color(0xFFEF4444)
                                : borderColor,
                            width: 1.5,
                          ),
                          boxShadow: isPriority
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPriority ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 16.sp,
                              color: isPriority
                                  ? const Color(0xFFEF4444)
                                  : textSecondaryColor,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              isPriority ? 'Priority' : 'Set Priority',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: isPriority
                                    ? const Color(0xFFEF4444)
                                    : textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                        color: textSecondaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          job['company'] as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: textPrimaryColor,
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
                        color: textSecondaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          job['job'] as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: textSecondaryColor,
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
                  Divider(height: 1, color: dividerColor),
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
                                  fontFamily: 'Inter',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondaryColor,
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
                                  fontFamily: 'Inter',
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

                  // Action buttons row
                  SizedBox(height: 8.h),
                  if (_isPriorityPage)
                    // Priority page: Both buttons in a row (Remove Priority left, Daily Entry right)
                    Row(
                      children: [
                        // Remove from Priority button (left)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _removeFromPriority(jobId),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: const Color(0xFFFCA5A5),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.remove_circle_outline,
                                    size: 14.sp,
                                    color: const Color(0xFFDC2626),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Remove',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Select for Daily Entry button (right)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkLogEntryFormPage(
                                    selectedDate: DateTime.now(),
                                    staffId: widget.currentStaff.staffId,
                                    preSelectedJobId: job['job_id'] as int,
                                    preSelectedClientId: job['client_id'] as int?,
                                    preSelectedJobName: job['job'] as String?,
                                    preSelectedClientName: job['company'] as String?,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 14.sp,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Daily Entry',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // Other pages: Only Daily Entry button (full width)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkLogEntryFormPage(
                              selectedDate: DateTime.now(),
                              staffId: widget.currentStaff.staffId,
                              preSelectedJobId: job['job_id'] as int,
                              preSelectedClientId: job['client_id'] as int?,
                              preSelectedJobName: job['job'] as String?,
                              preSelectedClientName: job['company'] as String?,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_calendar_outlined,
                              size: 16.sp,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Select for Daily Entry',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
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
