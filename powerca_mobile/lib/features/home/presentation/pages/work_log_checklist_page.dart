import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';

/// Page to display and manage checklist items for a staff member's tasks
class WorkLogChecklistPage extends StatefulWidget {
  final int staffId;
  final int jobId;
  final DateTime selectedDate;

  const WorkLogChecklistPage({
    super.key,
    required this.staffId,
    required this.jobId,
    required this.selectedDate,
  });

  @override
  State<WorkLogChecklistPage> createState() => _WorkLogChecklistPageState();
}

class _WorkLogChecklistPageState extends State<WorkLogChecklistPage> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Track checked state locally
  final Map<int, bool> _checkedTasks = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      if (widget.jobId <= 0) {
        setState(() {
          _tasks = [];
          _isLoading = false;
        });
        return;
      }

      debugPrint('Loading taskchecklist for job_id: ${widget.jobId}');

      // Query taskchecklist directly by job_id (new column added to table)
      final checklistResponse = await supabase
          .from('taskchecklist')
          .select('tc_id, task_id, job_id, checklistdesc, checkliststatus, completedby, completeddate, comments')
          .eq('job_id', widget.jobId)
          .order('task_id', ascending: true);

      debugPrint('Found ${checklistResponse.length} taskchecklist items for job_id: ${widget.jobId}');

      // Transform checklist items and remove duplicates by checklistdesc only
      final seenDescriptions = <String>{};
      final tasks = <Map<String, dynamic>>[];

      for (final item in checklistResponse) {
        final tcId = item['tc_id'] as int;
        final checklistDesc = item['checklistdesc']?.toString().trim() ?? '';

        // Skip if we've already seen this description (remove duplicates)
        if (seenDescriptions.contains(checklistDesc)) {
          continue;
        }
        seenDescriptions.add(checklistDesc);

        // Initialize checked state based on checkliststatus (numeric: 0=pending, 1=completed)
        final checklistStatus = item['checkliststatus'];
        _checkedTasks[tcId] = checklistStatus == 1 || checklistStatus == '1';

        tasks.add({
          'jt_id': tcId, // Using tc_id as the identifier
          'job_id': widget.jobId,
          'task_id': item['task_id'],
          'taskname': item['checklistdesc'] ?? 'Unnamed Checklist Item',
          'createddate': item['completeddate'] != null ? DateTime.parse(item['completeddate']) : null,
          'status': checklistStatus == 1 || checklistStatus == '1' ? 'Completed' : 'Pending',
          'totalhours': 0,
          'completedby': item['completedby'] ?? '',
          'comments': item['comments'] ?? '',
        });
      }

      debugPrint('After removing duplicates: ${tasks.length} unique checklist items');

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      setState(() {
        _errorMessage = 'Failed to load tasks: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _toggleTask(int jtId) {
    setState(() {
      _checkedTasks[jtId] = !(_checkedTasks[jtId] ?? false);
    });
  }

  Future<void> _saveChecklist() async {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final dialogBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);

    // Show saving indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: dialogBgColor,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: 16.h),
              Text(
                'Saving...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final supabase = Supabase.instance.client;

      // Update checklist statuses in database (checkliststatus: 0=pending, 1=completed)
      for (final task in _tasks) {
        final tcId = task['jt_id'] as int; // tc_id stored in jt_id field
        final isChecked = _checkedTasks[tcId] ?? false;
        final newStatus = isChecked ? 1 : 0;

        await supabase
            .from('taskchecklist')
            .update({'checkliststatus': newStatus})
            .eq('tc_id', tcId);
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Checklist saved successfully'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Column(
        children: [
          // Custom header
          _buildHeader(context),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64.sp,
                              color: Colors.red,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.sp,
                                color: textSecondaryColor,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            ElevatedButton.icon(
                              onPressed: _loadTasks,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _tasks.isEmpty
                        ? _buildEmptyState(context)
                        : _buildTaskList(context),
          ),
          // Bottom save button
          if (_tasks.isNotEmpty)
            SafeArea(
              top: false,
              child: _buildBottomSaveButton(context),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final backButtonBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backButtonBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        MediaQuery.of(context).padding.top + 12.h,
        16.w,
        16.h,
      ),
      color: headerBgColor,
      child: Row(
        children: [
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
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Checklist',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Job #${widget.jobId}',
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
    );
  }

  Widget _buildBottomSaveButton(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final containerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: containerBgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _saveChecklist,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.save_rounded,
                  size: 20.sp,
                  color: Colors.white,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Save Checklist',
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final iconColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFE5E7EB);
    final textPrimaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final textSecondaryColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_outlined,
            size: 80.sp,
            color: iconColor,
          ),
          SizedBox(height: 16.h),
          Text(
            'No tasks found',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'No tasks assigned to you for this job',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final sectionTitleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF334155);
    final progressBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // Count completed tasks
    final completedCount = _checkedTasks.values.where((v) => v).length;
    final totalCount = _tasks.length;
    final progressPercent = totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: isDarkMode ? 0.15 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.checklist_rounded,
                              size: 20.sp,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimaryColor,
                                ),
                              ),
                              Text(
                                '$completedCount of $totalCount tasks',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: completedCount == totalCount
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '$progressPercent%',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: completedCount == totalCount
                                ? const Color(0xFF10B981)
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: LinearProgressIndicator(
                      value: totalCount > 0 ? completedCount / totalCount : 0,
                      backgroundColor: progressBgColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completedCount == totalCount
                            ? const Color(0xFF10B981)
                            : AppTheme.primaryColor,
                      ),
                      minHeight: 6.h,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Section title
            Text(
              'Checklist Items',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: sectionTitleColor,
              ),
            ),
            SizedBox(height: 12.h),

            // Task list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _buildTaskCard(context, task, index + 1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task, int index) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final checkboxBgColor = isDarkMode ? const Color(0xFF334155) : Colors.white;
    final checkboxBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);
    final pendingStatusBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final pendingStatusTextColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final jtId = task['jt_id'] as int;
    final isChecked = _checkedTasks[jtId] ?? false;
    final taskname = task['taskname'] as String;

    return GestureDetector(
      onTap: () => _toggleTask(jtId),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: isChecked ? const Color(0xFF10B981) : AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14.r),
                    bottomLeft: Radius.circular(14.r),
                  ),
                ),
              ),
              // Main content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Row(
                    children: [
                      // Checkbox
                      GestureDetector(
                        onTap: () => _toggleTask(jtId),
                        child: Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            color: isChecked
                                ? const Color(0xFF10B981)
                                : checkboxBgColor,
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: isChecked
                                  ? const Color(0xFF10B981)
                                  : checkboxBorderColor,
                              width: 2,
                            ),
                          ),
                          child: isChecked
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 18.sp,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      // Task content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              taskname,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: isChecked
                                    ? textSecondaryColor
                                    : textPrimaryColor,
                                decoration: isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: textSecondaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.tag_rounded,
                                  size: 12.sp,
                                  color: textSecondaryColor,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Item $index',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status indicator
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : pendingStatusBgColor,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isChecked ? 'Done' : 'Pending',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isChecked
                                ? const Color(0xFF10B981)
                                : pendingStatusTextColor,
                          ),
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
    );
  }

}
