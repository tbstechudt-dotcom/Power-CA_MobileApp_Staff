import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';

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

      // Fetch tasks for the staff member and job
      List<dynamic> tasksResponse;

      if (widget.jobId > 0) {
        // If job ID is specified, get tasks for that job
        tasksResponse = await supabase
            .from('jobtasks')
            .select('jt_id, job_id, staff_id, task_id, taskname, tstartdate, tenddate, status, totalhours')
            .eq('staff_id', widget.staffId)
            .eq('job_id', widget.jobId)
            .order('tstartdate', ascending: true);
      } else {
        // Get all tasks for the staff member
        tasksResponse = await supabase
            .from('jobtasks')
            .select('jt_id, job_id, staff_id, task_id, taskname, tstartdate, tenddate, status, totalhours')
            .eq('staff_id', widget.staffId)
            .order('tstartdate', ascending: true)
            .limit(50);
      }

      // Transform tasks
      final tasks = tasksResponse.map<Map<String, dynamic>>((task) {
        final jtId = task['jt_id'] as int;
        // Initialize checked state based on status
        final status = (task['status'] as String?)?.toLowerCase() ?? '';
        _checkedTasks[jtId] = status == 'completed' || status == 'done';

        return {
          'jt_id': jtId,
          'job_id': task['job_id'],
          'staff_id': task['staff_id'],
          'task_id': task['task_id'],
          'taskname': task['taskname'] ?? 'Unnamed Task',
          'tstartdate': task['tstartdate'] != null ? DateTime.parse(task['tstartdate']) : null,
          'tenddate': task['tenddate'] != null ? DateTime.parse(task['tenddate']) : null,
          'status': task['status'] ?? 'Pending',
          'totalhours': task['totalhours'] ?? 0,
        };
      }).toList();

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
    // Show saving indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
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
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final supabase = Supabase.instance.client;

      // Update task statuses in database
      for (final task in _tasks) {
        final jtId = task['jt_id'] as int;
        final isChecked = _checkedTasks[jtId] ?? false;
        final newStatus = isChecked ? 'Completed' : 'Pending';

        await supabase
            .from('jobtasks')
            .update({'status': newStatus})
            .eq('jt_id', jtId);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A5F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Task Checklist',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E3A5F),
          ),
        ),
        actions: [
          // Save button
          TextButton.icon(
            onPressed: _tasks.isEmpty ? null : _saveChecklist,
            icon: Icon(
              Icons.save_outlined,
              size: 18.sp,
              color: AppTheme.primaryColor,
            ),
            label: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
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
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          color: const Color(0xFF6B7280),
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
                  ? _buildEmptyState()
                  : _buildTaskList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_outlined,
            size: 80.sp,
            color: const Color(0xFFE5E7EB),
          ),
          SizedBox(height: 16.h),
          Text(
            'No tasks found',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'No tasks assigned to you for this job',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    // Count completed tasks
    final completedCount = _checkedTasks.values.where((v) => v).length;
    final totalCount = _tasks.length;

    return Column(
      children: [
        // Progress header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    '$completedCount / $totalCount completed',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: totalCount > 0 ? completedCount / totalCount : 0,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completedCount == totalCount
                        ? const Color(0xFF4CAF50)
                        : AppTheme.primaryColor,
                  ),
                  minHeight: 8.h,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),

        // Task list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTasks,
            color: AppTheme.primaryColor,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              itemCount: _tasks.length,
              separatorBuilder: (context, index) => SizedBox(height: 8.h),
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return _buildTaskCard(task);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final jtId = task['jt_id'] as int;
    final isChecked = _checkedTasks[jtId] ?? false;
    final taskname = task['taskname'] as String;
    final status = task['status'] as String;
    final totalhours = task['totalhours'] ?? 0;
    final jobId = task['job_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _toggleTask(jtId),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isChecked ? const Color(0xFF4CAF50) : const Color(0xFFE5E7EB),
            width: isChecked ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Container(
              width: 24.w,
              height: 24.w,
              margin: EdgeInsets.only(top: 2.h),
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFF4CAF50) : Colors.white,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: isChecked ? const Color(0xFF4CAF50) : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? Icon(
                      Icons.check,
                      size: 16.sp,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: 12.w),

            // Task content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskname,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isChecked
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF1F2937),
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      // Job ID
                      if (jobId.isNotEmpty) ...[
                        Icon(
                          Icons.work_outline,
                          size: 12.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Job #$jobId',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                        SizedBox(width: 12.w),
                      ],
                      // Hours
                      Icon(
                        Icons.access_time,
                        size: 12.sp,
                        color: const Color(0xFF9CA3AF),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${totalhours}h',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Status badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          isChecked ? 'Completed' : status,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: isChecked ? const Color(0xFF4CAF50) : _getStatusColor(status),
                          ),
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
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return const Color(0xFF4CAF50);
      case 'in progress':
      case 'ongoing':
        return const Color(0xFF2196F3);
      case 'pending':
        return const Color(0xFFFFA726);
      case 'on hold':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
