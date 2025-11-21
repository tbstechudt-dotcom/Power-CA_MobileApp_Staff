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

      // Fetch tasks for this job
      final tasksResponse = await supabase
          .from('jobtasks')
          .select('jt_id, job_id, staff_id, task_id, jtaskdate, jenddate, jtstatus, totalhrs')
          .eq('job_id', jobId)
          .order('jtaskdate', ascending: true);

      // Get staff names for tasks
      final staffIds = tasksResponse
          .map((task) => task['staff_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<int, String> staffNames = {};
      if (staffIds.isNotEmpty) {
        final staffResponse = await supabase
            .from('mbstaff')
            .select('staff_id, staffname')
            .inFilter('staff_id', staffIds);

        for (var staff in staffResponse) {
          staffNames[staff['staff_id'] as int] = staff['staffname'] ?? 'Unknown';
        }
      }

      // Get task names from taskmaster
      final taskIds = tasksResponse
          .map((task) => task['task_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<int, String> taskNames = {};
      if (taskIds.isNotEmpty) {
        final taskResponse = await supabase
            .from('taskmaster')
            .select('task_id, taskname')
            .inFilter('task_id', taskIds);

        for (var task in taskResponse) {
          taskNames[task['task_id'] as int] = task['taskname'] ?? 'Unknown Task';
        }
      }

      // Transform to UI format
      final tasks = tasksResponse.map<Map<String, dynamic>>((record) {
        final staffId = record['staff_id'] as int?;
        final taskId = record['task_id'] as int?;
        final staffName = staffId != null ? (staffNames[staffId] ?? 'Unknown') : 'Unassigned';
        final taskName = taskId != null ? (taskNames[taskId] ?? 'Task #$taskId') : 'No Task';

        return {
          'jt_id': record['jt_id'],
          'taskName': taskName,
          'staffName': staffName,
          'startDate': record['jtaskdate'] != null
              ? DateTime.parse(record['jtaskdate'])
              : null,
          'endDate': record['jenddate'] != null
              ? DateTime.parse(record['jenddate'])
              : null,
          'status': record['jtstatus'] ?? 'P',
          'totalHours': record['totalhrs'] ?? 0,
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
          .select('wd_id, job_id, staff_id, wddate, wdstarttime, wdendtime, wdhours, wdnotes')
          .eq('job_id', jobId)
          .order('wddate', ascending: false);

      // Get staff names
      final staffIds = diaryResponse
          .map((entry) => entry['staff_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<int, String> staffNames = {};
      if (staffIds.isNotEmpty) {
        final staffResponse = await supabase
            .from('mbstaff')
            .select('staff_id, staffname')
            .inFilter('staff_id', staffIds);

        for (var staff in staffResponse) {
          staffNames[staff['staff_id'] as int] = staff['staffname'] ?? 'Unknown';
        }
      }

      // Transform to UI format
      final entries = diaryResponse.map<Map<String, dynamic>>((record) {
        final staffId = record['staff_id'] as int?;
        final staffName = staffId != null ? (staffNames[staffId] ?? 'Unknown') : 'Unknown';

        return {
          'wd_id': record['wd_id'],
          'date': record['wddate'] != null
              ? DateTime.parse(record['wddate'])
              : null,
          'staffName': staffName,
          'startTime': record['wdstarttime'] ?? '',
          'endTime': record['wdendtime'] ?? '',
          'hours': record['wdhours'] ?? 0,
          'notes': record['wdnotes'] ?? '',
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
                color: const Color(0xFFF3F4F6),
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
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final statusColor = _getTaskStatusColor(task['status'] as String);
          final statusText = _getTaskStatusText(task['status'] as String);

          return Container(
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
                // Header
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
                      Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.task_alt,
                          size: 18.sp,
                          color: statusColor,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          task['taskName'] as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                          statusText,
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
                // Content
                Padding(
                  padding: EdgeInsets.all(10.w),
                  child: Column(
                    children: [
                      // Staff
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14.sp,
                            color: const Color(0xFF6B7280),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            task['staffName'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      SizedBox(height: 6.h),
                      // Dates and Hours
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
                                    task['startDate'] != null
                                        ? dateFormat.format(task['startDate'])
                                        : '-',
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
                          // Hours
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14.sp,
                                color: const Color(0xFF8B5CF6),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${task['totalHours']}h',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                            ],
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
                color: const Color(0xFFF3F4F6),
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

    return RefreshIndicator(
      onRefresh: _loadWorkDiary,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        itemCount: _workDiaryEntries.length,
        itemBuilder: (context, index) {
          final entry = _workDiaryEntries[index];

          return Container(
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
                // Header with Date
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.r),
                      topRight: Radius.circular(12.r),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36.w,
                        height: 36.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          size: 18.sp,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          entry['date'] != null
                              ? dateFormat.format(entry['date'])
                              : 'No Date',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      // Hours Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${entry['hours']}h',
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
                // Content
                Padding(
                  padding: EdgeInsets.all(10.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Staff and Time Row
                      Row(
                        children: [
                          // Staff
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14.sp,
                                  color: const Color(0xFF6B7280),
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    entry['staffName'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF374151),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Time
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14.sp,
                                color: const Color(0xFF9CA3AF),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${entry['startTime']} - ${entry['endTime']}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Notes (if any)
                      if ((entry['notes'] as String).isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                        SizedBox(height: 6.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notes_outlined,
                              size: 14.sp,
                              color: const Color(0xFF9CA3AF),
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                entry['notes'] as String,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF6B7280),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
