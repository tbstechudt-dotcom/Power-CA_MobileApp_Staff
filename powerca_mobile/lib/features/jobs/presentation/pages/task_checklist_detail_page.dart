import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/widgets/soft_page.dart';

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
    return SoftScaffold(
      title: 'Task Checklist',
      subtitle: widget.jobNo,
      onBack: () => Navigator.pop(context),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final p = SoftPalette.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return SoftMessage(
        icon: Icons.error_outline_rounded,
        title: 'Error loading checklist',
        message: _error,
        actionLabel: 'Retry',
        onAction: _loadChecklistItems,
        color: p.danger,
      );
    }

    if (_checklistItems.isEmpty) {
      return const SoftMessage(
        icon: Icons.checklist,
        title: 'No checklist items',
        message: 'No checklist items found for this task',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChecklistItems,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 4,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Info Card
            SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SoftIconBadge(icon: Icons.checklist_rounded, color: p.accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TASK', style: SoftText.overline(p)),
                        const SizedBox(height: 4),
                        Text(widget.taskName, style: SoftText.heading(p, size: 15)),
                        const SizedBox(height: 8),
                        Text(
                          '${_groupedItems.length} unique ${_groupedItems.length == 1 ? 'item' : 'items'} (${_checklistItems.length} total)',
                          style: SoftText.caption(p),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Checklist Items
            const SoftSectionTitle(title: 'Checklist Items'),

            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _groupedItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _groupedItems[index];
                final count = item['count'] as int;
                final completedCount = item['completedCount'] as int;
                final isDone = item['allCompleted'] as bool;
                final someCompleted = item['someCompleted'] as bool;
                final doneDate = item['completeddate'];

                return SoftCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Checkbox icon
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? p.success : Colors.transparent,
                          border: Border.all(
                            color: isDone ? p.success : p.border,
                            width: 2,
                          ),
                        ),
                        child: isDone
                            ? Icon(Icons.check_rounded, size: 16, color: p.surface)
                            : null,
                      ),

                      const SizedBox(width: 12),

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
                                    style: SoftText.body(
                                      p,
                                      size: 13.5,
                                      color: isDone ? p.muted : p.ink,
                                    ).copyWith(
                                      fontWeight: FontWeight.w500,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                if (count > 1) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: p.surfaceAlt,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'x$count',
                                      style: SoftText.caption(p, size: 10.5)
                                          .copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (someCompleted) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.pending, size: 13, color: p.warning),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$completedCount of $count completed',
                                    style: SoftText.caption(p, size: 11).copyWith(color: p.warning),
                                  ),
                                ],
                              ),
                            ],
                            if (isDone && doneDate != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.check_circle, size: 13, color: p.success),
                                  const SizedBox(width: 4),
                                  Text(
                                    'All completed on ${_formatDate(doneDate)}',
                                    style: SoftText.caption(p, size: 11).copyWith(color: p.success),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Status badge
                      if (isDone || someCompleted) ...[
                        const SizedBox(width: 8),
                        SoftStatusPill(
                          label: isDone ? 'Done' : '$completedCount/$count',
                          color: isDone ? p.success : p.warning,
                          showDot: false,
                        ),
                      ],
                    ],
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
