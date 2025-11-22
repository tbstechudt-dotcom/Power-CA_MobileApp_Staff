import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../core/services/priority_service.dart';
import '../../../auth/domain/entities/staff.dart';
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
  bool _isSelectionMode = false;
  Set<int> _selectedJobIds = {};

  @override
  void initState() {
    super.initState();
    _loadPriorityJobs();
  }

  Future<void> _loadPriorityJobs() async {
    final jobIds = await PriorityService.getPriorityJobIds();
    if (mounted) {
      setState(() {
        _priorityJobIds = jobIds;
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedJobIds.clear();
      }
    });
  }

  void _toggleJobSelection(int jobId) {
    // Don't allow selecting jobs that are already priorities
    if (_priorityJobIds.contains(jobId)) {
      return;
    }

    setState(() {
      if (_selectedJobIds.contains(jobId)) {
        _selectedJobIds.remove(jobId);
      } else {
        _selectedJobIds.add(jobId);
      }
    });
  }

  Future<void> _confirmPrioritySelection() async {
    // Add all selected jobs to priority
    for (int jobId in _selectedJobIds) {
      if (!_priorityJobIds.contains(jobId)) {
        await PriorityService.addPriorityJob(jobId);
      }
    }

    // Exit selection mode and go back to jobs page
    if (mounted) {
      Navigator.pop(context);
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
      case 'Closer':
        return const Color(0xFF6B7280);
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
      case 'Closer':
        return Icons.done_all;
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
    final statusColor = _getStatusColor(widget.statusFilter);
    final statusIcon = _getStatusIcon(widget.statusFilter);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header with Back Button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 18.sp,
                        color: const Color(0xFF374151),
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
                          _isSelectionMode ? 'Select Priority' : widget.statusFilter,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          _isSelectionMode
                              ? '${_selectedJobIds.length} selected'
                              : '${widget.jobs.length} jobs',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: _isSelectionMode
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Menu button to enable selection mode (hide on Priority page)
                  if (!_isPriorityPage)
                    GestureDetector(
                      onTap: _toggleSelectionMode,
                      child: Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: _isSelectionMode
                              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          _isSelectionMode ? Icons.close : Icons.checklist_rounded,
                          size: 20.sp,
                          color: _isSelectionMode
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF374151),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Search Bar
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
                    fontFamily: 'Inter',
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
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),

            // Jobs List
            Expanded(
              child: _filteredJobs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      itemCount: _filteredJobs.length,
                      itemBuilder: (context, index) {
                        final job = _filteredJobs[index];
                        return _buildJobCard(job);
                      },
                    ),
            ),

            // Bottom confirm button when in selection mode with items selected
            if (_isSelectionMode && _selectedJobIds.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: GestureDetector(
                    onTap: _confirmPrioritySelection,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 20.sp,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Set ${_selectedJobIds.length} as Priority',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: (_isSelectionMode && _selectedJobIds.isNotEmpty)
          ? null
          : ModernBottomNavigation(
              currentIndex: 1,
              currentStaff: widget.currentStaff,
            ),
    );
  }

  Widget _buildEmptyState() {
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
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'No ${widget.statusFilter.toLowerCase()} jobs available',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final statusColor = _getStatusColor(job['status'] as String);
    final statusIcon = _getStatusIcon(job['status'] as String);
    final jobId = job['job_id'] as int;
    final isPriority = _priorityJobIds.contains(jobId);
    final isSelected = _selectedJobIds.contains(jobId);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleJobSelection(jobId);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailPage(
                currentStaff: widget.currentStaff,
                job: job,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: (isPriority || isSelected)
              ? Border.all(
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  width: 2
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : isPriority
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.04),
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
                  topLeft: Radius.circular((isPriority || isSelected) ? 10.r : 12.r),
                  topRight: Radius.circular((isPriority || isSelected) ? 10.r : 12.r),
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
                            color: const Color(0xFF6B7280),
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
                  // Status Badge or Checkbox
                  if (_isSelectionMode)
                    Container(
                      width: 22.w,
                      height: 22.h,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : isPriority
                                ? const Color(0xFFEF4444)  // Already priority - show red
                                : Colors.white,
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : isPriority
                                  ? const Color(0xFFEF4444)  // Already priority
                                  : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 14.sp,
                              color: Colors.white,
                            )
                          : isPriority
                              ? Icon(
                                  Icons.star,  // Show star icon for already priority
                                  size: 12.sp,
                                  color: Colors.white,
                                )
                              : null,
                    )
                  else
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
                            fontFamily: 'Inter',
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
                            fontFamily: 'Inter',
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
                                  fontFamily: 'Inter',
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

                  // Remove from Priority button (only on Priority page)
                  if (_isPriorityPage) ...[
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: () => _removeFromPriority(jobId),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 8.h),
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
                              size: 16.sp,
                              color: const Color(0xFFDC2626),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Remove from Priority',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFDC2626),
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
          ],
        ),
      ),
    );
  }
}
