import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/widgets/soft_page.dart';
import 'work_log_entry_form_page.dart';
import 'work_log_detail_page.dart';

/// Work Log List Page - entries logged for a single day (soft UI)
class WorkLogListPage extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> entries;
  final int staffId;

  const WorkLogListPage({
    super.key,
    required this.selectedDate,
    required this.entries,
    required this.staffId,
  });

  @override
  State<WorkLogListPage> createState() => _WorkLogListPageState();
}

class _WorkLogListPageState extends State<WorkLogListPage> {
  late List<Map<String, dynamic>> _entries;
  Map<int, String> _clientNames = {};
  Map<int, String> _jobNames = {};
  bool _isLoadingNames = true;

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.entries);
    _loadClientAndJobNames();
  }

  Future<void> _loadClientAndJobNames() async {
    try {
      final supabase = Supabase.instance.client;

      final clientIds = _entries
          .map((e) => e['client_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      final jobIds = _entries
          .map((e) => e['job_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (clientIds.isNotEmpty) {
        final clientResponse = await supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', clientIds);

        for (var client in clientResponse) {
          _clientNames[client['client_id']] = client['clientname'] ?? 'Unknown';
        }
      }

      if (jobIds.isNotEmpty) {
        final jobResponse = await supabase
            .from('jobshead')
            .select('job_id, work_desc')
            .inFilter('job_id', jobIds);

        for (var job in jobResponse) {
          _jobNames[job['job_id']] = job['work_desc'] ?? 'Unknown';
        }
      }

      if (mounted) {
        setState(() => _isLoadingNames = false);
      }
    } catch (e) {
      debugPrint('Error loading names: $e');
      if (mounted) {
        setState(() => _isLoadingNames = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SoftPageHeader(
                title: 'Work Log',
                subtitle: DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
                onBack: () => Navigator.pop(context, true),
              ),
              Expanded(
                child: _entries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadClientAndJobNames();
                        },
                        color: p.accent,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                          children: [
                            // Summary tiles
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryTile(
                                    label: 'Total time',
                                    value: _formatMinutesToHours(_calculateTotalMinutes()),
                                    icon: Icons.schedule_rounded,
                                    color: p.accent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SummaryTile(
                                    label: 'Entries',
                                    value: '${_entries.length}',
                                    icon: Icons.assignment_rounded,
                                    color: p.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            SoftSectionTitle(
                              title: 'Work entries',
                              trailing: Text(
                                '${_entries.length} ${_entries.length == 1 ? 'entry' : 'entries'}',
                                style: SoftText.caption(p),
                              ),
                            ),
                            for (var i = 0; i < _entries.length; i++) ...[
                              _buildEntryCard(_entries[i], i + 1),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addNewEntry(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Entry'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SoftMessage(
              icon: Icons.post_add_rounded,
              title: 'No Entries Yet',
              message: 'Start logging your work for this day',
            ),
            SoftPillButton(
              label: 'Add Entry',
              icon: Icons.add_rounded,
              expand: false,
              height: 46,
              onPressed: () => _addNewEntry(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry, int index) {
    final p = SoftPalette.of(context);
    final tasknotes = entry['tasknotes'] ?? '';
    final minutes = entry['minutes'] ?? 0;
    final hours = _formatMinutesToHours(minutes);
    final jobId = entry['job_id'];
    final clientId = entry['client_id'];
    final timeFrom = entry['timefrom'];
    final timeTo = entry['timeto'];
    final date = entry['date'];

    final clientName = clientId != null ? _clientNames[clientId] : null;
    final jobName = jobId != null ? _jobNames[jobId] : null;
    final hasTimeRange = timeFrom != null && timeTo != null;

    // Format date for display
    String formattedDate = '';
    if (date != null) {
      try {
        final dateObj = DateTime.parse(date.toString());
        formattedDate = DateFormat('yyyy-MM-dd').format(dateObj);
      } catch (e) {
        formattedDate = date.toString();
      }
    }

    return SoftCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkLogDetailPage(
              entry: entry,
              entryIndex: index,
              selectedDate: widget.selectedDate,
              staffId: widget.staffId,
              jobName: jobName,
              clientName: clientName,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row - job name and duration
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoadingNames ? 'Loading...' : (jobName ?? 'Job #$jobId'),
                      style: SoftText.heading(p, size: 15).copyWith(height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (clientId != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.business_rounded, size: 14, color: p.muted),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _isLoadingNames
                                  ? 'Loading...'
                                  : (clientName ?? 'Client #$clientId'),
                              style: SoftText.caption(p, size: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SoftStatusPill(
                label: hours,
                color: p.accent,
                icon: Icons.timer_outlined,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: p.border),
          ),
          // Details
          Row(
            children: [
              if (hasTimeRange) ...[
                Icon(Icons.schedule_rounded, size: 15, color: p.accent),
                const SizedBox(width: 6),
                Text(
                  '${_formatTimeDisplay(timeFrom)} - ${_formatTimeDisplay(timeTo)}',
                  style: SoftText.body(p, size: 13, color: p.ink)
                      .copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 14),
              ],
              if (formattedDate.isNotEmpty || tasknotes.isNotEmpty) ...[
                Icon(Icons.event_note_rounded, size: 15, color: p.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tasknotes.isNotEmpty ? '$formattedDate - $tasknotes' : formattedDate,
                    style: SoftText.body(p, size: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _reloadEntries() async {
    try {
      final supabase = Supabase.instance.client;
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      final response = await supabase
          .from('workdiary')
          .select()
          .eq('staff_id', widget.staffId)
          .eq('date', dateStr)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _entries = List<Map<String, dynamic>>.from(response);
          _isLoadingNames = true;
        });
        await _loadClientAndJobNames();
      }
    } catch (e) {
      debugPrint('Error reloading entries: $e');
    }
  }

  void _addNewEntry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkLogEntryFormPage(
          selectedDate: widget.selectedDate,
          staffId: widget.staffId,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Reload entries to show the new one
        _reloadEntries();
      }
    });
  }

  int _calculateTotalMinutes() {
    int totalMinutes = 0;
    for (var entry in _entries) {
      final minutes = entry['minutes'] ?? 0;
      totalMinutes += minutes as int;
    }
    return totalMinutes;
  }

  String _formatMinutesToHours(int minutes) {
    if (minutes == 0) return '0m';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '${remainingMinutes}m';
    } else if (remainingMinutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${remainingMinutes}m';
    }
  }

  /// Format time value for display with AM/PM (handles both timestamp and time formats)
  /// Input could be: "2025-11-26T12:30:00", "12:30:00", "12:30:00+00", etc.
  /// Output: "12:30 PM" or "11:30 AM"
  String _formatTimeDisplay(dynamic timeValue) {
    if (timeValue == null) return '';

    String timeStr = timeValue.toString();

    // If it contains 'T', it's a full datetime - extract just the time part
    if (timeStr.contains('T')) {
      timeStr = timeStr.split('T')[1];
    }

    // Remove timezone info (+00, -05:30, Z, etc.)
    timeStr = timeStr.split('+')[0].split('Z')[0];
    if (timeStr.contains('-') && timeStr.indexOf('-') > 2) {
      // Handle negative timezone like -05:30 but not time like 12:30
      final parts = timeStr.split('-');
      if (parts.length > 1 && parts.last.contains(':')) {
        timeStr = parts[0];
      }
    }

    // Remove milliseconds if present (.000)
    timeStr = timeStr.split('.')[0];

    // Now we should have HH:mm:ss format - convert to 12-hour with AM/PM
    final timeParts = timeStr.split(':');
    if (timeParts.length >= 2) {
      int hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = timeParts[1];

      // Determine AM/PM
      final period = hour >= 12 ? 'PM' : 'AM';

      // Convert to 12-hour format
      if (hour == 0) {
        hour = 12; // Midnight is 12 AM
      } else if (hour > 12) {
        hour = hour - 12;
      }

      return '$hour:$minute $period';
    }

    return timeStr;
  }
}

/// Small soft stat tile (value + label) used in the summary row.
class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SoftIconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: SoftText.title(p, size: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(label, style: SoftText.caption(p)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
