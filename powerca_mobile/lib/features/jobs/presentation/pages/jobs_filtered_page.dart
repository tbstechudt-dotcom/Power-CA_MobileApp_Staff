import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../../../core/services/priority_service.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../../home/presentation/pages/work_log_entry_form_page.dart';
import 'job_detail_page.dart';

class JobsFilteredPage extends StatefulWidget {
  final Staff currentStaff;
  final String statusFilter;
  final List<Map<String, dynamic>> jobs;

  const JobsFilteredPage({
    super.key,
    required this.currentStaff,
    required this.statusFilter,
    required this.jobs,
  });

  @override
  State<JobsFilteredPage> createState() => _JobsFilteredPageState();
}

class _JobsFilteredPageState extends State<JobsFilteredPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<int> _priorityJobIds = {};

  @override
  void initState() {
    super.initState();
    _loadPriorityJobs();
  }

  /// Update status bar style based on theme
  void _updateStatusBarStyle(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }

  Future<void> _loadPriorityJobs() async {
    final jobIds = await PriorityService.getPriorityJobIds();
    if (mounted) {
      setState(() {
        _priorityJobIds = jobIds;
      });
    }
  }

  Future<void> _removeFromPriority(int jobId) async {
    await PriorityService.removePriorityJob(jobId);
    if (mounted) {
      setState(() {
        _priorityJobIds.remove(jobId);
        // Also remove from the jobs list for Priority page
        widget.jobs.removeWhere((job) => job['job_id'] == jobId);
      });
    }
  }

  // Check if this is the Priority page
  bool get _isPriorityPage => widget.statusFilter == 'Priority';

  Future<void> _togglePriority(int jobId) async {
    final isPriority = await PriorityService.togglePriorityJob(jobId);
    if (mounted) {
      setState(() {
        if (isPriority) {
          _priorityJobIds.add(jobId);
        } else {
          _priorityJobIds.remove(jobId);
        }
      });
    }
  }

  List<Map<String, dynamic>> get _filteredJobs {
    List<Map<String, dynamic>> filtered = widget.jobs;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((job) {
        final jobNo = (job['jobNo'] as String).toLowerCase();
        final company = (job['company'] as String).toLowerCase();
        final jobDesc = (job['job'] as String).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return jobNo.contains(query) || company.contains(query) || jobDesc.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(SoftPalette p, String status) {
    switch (status) {
      case 'Priority':
        return p.danger;
      case 'Waiting':
        return p.warning;
      case 'Planning':
        return p.accent;
      case 'Progress':
        return p.success;
      case 'Work Done':
        return p.isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
      case 'Delivery':
        return p.leave;
      default:
        return p.accent;
    }
  }

  void _openDailyEntry(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkLogEntryFormPage(
          selectedDate: DateTime.now(),
          staffId: widget.currentStaff.staffId,
          preSelectedJobId: job['job_id'] as int,
          preSelectedClientId: job['client_id'] as int?,
          preSelectedJobName: job['job'] as String?,
          preSelectedClientName: job['company'] as String?,
        ),
      ),
    );
  }

  /// "Jobs · Planning" (search pages read "Jobs · Search").
  String get _eyebrow {
    final f = widget.statusFilter;
    if (f.startsWith('Search')) return 'Jobs · Search';
    return 'Jobs · $f';
  }

  List<({String text, bool strong})> get _headline {
    final n = widget.jobs.length;
    final f = widget.statusFilter;
    final jobs = n == 1 ? 'job' : 'jobs';
    if (f.startsWith('Search')) {
      final q = f.replaceFirst(RegExp(r'^Search:\s*'), '');
      return [
        (text: '$n $jobs', strong: true),
        (text: ' match $q — tap one to open it.', strong: false),
      ];
    }
    if (_isPriorityPage) {
      return [
        (text: '$n starred', strong: true),
        (text: ' $jobs — tap one to open it.', strong: false),
      ];
    }
    if (f == 'All jobs') {
      return [
        (text: '$n open', strong: true),
        (text: ' $jobs — tap one to open it.', strong: false),
      ];
    }
    return [
      (text: '$n ${f.toLowerCase()}', strong: true),
      (text: ' $jobs — tap one to open it.', strong: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    // Update status bar style based on theme
    _updateStatusBarStyle(p.isDark);

    final filteredJobs = _filteredJobs;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: p.background,
      extendBody: true,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: HomeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back (left) and menu (right)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Row(
                  children: [
                    SoftIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      size: 44,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    SoftIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: 'Menu',
                      size: 44,
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                  ],
                ),
              ),

              // Eyebrow + headline
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeEyebrow(_eyebrow),
                    HomeInlineHeadline(parts: _headline, size: 23),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: softInputTextStyle(context),
                  decoration: softInputDecoration(
                    context,
                    hint: 'Search job no, client or description',
                    icon: Icons.search_rounded,
                    pill: true,
                    suffix: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Jobs List
              Expanded(
                child: filteredJobs.isEmpty
                    ? SoftMessage(
                        icon: Icons.work_outline_rounded,
                        title: 'No jobs found',
                        message: _searchQuery.isNotEmpty
                            ? 'Nothing matches "$_searchQuery"'
                            : 'No ${widget.statusFilter.toLowerCase()} jobs available',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: filteredJobs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final job = filteredJobs[index];
                          return _buildJobCard(job, context);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 1,
        currentStaff: widget.currentStaff,
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, BuildContext context) {
    final p = SoftPalette.of(context);
    final status = job['status'] as String;
    final statusColor = _getStatusColor(p, status);
    final jobId = job['job_id'] as int;
    final isPriority = _priorityJobIds.contains(jobId);
    final start = (job['startDate'] as String?) ?? '';
    final deadline = (job['deadline'] as String?) ?? '';

    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailPage(
              currentStaff: widget.currentStaff,
              job: job,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Client, job no + description, priority star
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['company'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SoftText.heading(p, size: 17).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${job['jobNo']} • ${job['job']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SoftText.caption(p, size: 12),
                    ),
                  ],
                ),
              ),
              if (!_isPriorityPage) ...[
                const SizedBox(width: 10),
                _PriorityToggle(
                  isPriority: isPriority,
                  onTap: () => _togglePriority(jobId),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Status / Start / Deadline
          Row(
            children: [
              Expanded(child: HomeStat(label: 'Status', value: status, dot: statusColor)),
              Expanded(child: HomeStat(label: 'Start', value: start.isEmpty ? '-' : start)),
              Expanded(child: HomeStat(label: 'Deadline', value: deadline.isEmpty ? '-' : deadline)),
            ],
          ),
          const SizedBox(height: 16),

          // Actions
          if (_isPriorityPage)
            // Priority page: Remove from priority, and Daily entry
            Row(
              children: [
                Expanded(
                  child: SoftPillButton(
                    label: 'Remove',
                    icon: Icons.star_outline_rounded,
                    variant: SoftPillVariant.danger,
                    height: 48,
                    onPressed: () => _removeFromPriority(jobId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftPillButton(
                    label: 'Daily entry',
                    icon: Icons.edit_calendar_outlined,
                    variant: SoftPillVariant.blue,
                    height: 48,
                    onPressed: () => _openDailyEntry(job),
                  ),
                ),
              ],
            )
          else
            SoftPillButton(
              label: 'Select for daily entry',
              icon: Icons.edit_calendar_outlined,
              variant: SoftPillVariant.blue,
              height: 48,
              onPressed: () => _openDailyEntry(job),
            ),
        ],
      ),
    );
  }
}

/// Round star button to toggle a job's priority.
class _PriorityToggle extends StatelessWidget {
  final bool isPriority;
  final VoidCallback onTap;

  const _PriorityToggle({required this.isPriority, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Tooltip(
      message: isPriority ? 'Remove from priority' : 'Mark as priority',
      child: Material(
        color: isPriority ? p.tint(p.danger) : p.surface,
        shape: CircleBorder(side: BorderSide(color: isPriority ? p.danger : p.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              isPriority ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 21,
              color: isPriority ? p.danger : p.ink,
            ),
          ),
        ),
      ),
    );
  }
}
