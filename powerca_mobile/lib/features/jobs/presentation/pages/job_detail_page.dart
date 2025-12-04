import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../auth/domain/entities/staff.dart';

class JobDetailPage extends StatefulWidget {
  final Staff currentStaff;
  final Map<String, dynamic> job;

  const JobDetailPage({
    super.key,
    required this.currentStaff,
    required this.job,
  });

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _workDiaryEntries = [];
  bool _isLoadingTasks = true;
  bool _isLoadingDiary = true;
  String? _tasksError;
  String? _diaryError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTasks();
    _loadWorkDiary();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoadingTasks = true;
      _tasksError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final jobId = widget.job['job_id'];
      final currentStaffId = widget.currentStaff.staffId;

      // Fetch tasks for this job with available hour columns
      final tasksResponse = await supabase
          .from('jobtasks')
          .select('jt_id, job_id, task_id, task_desc, createddate, task_status, jobdet_man_hrs, actual_man_hrs')
          .eq('job_id', jobId)
          .order('task_desc', ascending: true);

      // Fetch workdiary entries for this job to calculate login/other staff hours
      final workdiaryResponse = await supabase
          .from('workdiary')
          .select('wd_id, job_id, staff_id, task_id, minutes')
          .eq('job_id', jobId);

      // Group workdiary by task_id
      final Map<int, Map<String, double>> taskHours = {};
      for (final entry in workdiaryResponse) {
        final taskId = entry['task_id'] as int?;
        if (taskId == null) continue;

        final staffId = entry['staff_id'] as int?;
        final minutes = (entry['minutes'] ?? 0) as num;
        final hours = minutes / 60;

        if (!taskHours.containsKey(taskId)) {
          taskHours[taskId] = {'loginStaff': 0.0, 'otherStaff': 0.0};
        }

        if (staffId == currentStaffId) {
          taskHours[taskId]!['loginStaff'] = taskHours[taskId]!['loginStaff']! + hours;
        } else {
          taskHours[taskId]!['otherStaff'] = taskHours[taskId]!['otherStaff']! + hours;
        }
      }

      // Transform to UI format using values from jobtasks table
      final tasks = tasksResponse.map<Map<String, dynamic>>((record) {
        final taskId = record['task_id'] as int?;

        // Get hours from jobtasks table
        final estHours = (record['jobdet_man_hrs'] ?? 0) as num;

        // Parse actual_man_hrs (time format like "02:30:00")
        double actHours = 0.0;
        final actualHrsValue = record['actual_man_hrs'];
        if (actualHrsValue != null && actualHrsValue is String) {
          final parts = actualHrsValue.split(':');
          if (parts.length >= 2) {
            final hours = int.tryParse(parts[0]) ?? 0;
            final minutes = int.tryParse(parts[1]) ?? 0;
            actHours = hours + (minutes / 60);
          }
        }

        // Get login/other staff hours from workdiary
        final loginStaffHours = taskId != null ? (taskHours[taskId]?['loginStaff'] ?? 0.0) : 0.0;
        final otherStaffHours = taskId != null ? (taskHours[taskId]?['otherStaff'] ?? 0.0) : 0.0;

        return {
          'jt_id': record['jt_id'],
          'task_id': taskId,
          'taskName': record['task_desc'] ?? 'Unnamed Task',
          'estHours': estHours,
          'loginStaffHours': loginStaffHours,
          'otherStaffHours': otherStaffHours,
          'actHours': actHours,
        };
      }).toList();

      setState(() {
        _tasks = tasks;
        _isLoadingTasks = false;
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      setState(() {
        _tasksError = e.toString();
        _isLoadingTasks = false;
      });
    }
  }

  Future<void> _loadWorkDiary() async {
    setState(() {
      _isLoadingDiary = true;
      _diaryError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final jobId = widget.job['job_id'];

      // Fetch work diary entries for this job
      final diaryResponse = await supabase
          .from('workdiary')
          .select('wd_id, job_id, staff_id, task_id, date, timefrom, timeto, minutes, tasknotes')
          .eq('job_id', jobId)
          .order('date', ascending: false);

      // Get task descriptions
      final taskIds = diaryResponse
          .map((entry) => entry['task_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<int, String> taskDescriptions = {};
      if (taskIds.isNotEmpty) {
        final taskResponse = await supabase
            .from('jobtasks')
            .select('task_id, task_desc')
            .eq('job_id', jobId);

        for (var task in taskResponse) {
          taskDescriptions[task['task_id'] as int] = task['task_desc'] ?? 'Unknown Task';
        }
      }

      // Transform to UI format
      final entries = diaryResponse.map<Map<String, dynamic>>((record) {
        final taskId = record['task_id'] as int?;
        final taskDesc = taskId != null ? (taskDescriptions[taskId] ?? 'Unknown Task') : 'Unknown Task';
        final minutes = record['minutes'] as int? ?? 0;
        final hours = minutes ~/ 60;
        final mins = minutes % 60;

        return {
          'wd_id': record['wd_id'],
          'date': record['date'] != null
              ? DateTime.parse(record['date'])
              : null,
          'taskDesc': taskDesc,
          'minutes': minutes,
          'hoursFormatted': '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}',
          'notes': record['tasknotes'] ?? '',
        };
      }).toList();

      setState(() {
        _workDiaryEntries = entries;
        _isLoadingDiary = false;
      });
    } catch (e) {
      debugPrint('Error loading work diary: $e');
      setState(() {
        _diaryError = e.toString();
        _isLoadingDiary = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getTaskStatusColor(String status) {
    switch (status) {
      case 'C':
        return const Color(0xFF10B981); // Completed - green
      case 'P':
        return const Color(0xFFF59E0B); // Pending - orange
      case 'W':
        return const Color(0xFF3B82F6); // Working - blue
      default:
        return const Color(0xFF6B7280); // Default - gray
    }
  }

  String _getTaskStatusText(String status) {
    switch (status) {
      case 'C':
        return 'Completed';
      case 'P':
        return 'Pending';
      case 'W':
        return 'In Progress';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2563EB)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.job['jobNo'] ?? 'Job Details',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
            ),
            Text(
              widget.job['company'] ?? '',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt, size: 16),
                      SizedBox(width: 6),
                      Text('Task Summary'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month, size: 16),
                      SizedBox(width: 6),
                      Text('Day Summary'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Task Summary Tab
                _buildTaskSummaryTab(dateFormat),
                // Day Summary Tab
                _buildDaySummaryTab(dateFormat),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(num hours) {
    final h = hours.toInt();
    final m = ((hours - h) * 60).round();
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  Widget _buildTaskSummaryTab(DateFormat dateFormat) {
    if (_isLoadingTasks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasksError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
            SizedBox(height: 16.h),
            Text(
              'Error loading tasks',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
            TextButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.task_alt,
                size: 40.sp,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No tasks found',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Tasks will appear here when added',
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

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(12.w),
        child: Container(
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
              // Table Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    topRight: Radius.circular(12.r),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Tasks',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 45.w,
                      child: Text(
                        'Est.\nHrs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 45.w,
                      child: Text(
                        'Login\nStaff',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 45.w,
                      child: Text(
                        'Other\nStaff',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 45.w,
                      child: Text(
                        'Act.\nHrs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tasks.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFFE5E7EB),
                ),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final estHours = task['estHours'] as num;
                  final loginStaffHours = task['loginStaffHours'] as double;
                  final otherStaffHours = task['otherStaffHours'] as double;
                  final actHours = task['actHours'] as double;

                  // View only - no navigation
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 24.h),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            task['taskName'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1F2937),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 45.w,
                          child: Text(
                            _formatHours(estHours),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 45.w,
                          child: Text(
                            _formatHours(loginStaffHours),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 45.w,
                          child: Text(
                            _formatHours(otherStaffHours),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 45.w,
                          child: Text(
                            _formatHours(actHours),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: actHours > 0 ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySummaryTab(DateFormat dateFormat) {
    if (_isLoadingDiary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_diaryError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
            SizedBox(height: 16.h),
            Text(
              'Error loading diary entries',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
            TextButton.icon(
              onPressed: _loadWorkDiary,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_workDiaryEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.calendar_month,
                size: 40.sp,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No diary entries found',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Work diary entries will appear here',
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

    // Calculate total hours
    int totalMinutes = 0;
    for (final entry in _workDiaryEntries) {
      totalMinutes += entry['minutes'] as int;
    }
    final totalHours = totalMinutes ~/ 60;
    final totalMins = totalMinutes % 60;
    final totalFormatted = '${totalHours.toString().padLeft(2, '0')}:${totalMins.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      onRefresh: _loadWorkDiary,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(12.w),
        child: Container(
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
              // Table Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    topRight: Radius.circular(12.r),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80.w,
                      child: Text(
                        'Work Date',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Task',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Work Details',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50.w,
                      child: Text(
                        'hh:mm',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _workDiaryEntries.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFFE5E7EB),
                ),
                itemBuilder: (context, index) {
                final entry = _workDiaryEntries[index];

                // View only - no navigation
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 24.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Work Date
                      SizedBox(
                        width: 80.w,
                        child: Text(
                          entry['date'] != null
                              ? DateFormat('dd/MM/yyyy').format(entry['date'])
                              : '-',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF374151),
                          ),
                        ),
                      ),
                      // Task
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry['taskDesc'] as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF374151),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Work Details
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: EdgeInsets.only(left: 4.w),
                          child: Text(
                            entry['notes'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Hours
                      SizedBox(
                        width: 50.w,
                        child: Text(
                          entry['hoursFormatted'] as String,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Total Row
            Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              border: const Border(
                top: BorderSide(
                  color: Color(0xFFD1D5DB),
                  width: 1,
                ),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12.r),
                bottomRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total hours :',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 50.w,
                  child: Text(
                    totalFormatted,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
