import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../../../core/services/priority_service.dart';
import '../../../../core/services/tab_data_cache.dart';
import '../../../auth/domain/entities/staff.dart';
import 'jobs_filtered_page.dart';


/// Soft palette tone for a job status label.
Color _jobStatusTone(SoftPalette p, String status) {
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

class JobsPage extends StatefulWidget {
  final Staff currentStaff;

  const JobsPage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  // Jobs from database
  List<Map<String, dynamic>> _allJobs = [];
  bool _isLoadingJobs = false;
  String _searchQuery = '';

  // Priority jobs
  Set<int> _priorityJobIds = {};
  int _priorityCount = 0;

  // Status configurations
  final List<Map<String, dynamic>> _statusConfigs = [
    {'status': 'Waiting', 'icon': Icons.hourglass_empty_rounded},
    {'status': 'Planning', 'icon': Icons.architecture_rounded},
    {'status': 'Progress', 'icon': Icons.rocket_launch_rounded},
    {'status': 'Work Done', 'icon': Icons.task_alt_rounded},
    {'status': 'Delivery', 'icon': Icons.local_shipping_rounded},
    // Closer status removed - not needed in jobs list
  ];

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _cacheKey =>
      'jobs:${widget.currentStaff.staffId}:${widget.currentStaff.orgId}:${widget.currentStaff.locId}';

  Future<void> _initializeAndLoad() async {
    // Show the last loaded jobs instantly; _loadJobs refreshes quietly.
    final cached = TabDataCache.read<List<Map<String, dynamic>>>(_cacheKey);
    if (cached != null) _allJobs = cached;

    // Set staff ID in PriorityService first
    debugPrint('JobsPage: Setting staff ID ${widget.currentStaff.staffId} in PriorityService');
    await PriorityService.setCurrentStaffId(widget.currentStaff.staffId);

    // Then load jobs and priority jobs
    _loadJobs();
    _loadPriorityJobs();
  }

  Future<void> _loadPriorityJobs() async {
    final jobIds = await PriorityService.getPriorityJobIds();
    if (mounted) {
      setState(() {
        _priorityJobIds = jobIds;
        _priorityCount = jobIds.length;
      });
    }
  }

  // Get priority jobs from all jobs
  List<Map<String, dynamic>> _getPriorityJobs() {
    return _allJobs.where((job) => _priorityJobIds.contains(job['job_id'] as int)).toList();
  }

  Future<void> _loadJobs() async {
    if (!mounted) return;
    // Spinner only when there's nothing to show yet.
    final hasCache = TabDataCache.read<List<Map<String, dynamic>>>(_cacheKey) != null;
    setState(() {
      _isLoadingJobs = !hasCache;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch jobs for current staff's organization and location
      // (sporg_id is not populated in synced data, so we filter by org_id and loc_id)
      // Exclude Closer jobs (status code 'C') - they should not appear in the app
      final jobsResponse = await supabase
          .from('jobshead')
          .select('job_id, job_uid, job_status, jobdate, targetdate, work_desc, client_id')
          .eq('org_id', widget.currentStaff.orgId)
          .eq('loc_id', widget.currentStaff.locId)
          .neq('job_status', 'C')
          .order('job_id', ascending: false);

      // Get unique client IDs
      final clientIds = jobsResponse
          .map((job) => job['client_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // Fetch client names for all client IDs
      Map<int, String> clientNames = {};
      if (clientIds.isNotEmpty) {
        final clientsResponse = await supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', clientIds);

        for (var client in clientsResponse) {
          clientNames[client['client_id'] as int] = client['clientname'] ?? 'Unknown Client';
        }
      }

      // Map job status codes to display names (Closer status 'C' excluded - not needed)
      final statusMap = {
        'W': 'Waiting',
        'P': 'Progress',
        'D': 'Delivery',
        'A': 'Planning',
        'G': 'Work Done',
        'L': 'Planning',
      };

      // Transform database records to UI format and deduplicate by job_id
      // (matching work_log_entry_form_page.dart behavior to ensure consistent counts)
      final Map<int, Map<String, dynamic>> uniqueJobsMap = {};

      for (var record in jobsResponse) {
        final jobId = record['job_id'] as int;

        // Skip if we already have this job (deduplicate)
        if (uniqueJobsMap.containsKey(jobId)) continue;

        final statusCode = record['job_status']?.toString().trim() ?? 'W';
        final status = statusMap[statusCode] ?? 'Waiting';
        final clientId = record['client_id'] as int?;
        final clientName = clientId != null ? (clientNames[clientId] ?? 'Unknown Client') : 'Unknown Client';

        uniqueJobsMap[jobId] = {
          'job_id': jobId,
          'client_id': clientId,
          'jobNo': record['job_uid'] ?? 'N/A',
          'status': status,
          'company': clientName,
          'job': record['work_desc'] ?? 'No description',
          'statusColor': _getStatusColor(status),
          'startDate': record['jobdate'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(record['jobdate']))
              : '',
          'deadline': record['targetdate'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(record['targetdate']))
              : '',
        };
      }

      final jobs = uniqueJobsMap.values.toList();
      debugPrint('DEBUG JobsPage: Loaded ${jobsResponse.length} records for staff ${widget.currentStaff.staffId}, deduplicated to ${jobs.length} unique jobs');

      // Debug: Count jobs by status
      final statusCounts = <String, int>{};
      for (var job in jobs) {
        final status = job['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      debugPrint('DEBUG JobsPage: Status counts: $statusCounts');

      TabDataCache.write(_cacheKey, jobs);
      if (!mounted) return;
      setState(() {
        _allJobs = jobs;
        _isLoadingJobs = false;
      });
    } catch (e) {
      debugPrint('Error loading jobs: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingJobs = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Waiting':
        return const Color(0xFFF59E0B);
      case 'Planning':
        return const Color(0xFF3B82F6);
      case 'Progress':
        return const Color(0xFF10B981);
      case 'Work Done':
        return const Color(0xFF0D9488);
      case 'Delivery':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7FFF);
    }
  }

  // Get jobs excluding 'Closer' status
  List<Map<String, dynamic>> get _activeJobs {
    return _allJobs.where((job) => job['status'] != 'Closer').toList();
  }

  int _getJobCountByStatus(String status) {
    return _allJobs.where((job) => job['status'] == status).length;
  }

  List<Map<String, dynamic>> _getJobsByStatus(String status) {
    return _allJobs.where((job) => job['status'] == status).toList();
  }

  void _navigateToFilteredJobs(String status) {
    final jobs = _getJobsByStatus(status);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobsFilteredPage(
          currentStaff: widget.currentStaff,
          statusFilter: status,
          jobs: jobs,
        ),
      ),
    ).then((_) {
      // Reload priority jobs when returning from filtered page
      _loadPriorityJobs();
    });
  }

  void _navigateToPriorityJobs() {
    final jobs = _getPriorityJobs();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobsFilteredPage(
          currentStaff: widget.currentStaff,
          statusFilter: 'Priority',
          jobs: jobs,
        ),
      ),
    ).then((_) {
      // Reload priority jobs when returning
      _loadPriorityJobs();
    });
  }

  // Search jobs by client name
  List<Map<String, dynamic>> _searchJobsByClient(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _allJobs.where((job) {
      // Exclude Closer jobs from search results
      if (job['status'] == 'Closer') return false;
      final company = (job['company'] as String?)?.toLowerCase() ?? '';
      return company.contains(lowerQuery);
    }).toList();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final searchResults = _searchJobsByClient(query);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobsFilteredPage(
          currentStaff: widget.currentStaff,
          statusFilter: 'Search: "$query"',
          jobs: searchResults,
        ),
      ),
    ).then((_) {
      // Reload priority jobs when returning
      _loadPriorityJobs();
    });
  }


  void _navigateToAllJobs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobsFilteredPage(
          currentStaff: widget.currentStaff,
          statusFilter: 'All jobs',
          jobs: _activeJobs,
        ),
      ),
    ).then((_) => _loadPriorityJobs());
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    // Update status bar style based on theme
    _updateStatusBarStyle(p.isDark);

    final total = _activeJobs.length;
    final inProgress = _getJobCountByStatus('Progress');
    final planning = _getJobCountByStatus('Planning');
    final active = inProgress + planning;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: p.background,
      extendBody: true,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: HomeBackground(
        child: Column(
          children: [
            AppHeader(
              currentStaff: widget.currentStaff,
              homeStyle: true,
              showPlace: false,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),

            // Content
            Expanded(
              child: _isLoadingJobs
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadJobs,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        children: [
                          const HomeEyebrow('My jobs'),
                          HomeInlineHeadline(
                            parts: [
                              (text: 'You have ', strong: false),
                              (text: '$active active ${active == 1 ? 'job' : 'jobs'}', strong: true),
                              (text: ', ', strong: false),
                              (text: '$inProgress in progress', strong: true),
                              (text: '.', strong: false),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Client Search Field
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            onSubmitted: (_) => _performSearch(),
                            style: softInputTextStyle(context),
                            decoration: softInputDecoration(
                              context,
                              hint: 'Search jobs by client name',
                              icon: Icons.search_rounded,
                              pill: true,
                              suffix: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: p.muted,
                                        size: 20,
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: _performSearch,
                                      icon: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: p.ink,
                                        size: 22,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // By status
                          HomeSectionCard(
                            title: 'By status',
                            subtitle: 'Tap a status to see its jobs',
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
                            child: Column(
                              children: [
                                HomeStatusRow(
                                  first: true,
                                  color: p.danger,
                                  label: 'Priority',
                                  caption: 'Jobs you starred',
                                  count: '$_priorityCount',
                                  onTap: _navigateToPriorityJobs,
                                ),
                                for (final config in _statusConfigs)
                                  HomeStatusRow(
                                    color: _jobStatusTone(p, config['status'] as String),
                                    label: config['status'] as String,
                                    count: '${_getJobCountByStatus(config['status'] as String)}',
                                    onTap: () => _navigateToFilteredJobs(config['status'] as String),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Job overview
                          HomeSectionCard(
                            title: 'Job overview',
                            subtitle: '$total open ${total == 1 ? 'job' : 'jobs'} • $planning planning',
                            trailing: HomeRoundAction(
                              icon: Icons.north_east_rounded,
                              tooltip: 'All jobs',
                              onTap: _navigateToAllJobs,
                            ),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(child: HomeStat(label: 'Total', value: '$total')),
                                    Expanded(child: HomeStat(label: 'Active', value: '$active')),
                                    Expanded(
                                      child: HomeStat(
                                        label: 'Priority',
                                        value: '$_priorityCount',
                                        dot: p.danger,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                HomeSegmentBar(
                                  segments: [
                                    for (final config in _statusConfigs)
                                      (
                                        value: _getJobCountByStatus(config['status'] as String).toDouble(),
                                        color: _jobStatusTone(p, config['status'] as String),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('By status', style: SoftText.caption(p, size: 12)),
                                    const Spacer(),
                                    Text(
                                      '$total ${total == 1 ? 'job' : 'jobs'}',
                                      style: SoftText.caption(p, size: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 1,
        currentStaff: widget.currentStaff,
      ),
    );
  }
}
