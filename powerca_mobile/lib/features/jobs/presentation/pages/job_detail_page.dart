import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
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
    final p = SoftPalette.of(context);
    final activeBg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
    const tabLabel = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    );
    final company = (widget.job['company'] ?? '').toString();
    final jobDesc = (widget.job['job'] ?? 'Job details').toString();

    return Scaffold(
      backgroundColor: p.background,
      body: HomeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SoftIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    size: 44,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ),

              // "Job KJ..." + "CLIENT — description"
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeEyebrow('Job ${widget.job['jobNo'] ?? ''}'),
                    HomeInlineHeadline(
                      size: 22,
                      parts: [
                        if (company.isNotEmpty) (text: company, strong: true),
                        (text: company.isNotEmpty ? ' — $jobDesc' : jobDesc, strong: company.isEmpty),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab switch
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.border),
                    boxShadow: p.shadow,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: p.isDark ? p.background : Colors.white,
                    unselectedLabelColor: p.inkSoft,
                    indicator: BoxDecoration(
                      color: activeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(999),
                    labelStyle: tabLabel,
                    unselectedLabelStyle: tabLabel.copyWith(fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Task summary'),
                      Tab(text: 'Day summary'),
                    ],
                  ),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskSummaryTab(context),
                    _buildDaySummaryTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHours(num hours) {
    final h = hours.toInt();
    final m = ((hours - h) * 60).round();
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  /// Soft card with a title and a caption (empty / error states).
  Widget _noteCard(SoftPalette p, String title, String message, {VoidCallback? onRetry}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        SoftCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SoftText.heading(p, size: 17).copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(message, style: SoftText.caption(p, size: 12.5)),
                  ],
                ),
              ),
              if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }

  void _openDailyEntry(Map<String, dynamic> task) {
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
  }

  Widget _buildTaskSummaryTab(BuildContext context) {
    final p = SoftPalette.of(context);

    if (_isLoadingTasks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasksError != null) {
      return _noteCard(p, "Couldn't load tasks", 'Check your connection and try again.',
          onRetry: _loadTasks,);
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTasks,
        child: _noteCard(p, 'No tasks found', 'Tasks will appear here when added.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final estHours = (task['estHours'] as num).toDouble();
          final you = task['loginStaffHours'] as double;
          final others = task['otherStaffHours'] as double;
          final actual = task['actHours'] as double;
          final logged = you + others;
          final remaining = (estHours - logged).clamp(0.0, double.infinity);

          return SoftCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['taskName'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SoftText.heading(p, size: 16.5).copyWith(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Estimated ${_formatHours(estHours)} hrs',
                            style: SoftText.caption(p, size: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SoftIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Daily entry',
                      size: 42,
                      onTap: () => _openDailyEntry(task),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: HomeStat(label: 'You', value: _formatHours(you), dot: p.accent)),
                    Expanded(child: HomeStat(label: 'Others', value: _formatHours(others), dot: p.leave)),
                    Expanded(child: HomeStat(label: 'Actual', value: _formatHours(actual))),
                  ],
                ),
                const SizedBox(height: 16),
                HomeSegmentBar(
                  height: 20,
                  segments: logged == 0
                      ? const []
                      : [
                          (value: you, color: p.accent),
                          (value: others, color: p.leave),
                          (value: remaining, color: p.border),
                        ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Logged ${_formatHours(logged)}', style: SoftText.caption(p, size: 12)),
                    const Spacer(),
                    Text('Est. ${_formatHours(estHours)}', style: SoftText.caption(p, size: 12)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaySummaryTab(BuildContext context) {
    final p = SoftPalette.of(context);

    if (_isLoadingDiary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_diaryError != null) {
      return _noteCard(p, "Couldn't load diary entries", 'Check your connection and try again.',
          onRetry: _loadWorkDiary,);
    }

    if (_workDiaryEntries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadWorkDiary,
        child: _noteCard(p, 'No diary entries found', 'Work diary entries will appear here.'),
      );
    }

    // Calculate total hours
    int totalMinutes = 0;
    for (final entry in _workDiaryEntries) {
      totalMinutes += entry['minutes'] as int;
    }
    final totalFormatted =
        '${(totalMinutes ~/ 60).toString().padLeft(2, '0')}:${(totalMinutes % 60).toString().padLeft(2, '0')}';
    final count = _workDiaryEntries.length;

    return RefreshIndicator(
      onRefresh: _loadWorkDiary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          // Total
          SoftCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total logged', style: SoftText.heading(p, size: 17).copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(
                        '$count ${count == 1 ? 'entry' : 'entries'} on this job',
                        style: SoftText.caption(p, size: 12.5),
                      ),
                    ],
                  ),
                ),
                Text('$totalFormatted hrs', style: SoftText.heading(p, size: 17)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Entries (view only)
          SoftCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
            child: Column(
              children: [
                for (int i = 0; i < count; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.border),
                  _buildDiaryRow(p, _workDiaryEntries[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryRow(SoftPalette p, Map<String, dynamic> entry) {
    final date = entry['date'] as DateTime?;
    final notes = (entry['notes'] as String).trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date != null ? DateFormat('EEE, d MMM yyyy').format(date) : '-',
                  style: SoftText.heading(p, size: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  entry['taskDesc'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SoftText.caption(p, size: 12.5),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SoftText.body(p, size: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(entry['hoursFormatted'] as String, style: SoftText.heading(p, size: 14.5)),
        ],
      ),
    );
  }
}
