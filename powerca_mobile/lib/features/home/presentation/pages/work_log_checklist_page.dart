import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/widgets/soft_page.dart';

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
    final p = SoftPalette.of(context);

    // Show saving indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: p.ink),
              ),
              const SizedBox(height: 14),
              Text(
                'Saving...',
                style: SoftText.body(p, color: p.ink).copyWith(
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
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
            backgroundColor: p.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
            backgroundColor: p.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      body = SoftMessage(
        icon: Icons.error_outline_rounded,
        title: "Couldn't load checklist",
        message: _errorMessage,
        actionLabel: 'Retry',
        onAction: _loadTasks,
        color: p.danger,
      );
    } else if (_tasks.isEmpty) {
      body = const SoftMessage(
        icon: Icons.checklist_outlined,
        title: 'No tasks found',
        message: 'No tasks assigned to you for this job',
      );
    } else {
      body = _buildTaskList(context);
    }

    return SoftScaffold(
      title: 'Task Checklist',
      subtitle: 'Job #${widget.jobId}',
      body: body,
      bottomBar: _tasks.isNotEmpty
          ? SoftPillButton(
              label: 'Save Checklist',
              icon: Icons.save_rounded,
              onPressed: _saveChecklist,
            )
          : null,
    );
  }

  Widget _buildTaskList(BuildContext context) {
    final p = SoftPalette.of(context);

    // Count completed tasks
    final completedCount = _checkedTasks.values.where((v) => v).length;
    final totalCount = _tasks.length;
    final progressPercent = totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;
    final allDone = completedCount == totalCount;
    final progressColor = allDone ? p.success : p.accent;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: p.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // Progress card
          SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    SoftIconBadge(icon: Icons.checklist_rounded, color: progressColor, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Progress', style: SoftText.heading(p, size: 14.5)),
                          const SizedBox(height: 2),
                          Text(
                            '$completedCount of $totalCount tasks',
                            style: SoftText.caption(p),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$progressPercent%',
                      style: SoftText.title(p, size: 20).copyWith(color: progressColor),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: totalCount > 0 ? completedCount / totalCount : 0,
                    backgroundColor: p.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          const SoftSectionTitle(title: 'Checklist Items'),

          // Task list
          for (var i = 0; i < _tasks.length; i++) ...[
            _buildTaskCard(context, _tasks[i], i + 1),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task, int index) {
    final p = SoftPalette.of(context);

    final jtId = task['jt_id'] as int;
    final isChecked = _checkedTasks[jtId] ?? false;
    final taskname = task['taskname'] as String;

    return SoftCard(
      padding: const EdgeInsets.all(14),
      radius: 18,
      onTap: () => _toggleTask(jtId),
      child: Row(
        children: [
          // Checkbox
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isChecked ? p.success : p.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isChecked ? p.success : p.border,
                width: 1.6,
              ),
            ),
            child: isChecked
                ? Icon(Icons.check_rounded, size: 18, color: p.surface)
                : null,
          ),
          const SizedBox(width: 14),
          // Task content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  taskname,
                  style: SoftText.body(p, color: isChecked ? p.muted : p.ink).copyWith(
                    fontWeight: FontWeight.w500,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    decorationColor: p.muted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text('Item $index', style: SoftText.caption(p, size: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SoftStatusPill(
            label: isChecked ? 'Done' : 'Pending',
            color: isChecked ? p.success : p.muted,
          ),
        ],
      ),
    );
  }
}
