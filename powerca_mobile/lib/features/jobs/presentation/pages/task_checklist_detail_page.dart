import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/theme_provider.dart';

class TaskChecklistDetailPage extends StatefulWidget {
  final int jobId;
  final int taskId;
  final String taskName;
  final String jobNo;

  const TaskChecklistDetailPage({
    super.key,
    required this.jobId,
    required this.taskId,
    required this.taskName,
    required this.jobNo,
  });

  @override
  State<TaskChecklistDetailPage> createState() => _TaskChecklistDetailPageState();
}

class _TaskChecklistDetailPageState extends State<TaskChecklistDetailPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _checklistItems = [];
  List<Map<String, dynamic>> _groupedItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChecklistItems();
  }

  Future<void> _loadChecklistItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Query taskchecklist table for this job and task
      final response = await supabase
          .from('taskchecklist')
          .select('tc_id, job_id, task_id, checklistdesc, checkliststatus, completedby, completeddate')
          .eq('job_id', widget.jobId)
          .eq('task_id', widget.taskId)
          .order('tc_id');

      setState(() {
        _checklistItems = List<Map<String, dynamic>>.from(response);
        _groupedItems = _groupChecklistItems(_checklistItems);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _groupChecklistItems(List<Map<String, dynamic>> items) {
    // Group items by description
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var item in items) {
      final desc = item['checklistdesc'] ?? 'Checklist item';
      if (!grouped.containsKey(desc)) {
        grouped[desc] = [];
      }
      grouped[desc]!.add(item);
    }

    // Convert to list with count and completion info
    return grouped.entries.map((entry) {
      final items = entry.value;
      final completedCount = items.where((item) =>
        (item['checkliststatus'] == 1) ||
        (item['completedby'] != null && item['completedby'].toString().isNotEmpty)
      ).length;

      return {
        'checklistdesc': entry.key,
        'count': items.length,
        'completedCount': completedCount,
        'allCompleted': completedCount == items.length,
        'someCompleted': completedCount > 0 && completedCount < items.length,
        'completeddate': items.firstWhere(
          (item) => item['completeddate'] != null,
          orElse: () => {'completeddate': null}
        )['completeddate'],
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final backButtonBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backButtonBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: headerBgColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: Center(
            child: GestureDetector(
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
          ),
        ),
        leadingWidth: 58.w,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Checklist',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            Text(
              widget.jobNo,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final emptyStateBgColor = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8F9FC);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
            SizedBox(height: 16.h),
            Text(
              'Error loading checklist',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 16.h),
            TextButton.icon(
              onPressed: _loadChecklistItems,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_checklistItems.isEmpty) {
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
                Icons.checklist,
                size: 40.sp,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No checklist items',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'No checklist items found for this task',
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

    return RefreshIndicator(
      onRefresh: _loadChecklistItems,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 16.w,
          bottom: 16.w + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Info Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: textSecondaryColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    widget.taskName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        size: 16.sp,
                        color: textSecondaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        '${_groupedItems.length} unique ${_groupedItems.length == 1 ? 'item' : 'items'} (${_checklistItems.length} total)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Checklist Items
            Text(
              'Checklist Items',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
            SizedBox(height: 12.h),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _groupedItems.length,
              separatorBuilder: (context, index) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final item = _groupedItems[index];
                final count = item['count'] as int;
                final completedCount = item['completedCount'] as int;
                final isDone = item['allCompleted'] as bool;
                final someCompleted = item['someCompleted'] as bool;
                final doneDate = item['completeddate'];

                return Container(
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : borderColor,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Checkbox icon
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? const Color(0xFF10B981)
                                : Colors.transparent,
                            border: Border.all(
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : (isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
                              width: 2,
                            ),
                          ),
                          child: isDone
                              ? Icon(
                                  Icons.check,
                                  size: 16.sp,
                                  color: Colors.white,
                                )
                              : null,
                        ),

                        SizedBox(width: 12.w),

                        // Item details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['checklistdesc'] ?? 'Checklist item',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isDone
                                            ? textSecondaryColor
                                            : textPrimaryColor,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (count > 1) ...[
                                    SizedBox(width: 8.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: textSecondaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        'x$count',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (someCompleted) ...[
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.pending,
                                      size: 12.sp,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '$completedCount of $count completed',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (isDone && doneDate != null) ...[
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12.sp,
                                      color: const Color(0xFF10B981),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'All completed on ${_formatDate(doneDate)}',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Status badge
                        if (isDone || someCompleted)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              isDone ? 'Done' : '$completedCount/$count',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w600,
                                color: isDone
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }
}
