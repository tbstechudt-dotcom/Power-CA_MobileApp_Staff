import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../../home/presentation/pages/work_log_entry_form_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F5F5);
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final backButtonBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backButtonBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);

    final dateFormat = DateFormat('dd MMM yyyy');

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
              widget.job['job'] ?? 'Job Details',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.job['jobNo'] ?? ''} • ${widget.job['company'] ?? ''}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: textSecondaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: headerBgColor,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: textSecondaryColor,
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
                _buildTaskSummaryTab(context, dateFormat),
                // Day Summary Tab
                _buildDaySummaryTab(context, dateFormat),
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

  Widget _buildTaskSummaryTab(BuildContext context, DateFormat dateFormat) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final headerBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC);
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final emptyStateBgColor = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8F9FC);

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
                color: textSecondaryColor,
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
                color: emptyStateBgColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.task_alt,
                size: 40.sp,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No tasks found',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Tasks will appear here when added',
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
      onRefresh: _loadTasks,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(12.w),
        child: Container(
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
            children: [
              // Table Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: headerBgColor,
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
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        'Est.\nHrs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        'Login\nStaff',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        'Other\nStaff',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        'Act.\nHrs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                    ),
                    // Daily Entry action column header
                    SizedBox(width: 4.w),
                    SizedBox(
                      width: 32.w,
                      child: Text(
                        'Daily\nEntry',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
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
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                ),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final estHours = task['estHours'] as num;
                  final loginStaffHours = task['loginStaffHours'] as double;
                  final otherStaffHours = task['otherStaffHours'] as double;
                  final actHours = task['actHours'] as double;

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                    child: Row(
                      children: [
                        // Task name
                        Expanded(
                          flex: 3,
                          child: Text(
                            task['taskName'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: textPrimaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Est Hours
                        SizedBox(
                          width: 40.w,
                          child: Text(
                            _formatHours(estHours),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: textSecondaryColor,
                            ),
                          ),
                        ),
                        // Login Staff Hours
                        SizedBox(
                          width: 40.w,
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
                        // Other Staff Hours
                        SizedBox(
                          width: 40.w,
                          child: Text(
                            _formatHours(otherStaffHours),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: textSecondaryColor,
                            ),
                          ),
                        ),
                        // Act Hours
                        SizedBox(
                          width: 40.w,
                          child: Text(
                            _formatHours(actHours),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: actHours > 0 ? const Color(0xFF10B981) : textSecondaryColor,
                            ),
                          ),
                        ),
                        // Select for Daily Entry button - compact icon
                        SizedBox(width: 4.w),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkLogEntryFormPage(
                                  selectedDate: DateTime.now(),
                                  staffId: widget.currentStaff.staffId,
                                  preSelectedJobId: widget.job['job_id'] as int?,
                                  preSelectedClientId: widget.job['client_id'] as int?,
                                  preSelectedJobName: widget.job['job'] as String?,
                                  preSelectedClientName: widget.job['company'] as String?,
                                  preSelectedTaskId: task['task_id'] as int?,
                                  preSelectedTaskName: task['taskName'] as String?,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 32.w,
                            height: 32.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 18.sp,
                              color: Colors.white,
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

  Widget _buildDaySummaryTab(BuildContext context, DateFormat dateFormat) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final headerBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final emptyStateBgColor = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8F9FC);

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
                color: textSecondaryColor,
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
                color: emptyStateBgColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Icon(
                Icons.calendar_month,
                size: 40.sp,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'No diary entries found',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: textSecondaryColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Work diary entries will appear here',
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
            children: [
              // Table Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: headerBgColor,
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
                          color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
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
                          color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
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
                          color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
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
                          color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
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
                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
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
                            color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
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
                            color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
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
                              color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
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
              color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC),
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
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
                      color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151),
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
