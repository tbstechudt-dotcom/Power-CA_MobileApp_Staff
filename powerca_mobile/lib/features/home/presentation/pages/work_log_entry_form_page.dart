import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/work_hours_provider.dart';
import '../../../../core/services/priority_service.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import 'work_log_list_page.dart';

class WorkLogEntryFormPage extends StatefulWidget {
  final DateTime selectedDate;
  final int staffId;
  final int? preSelectedJobId;
  final int? preSelectedClientId;
  final String? preSelectedJobName;
  final String? preSelectedClientName;
  final int? preSelectedTaskId;
  final String? preSelectedTaskName;

  const WorkLogEntryFormPage({
    super.key,
    required this.selectedDate,
    required this.staffId,
    this.preSelectedJobId,
    this.preSelectedClientId,
    this.preSelectedJobName,
    this.preSelectedClientName,
    this.preSelectedTaskId,
    this.preSelectedTaskName,
  });

  @override
  State<WorkLogEntryFormPage> createState() => _WorkLogEntryFormPageState();
}

class _WorkLogEntryFormPageState extends State<WorkLogEntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _descriptionScrollController = ScrollController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  int? _selectedClientId;
  int? _selectedJobId;
  int? _selectedTaskId;
  String? _selectedRecurrent;
  int? _selectedRecperId; // recper_id from mbrecurrent_periods table

  // Recurrent options loaded from database
  List<Map<String, dynamic>> _recurrentPeriods = [];

  // Staff's con_id (from mbstaff table, NOT from job)
  int? _staffConId;

  // Work hours input mode: true = From/To Time, false = Hours/Minutes
  bool _useTimeRangeMode = true;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _allClients = []; // All clients for search in priority dialog
  Map<int, Map<int, Map<String, dynamic>>> _jobsByClient = {};
  List<Map<String, dynamic>> _tasks = [];

  bool _isLoading = false;
  bool _isSubmitting = false;

  // Priority filtering
  Set<int> _priorityJobIds = {};
  bool _hasPriorities = false;

  // All jobs for priority selection
  List<Map<String, dynamic>> _allJobs = [];
  Set<int> _selectedPriorityJobIds = {};

  bool _hasLoadedDefaultMode = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _loadFormData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load default work hours mode from settings (only once)
    if (!_hasLoadedDefaultMode) {
      final workHoursProvider = Provider.of<WorkHoursProvider>(context, listen: false);
      if (workHoursProvider.isInitialized) {
        _useTimeRangeMode = workHoursProvider.isFromToTimeDefault;
        _hasLoadedDefaultMode = true;
      } else {
        // Listen for provider initialization
        workHoursProvider.addListener(_onWorkHoursProviderChanged);
      }
    }
  }

  void _onWorkHoursProviderChanged() {
    if (!_hasLoadedDefaultMode) {
      final workHoursProvider = Provider.of<WorkHoursProvider>(context, listen: false);
      if (workHoursProvider.isInitialized) {
        setState(() {
          _useTimeRangeMode = workHoursProvider.isFromToTimeDefault;
          _hasLoadedDefaultMode = true;
        });
        workHoursProvider.removeListener(_onWorkHoursProviderChanged);
      }
    }
  }

  @override
  void dispose() {
    // Clean up listener if still attached
    if (!_hasLoadedDefaultMode) {
      try {
        final workHoursProvider = Provider.of<WorkHoursProvider>(context, listen: false);
        workHoursProvider.removeListener(_onWorkHoursProviderChanged);
      } catch (_) {
        // Context may not be valid during dispose
      }
    }
    _descriptionController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // STEP 0: Load priority job IDs first
      final priorityJobIds = await PriorityService.getPriorityJobIds();
      _priorityJobIds = priorityJobIds;
      _hasPriorities = priorityJobIds.isNotEmpty;

      // STEP 0.5: Load staff's con_id from mbstaff (for workdiary insert)
      final staffResponse = await supabase
          .from('mbstaff')
          .select('con_id')
          .eq('staff_id', widget.staffId)
          .maybeSingle();
      if (staffResponse != null) {
        _staffConId = staffResponse['con_id'] as int?;
      }

      // STEP 1: Load jobs assigned to current staff from jobshead
      // Note: work_desc maps to job_name
      // Load jobs from jobshead (sporg_id is not populated, so we don't filter by it)
      // Exclude Closer jobs (status code 'C') - they should not appear in the app
      final jobsResponse = await supabase
          .from('jobshead')
          .select('job_id, job_uid, work_desc, client_id, job_status, org_id, loc_id, con_id')
          .neq('job_status', 'C')
          .order('work_desc')
          .limit(50000); // Increase limit to get all jobs

      // Store all jobs for priority selection dialog (deduplicated by job_id)
      final Map<int, Map<String, dynamic>> uniqueJobsMap = {};
      final Set<int> allClientIds = {}; // Collect all client IDs from jobs
      for (var job in jobsResponse) {
        final jobId = job['job_id'] as int;
        if (!uniqueJobsMap.containsKey(jobId)) {
          uniqueJobsMap[jobId] = job;
        }
        // Collect client IDs for loading all clients
        if (job['client_id'] != null) {
          allClientIds.add(job['client_id'] as int);
        }
      }
      _allJobs = uniqueJobsMap.values.toList();
      _selectedPriorityJobIds = Set<int>.from(_priorityJobIds);
      print('DEBUG WorkLogForm: Loaded ${jobsResponse.length} jobs for staff ${widget.staffId}, deduplicated to ${_allJobs.length} unique jobs');

      // Debug: Count jobs by status (to compare with jobs_page.dart)
      final statusCounts = <String, int>{};
      for (var job in _allJobs) {
        final statusCode = job['job_status']?.toString().trim() ?? 'W';
        final statusName = _getStatusName(statusCode);
        statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;
      }
      print('DEBUG WorkLogForm: Status counts: $statusCounts');

      // Load ALL clients for search functionality in priority dialog
      if (allClientIds.isNotEmpty) {
        final allClientsResponse = await supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', allClientIds.toList())
            .order('clientname');
        _allClients = List<Map<String, dynamic>>.from(allClientsResponse);
        print('DEBUG: Loaded ${_allClients.length} clients for search');
      }

      // STEP 1.5: Filter jobs to priority jobs only if priorities are set
      // BUT: Skip priority filtering if a job was pre-selected from Jobs page
      // (user explicitly chose this job, so show it regardless of priority status)
      final bool hasPreSelection = widget.preSelectedJobId != null && widget.preSelectedClientId != null;

      List<dynamic> filteredJobsResponse;
      if (_hasPriorities && !hasPreSelection) {
        filteredJobsResponse = jobsResponse.where((job) {
          final jobId = job['job_id'] as int;
          return _priorityJobIds.contains(jobId);
        }).toList();
        print('DEBUG: Filtered to ${filteredJobsResponse.length} priority jobs out of ${jobsResponse.length} total jobs');
      } else {
        filteredJobsResponse = jobsResponse;
        if (hasPreSelection) {
          print('DEBUG: Pre-selection mode - showing all ${jobsResponse.length} jobs (bypassing priority filter)');
        } else {
          print('DEBUG: No priorities set, showing all ${jobsResponse.length} jobs');
        }
      }

      // STEP 2: Group jobs by client_id FIRST, then deduplicate within each client
      // This ensures we don't lose jobs that appear with different client_ids
      final Map<int, Map<int, Map<String, dynamic>>> jobsByClient = {};

      for (var job in filteredJobsResponse) {
        final clientId = job['client_id'];
        final jobId = job['job_id'] as int;

        if (clientId != null) {
          // Initialize client map if not exists
          if (!jobsByClient.containsKey(clientId)) {
            jobsByClient[clientId] = {};
          }

          // Add job to this client (deduplicate by job_id within client)
          if (!jobsByClient[clientId]!.containsKey(jobId)) {
            jobsByClient[clientId]![jobId] = job;
          }
        }
      }

      // STEP 3: Extract unique client IDs
      final uniqueClientIds = jobsByClient.keys.toList();

      // STEP 4: Load ONLY clients that have jobs (filtered by priority)
      // Note: Column is 'clientname' (one word), NOT 'client_name'
      List<Map<String, dynamic>> clientsResponse = [];
      if (uniqueClientIds.isNotEmpty) {
        clientsResponse = await supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', uniqueClientIds)
            .order('clientname');
      }

      setState(() {
        _clients = List<Map<String, dynamic>>.from(clientsResponse);
        _jobsByClient = jobsByClient; // Store grouped jobs
        _tasks = []; // Tasks will be loaded when job is selected
        _isLoading = false;
      });

      // Handle pre-selection if job/client was passed from Jobs page
      if (widget.preSelectedClientId != null && widget.preSelectedJobId != null) {
        // Set the pre-selected client
        _selectedClientId = widget.preSelectedClientId;
        // Set the pre-selected job
        _selectedJobId = widget.preSelectedJobId;
        // Load tasks for the pre-selected job
        await _loadTasksForJob(widget.preSelectedJobId!);
        // Load recurrent periods for the pre-selected job
        await _loadRecurrentPeriodsForJob(widget.preSelectedJobId!);

        // Handle task pre-selection if task was also passed (from Job Detail page)
        if (widget.preSelectedTaskId != null) {
          // Verify the task exists in the loaded tasks list
          final taskExists = _tasks.any((task) => task['task_id'] == widget.preSelectedTaskId);
          if (taskExists) {
            _selectedTaskId = widget.preSelectedTaskId;
            print('DEBUG: Pre-selected task ${widget.preSelectedTaskId} (${widget.preSelectedTaskName})');
          } else {
            print('DEBUG: Pre-selected task ${widget.preSelectedTaskId} not found in tasks list');
          }
        }
        print('DEBUG: Pre-selected client ${widget.preSelectedClientId}, job ${widget.preSelectedJobId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading form data: $e')),
        );
      }
    }
  }

  /// Load tasks for the selected job from jobtasks table
  Future<void> _loadTasksForJob(int jobId) async {
    try {
      final supabase = Supabase.instance.client;

      // Load tasks from jobtasks table for the selected job
      // Note: Column is 'task_desc' (NOT 'task_name')
      final tasksResponse = await supabase
          .from('jobtasks')
          .select('jt_id, task_id, task_desc, job_id')
          .eq('job_id', jobId)
          .order('task_desc');

      setState(() {
        _tasks = List<Map<String, dynamic>>.from(tasksResponse);
        _selectedTaskId = null; // Reset selected task when job changes
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    }
  }

  /// Load recurrent periods for the selected job from mbrecurrent_periods table
  Future<void> _loadRecurrentPeriodsForJob(int jobId) async {
    try {
      final supabase = Supabase.instance.client;

      // Load recurrent periods ONLY for this specific job_id
      final recurrentResponse = await supabase
          .from('mbrecurrent_periods')
          .select('recper_id, recur_period, recper_order')
          .eq('job_id', jobId)
          .order('recper_order');

      final loadedPeriods = List<Map<String, dynamic>>.from(recurrentResponse);

      setState(() {
        _recurrentPeriods = loadedPeriods;

        // Auto-select if there's exactly one recurrent period
        if (loadedPeriods.length == 1) {
          final period = loadedPeriods.first;
          // Use recper_id as string (matches dropdown item value)
          _selectedRecurrent = period['recper_id']?.toString();
          _selectedRecperId = period['recper_id'] as int?;
        } else {
          // Multiple options or none - leave for user to select
          _selectedRecurrent = null;
          _selectedRecperId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading recurrent periods: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    // Get current date at midnight (00:00:00) for firstDate
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today, // Only allow current date and future dates
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isFromTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFromTime) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  double _calculateHours() {
    if (_useTimeRangeMode) {
      // From/To Time mode
      if (_fromTime == null || _toTime == null) return 0.0;

      final from = _fromTime!.hour + _fromTime!.minute / 60.0;
      final to = _toTime!.hour + _toTime!.minute / 60.0;

      // Handle overnight work (when toTime is past midnight)
      if (to > from) {
        return to - from;
      } else if (to < from) {
        // Overnight work: add 24 hours to toTime
        return (24.0 - from) + to;
      } else {
        return 0.0; // Same time = 0 hours
      }
    } else {
      // Hours/Minutes direct input mode
      final hours = int.tryParse(_hoursController.text) ?? 0;
      final minutes = int.tryParse(_minutesController.text) ?? 0;
      return hours + minutes / 60.0;
    }
  }

  /// Get total minutes from current input mode
  int _getTotalMinutes() {
    if (_useTimeRangeMode) {
      return (_calculateHours() * 60).round();
    } else {
      final hours = int.tryParse(_hoursController.text) ?? 0;
      final minutes = int.tryParse(_minutesController.text) ?? 0;
      return (hours * 60) + minutes;
    }
  }

  /// Check if work hours are valid based on current input mode
  bool _hasValidWorkHours() {
    if (_useTimeRangeMode) {
      return _fromTime != null && _toTime != null;
    } else {
      final hours = int.tryParse(_hoursController.text) ?? 0;
      final minutes = int.tryParse(_minutesController.text) ?? 0;
      return hours > 0 || minutes > 0;
    }
  }

  /// Check if the new time range overlaps with any existing work entries
  /// Returns the overlapping entry details if overlap found, null otherwise
  Future<Map<String, dynamic>?> _checkTimeOverlap() async {
    if (_selectedDate == null || _fromTime == null || _toTime == null) {
      return null;
    }

    try {
      final supabase = Supabase.instance.client;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // Convert new entry times to minutes for comparison
      final newFromMinutes = _fromTime!.hour * 60 + _fromTime!.minute;
      final newToMinutes = _toTime!.hour * 60 + _toTime!.minute;

      // Query existing entries for the same staff and date
      final existingEntries = await supabase
          .from('workdiary')
          .select('wd_id, timefrom, timeto, job_id')
          .eq('staff_id', widget.staffId)
          .eq('date', dateStr);

      // Check for overlaps
      for (final entry in existingEntries) {
        final existingFrom = entry['timefrom'];
        final existingTo = entry['timeto'];

        if (existingFrom == null || existingTo == null) continue;

        // Parse existing times (format: "HH:mm:ss" or "HH:mm:ss+00")
        int existingFromMinutes;
        int existingToMinutes;

        try {
          // Handle time format - could be "17:00:00" or "2025-11-26T17:00:00"
          String fromTimeStr = existingFrom.toString();
          String toTimeStr = existingTo.toString();

          // If it contains 'T', it's a full datetime - extract just the time part
          if (fromTimeStr.contains('T')) {
            fromTimeStr = fromTimeStr.split('T')[1].split('+')[0].split('.')[0];
          }
          if (toTimeStr.contains('T')) {
            toTimeStr = toTimeStr.split('T')[1].split('+')[0].split('.')[0];
          }

          // Remove any timezone info
          fromTimeStr = fromTimeStr.split('+')[0].split('-')[0];
          toTimeStr = toTimeStr.split('+')[0].split('-')[0];

          final fromParts = fromTimeStr.split(':');
          final toParts = toTimeStr.split(':');

          existingFromMinutes = int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
          existingToMinutes = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);
        } catch (e) {
          debugPrint('Error parsing time: $e');
          continue;
        }

        // Check for overlap: two ranges overlap if one starts before the other ends
        // Overlap occurs when: newFrom < existingTo AND newTo > existingFrom
        if (newFromMinutes < existingToMinutes && newToMinutes > existingFromMinutes) {
          // Format times for display
          final existingFromFormatted =
              '${(existingFromMinutes ~/ 60).toString().padLeft(2, '0')}:${(existingFromMinutes % 60).toString().padLeft(2, '0')}';
          final existingToFormatted =
              '${(existingToMinutes ~/ 60).toString().padLeft(2, '0')}:${(existingToMinutes % 60).toString().padLeft(2, '0')}';

          return {
            'fromTime': existingFromFormatted,
            'toTime': existingToFormatted,
            'job_id': entry['job_id'],
          };
        }
      }

      return null; // No overlap found
    } catch (e) {
      debugPrint('Error checking time overlap: $e');
      return null; // On error, allow the entry (let server handle it)
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    // Validate work hours based on input mode
    if (!_hasValidWorkHours()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useTimeRangeMode
              ? 'Please select from and to times'
              : 'Please enter hours or minutes'),
        ),
      );
      return;
    }

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client')),
      );
      return;
    }

    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a job')),
      );
      return;
    }

    if (_selectedRecurrent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a recurrence')),
      );
      return;
    }

    if (_selectedTaskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a task')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Check for time overlap with existing entries (only for time range mode)
    if (_useTimeRangeMode) {
      final overlap = await _checkTimeOverlap();
      if (overlap != null) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Time overlap! You already have an entry from ${overlap['fromTime']} to ${overlap['toTime']}',
              ),
              backgroundColor: SoftPalette.of(context).warning,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    try {
      final supabase = Supabase.instance.client;
      final minutes = _getTotalMinutes();

      // IMPORTANT: workdiary columns are: date, minutes, tasknotes (NOT wd_date, actual_hrs, wd_notes)
      // Format times as TIME ONLY (HH:mm:ss) - timefrom/timeto columns are time type
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // Only set time strings if using time range mode
      String? fromTimeStr;
      String? toTimeStr;
      if (_useTimeRangeMode && _fromTime != null && _toTime != null) {
        fromTimeStr = '${_fromTime!.hour.toString().padLeft(2, '0')}:${_fromTime!.minute.toString().padLeft(2, '0')}:00';
        toTimeStr = '${_toTime!.hour.toString().padLeft(2, '0')}:${_toTime!.minute.toString().padLeft(2, '0')}:00';
      }

      // If recper_id is negative, it's a fallback option - save null
      final recperId = (_selectedRecperId != null && _selectedRecperId! > 0)
          ? _selectedRecperId
          : null;

      // Get org_id, loc_id from the selected job (con_id comes from staff)
      final selectedJob = _jobsByClient[_selectedClientId]?[_selectedJobId];
      final orgId = selectedJob?['org_id'];
      final locId = selectedJob?['loc_id'];

      await supabase.from('workdiary').insert({
        'staff_id': widget.staffId,
        'job_id': _selectedJobId,
        'client_id': _selectedClientId,
        'task_id': _selectedTaskId,
        'org_id': orgId, // From selected job
        'loc_id': locId, // From selected job
        'con_id': _staffConId, // From logged-in staff (mbstaff.con_id)
        'date': dateStr, // Column is 'date'
        'tasknotes': _descriptionController.text.trim(), // Column is 'tasknotes'
        'minutes': minutes, // Column is 'minutes' (integer)
        'timefrom': fromTimeStr, // From time (null if using hours/minutes mode)
        'timeto': toTimeStr, // To time (null if using hours/minutes mode)
        'recper_id': recperId, // recper_id from mbrecurrent_periods table (null if fallback option)
        'source': 'M', // Mobile source
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Work log entry created successfully'),
            backgroundColor: SoftPalette.of(context).success,
          ),
        );

        // Fetch all entries for the selected date to show in the list
        final entriesResponse = await supabase
            .from('workdiary')
            .select()
            .eq('staff_id', widget.staffId)
            .eq('date', dateStr)
            .order('created_at', ascending: false);

        final entries = List<Map<String, dynamic>>.from(entriesResponse);

        // Navigate to Work Log List page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WorkLogListPage(
                selectedDate: _selectedDate!,
                entries: entries,
                staffId: widget.staffId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating work log: $e'),
            backgroundColor: SoftPalette.of(context).danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final headerDate = _selectedDate ?? DateTime.now();

    Widget card(List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SoftCard(
            radius: 26,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );

    return Scaffold(
      backgroundColor: p.background,
      body: HomeBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header: back, title + date, Priority pill
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    SoftIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Log work', style: SoftText.heading(p, size: 19)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEEE, d MMMM').format(headerDate),
                            style: SoftText.caption(p, size: 12.5),
                          ),
                        ],
                      ),
                    ),
                    HomeOutlinePill(
                      label: _hasPriorities
                          ? 'Priority · ${_priorityJobIds.length}'
                          : 'Priority',
                      icon: _hasPriorities ? Icons.star_rounded : Icons.star_outline_rounded,
                      onTap: _isLoading ? null : _showPrioritySelectionDialog,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Card 1: date and work hours
                              card([
                                const SoftFieldLabel('Date', required: true),
                                SoftPickerField(
                                  value: _selectedDate != null
                                      ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)
                                      : null,
                                  placeholder: 'Select a date',
                                  icon: Icons.calendar_today_outlined,
                                  filled: true,
                                  trailing: false,
                                  onTap: _selectDate,
                                ),
                                const SizedBox(height: 18),

                                // Work hours title with info icon + mode toggle
                                _buildWorkHoursSectionTitle(),
                                const SizedBox(height: 14),
                                // Either a time range or hours / minutes
                                if (_useTimeRangeMode)
                                  Row(
                                    children: [
                                      Expanded(child: _buildTimeSelector(true)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildTimeSelector(false)),
                                    ],
                                  )
                                else
                                  _buildHoursMinutesInput(),
                                if (_hasValidWorkHours()) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: SoftStatusPill(
                                      label:
                                          'Total Hours: ${_formatMinutesToHours(_getTotalMinutes())}',
                                      color: p.accent,
                                      icon: Icons.timer_outlined,
                                    ),
                                  ),
                                ],
                              ]),

                              // Card 2: client, job, recurrence, task
                              card([
                                const SoftFieldLabel('Client', required: true),
                                _buildClientDropdown(),
                                const SizedBox(height: 18),
                                SoftFieldLabel(
                                  'Job',
                                  required: true,
                                  enabled: _selectedClientId != null,
                                ),
                                _buildJobDropdown(),
                                const SizedBox(height: 18),
                                SoftFieldLabel(
                                  'Recurrent',
                                  required: true,
                                  enabled: _selectedJobId != null && _recurrentPeriods.isNotEmpty,
                                ),
                                _buildRecurrentDropdown(),
                                const SizedBox(height: 18),
                                SoftFieldLabel(
                                  'Task',
                                  required: true,
                                  enabled: _selectedRecurrent != null,
                                ),
                                _buildTaskDropdown(),
                              ]),

                              // Card 3: description
                              card([
                                SoftFieldLabel(
                                  'Work description',
                                  required: true,
                                  hint: '${_descriptionController.text.length}/200',
                                ),
                                _buildDescriptionField(),
                              ]),
                            ],
                          ),
                        ),
                      ),
              ),

              // Save button
              if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: SoftPillButton(
                    label: 'Save work log',
                    variant: SoftPillVariant.blue,
                    height: 54,
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submitForm,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkHoursSectionTitle() {
    final p = SoftPalette.of(context);

    return Row(
        children: [
          Text(
            'Work hours',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: p.ink,
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'You can change the default\ninput method in Settings',
            preferBelow: false,
            verticalOffset: 20,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.pill,
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: SoftText.body(p, size: 12, color: p.onPill),
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 3),
            child: Icon(Icons.info_outline_rounded, size: 16, color: p.muted),
          ),
          const Spacer(),
          _buildWorkHoursModeToggle(),
        ],
    );
  }

  /// Segmented toggle between Time Range and Hours/Minutes input modes.
  /// The default option (from settings) appears first.
  Widget _buildWorkHoursModeToggle() {
    final p = SoftPalette.of(context);
    final workHoursProvider = Provider.of<WorkHoursProvider>(context, listen: false);

    // Check which mode is the default from settings
    final isHoursMinutesDefault = workHoursProvider.isHoursMinutesDefault;

    final fromToChip = _ModeChip(
      label: 'From–To',
      icon: Icons.schedule_rounded,
      selected: _useTimeRangeMode,
      onTap: () => setState(() => _useTimeRangeMode = true),
    );

    final hoursMinChip = _ModeChip(
      label: 'Hrs/Min',
      icon: Icons.timer_outlined,
      selected: !_useTimeRangeMode,
      onTap: () => setState(() => _useTimeRangeMode = false),
    );

    // Order chips based on default setting - default option comes first
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: softFieldFill(p),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isHoursMinutesDefault
            ? [hoursMinChip, fromToChip]
            : [fromToChip, hoursMinChip],
      ),
    );
  }

  /// Build Hours and Minutes direct input fields
  Widget _buildHoursMinutesInput() {
    return Row(
      children: [
        Expanded(
          child: _buildNumberInput(
            label: 'Hours',
            controller: _hoursController,
            max: 12,
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildNumberInput(
            label: 'Minutes',
            controller: _minutesController,
            max: 59,
            icon: Icons.timer_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildNumberInput({
    required String label,
    required TextEditingController controller,
    required int max,
    required IconData icon,
  }) {
    final p = SoftPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftFieldLabel(label, required: true),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          cursorColor: p.ink,
          maxLength: 2,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _RangeTextInputFormatter(min: 0, max: max),
          ],
          style: softInputTextStyle(context),
          decoration: softInputDecoration(
            context,
            hint: '0',
            icon: icon,
            counterText: '',
            filled: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(bool isFromTime) {
    final time = isFromTime ? _fromTime : _toTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftFieldLabel(isFromTime ? 'Start' : 'End', required: true),
        SoftPickerField(
          value: time?.format(context),
          placeholder: 'Select time',
          icon: Icons.access_time_rounded,
          filled: true,
          trailing: false,
          onTap: () => _selectTime(isFromTime),
        ),
      ],
    );
  }

  Widget _buildClientDropdown() {
    // Get selected client name for display
    String? selectedClientName;
    if (_selectedClientId != null) {
      final selectedClient = _clients.firstWhere(
        (c) => c['client_id'] == _selectedClientId,
        orElse: () => {'clientname': null},
      );
      selectedClientName = selectedClient['clientname'] as String?;
    }

    return SoftPickerField(
      value: selectedClientName,
      placeholder: 'Select a client',
      icon: Icons.apartment_rounded,
      filled: true,
      onTap: () => _showClientSearchDialog(),
    );
  }

  /// Shared layout for the searchable client / job / task sheets:
  /// title + count, search field, then the list (or an empty message).
  Widget _buildSearchSheetBody({
    required String title,
    required String countLabel,
    required String searchHint,
    required TextEditingController searchController,
    required String searchQuery,
    required ValueChanged<String> onQueryChanged,
    required String emptyText,
    required ScrollController scrollController,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    double bottomPadding = 16,
  }) {
    final p = SoftPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(child: Text(title, style: SoftText.title(p, size: 20))),
              Text(countLabel, style: SoftText.caption(p)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: searchController,
            autofocus: true,
            cursorColor: p.ink,
            onChanged: onQueryChanged,
            style: softInputTextStyle(context),
            decoration: softInputDecoration(
              context,
              hint: searchHint,
              icon: Icons.search_rounded,
              pill: true,
              dense: true,
              suffix: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                      onPressed: () {
                        searchController.clear();
                        onQueryChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: itemCount == 0
              ? SoftMessage(icon: Icons.search_off_rounded, title: emptyText)
              : ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding),
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                ),
        ),
      ],
    );
  }

  /// Show searchable client selection dialog
  Future<void> _showClientSearchDialog() async {
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter clients based on search query
            var filteredClients = searchQuery.isEmpty
                ? _clients
                : _clients.where((client) {
                    final clientName = (client['clientname'] ?? '').toString().toLowerCase();
                    return clientName.contains(searchQuery.toLowerCase());
                  }).toList();

            // Sort alphabetically by client name
            filteredClients = List.from(filteredClients)
              ..sort((a, b) => (a['clientname'] ?? '').toString().toLowerCase()
                  .compareTo((b['clientname'] ?? '').toString().toLowerCase()));

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Stack(
                  children: [
                    _buildSearchSheetBody(
                      title: 'Select Client',
                      countLabel: '${filteredClients.length} clients',
                      searchHint: 'Search client name...',
                      searchController: searchController,
                      searchQuery: searchQuery,
                      onQueryChanged: (value) => setModalState(() => searchQuery = value),
                      emptyText: 'No clients found',
                      scrollController: scrollController,
                      itemCount: filteredClients.length,
                      // Leave room for the floating Priority button
                      bottomPadding: 88,
                      itemBuilder: (context, index) {
                        final client = filteredClients[index];
                        final clientId = client['client_id'] as int;
                        final clientName = client['clientname'] ?? 'Unknown Client';
                        final isSelected = clientId == _selectedClientId;

                        return _PickerTile(
                          title: clientName,
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedClientId = clientId;
                              _selectedJobId = null;
                              _selectedTaskId = null;
                              _tasks = [];
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                    // Floating button to jump to the priority selection sheet.
                    // Centered at the bottom of the sheet, full-width minus margins.
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 16,
                      child: SoftPillButton(
                        label: 'Priority',
                        icon: Icons.star_rounded,
                        onPressed: () {
                          Navigator.pop(context);
                          _showPrioritySelectionDialog();
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildJobDropdown() {
    final isEnabled = _selectedClientId != null;

    // Get jobs for the selected client from the pre-grouped structure
    final filteredJobs = _selectedClientId != null && _jobsByClient.containsKey(_selectedClientId)
        ? _jobsByClient[_selectedClientId]!.values.toList()
        : <Map<String, dynamic>>[];

    // Get selected job name for display
    String? selectedJobDisplay;
    if (_selectedJobId != null && filteredJobs.isNotEmpty) {
      final selectedJob = filteredJobs.firstWhere(
        (j) => j['job_id'] == _selectedJobId,
        orElse: () => {'work_desc': null, 'job_uid': null},
      );
      if (selectedJob['work_desc'] != null) {
        selectedJobDisplay = '${selectedJob['job_uid'] ?? 'N/A'} - ${selectedJob['work_desc']}';
      }
    }

    // Determine hint text
    String hintText;
    if (!isEnabled) {
      hintText = 'Select a client first';
    } else if (filteredJobs.isEmpty) {
      hintText = 'No jobs available';
    } else {
      hintText = 'Select a job';
    }

    return SoftPickerField(
      value: selectedJobDisplay,
      placeholder: hintText,
      icon: Icons.work_outline_rounded,
      filled: true,
      enabled: isEnabled,
      onTap: !isEnabled || filteredJobs.isEmpty
          ? null
          : () => _showJobSearchDialog(filteredJobs),
    );
  }

  /// Show searchable job selection dialog
  Future<void> _showJobSearchDialog(List<Map<String, dynamic>> jobs) async {
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter jobs based on search query
            var filteredJobs = searchQuery.isEmpty
                ? jobs
                : jobs.where((job) {
                    final jobDesc = (job['work_desc'] ?? '').toString().toLowerCase();
                    final jobUid = (job['job_uid'] ?? '').toString().toLowerCase();
                    final query = searchQuery.toLowerCase();
                    return jobDesc.contains(query) || jobUid.contains(query);
                  }).toList();

            // Sort alphabetically by job description
            filteredJobs = List.from(filteredJobs)
              ..sort((a, b) => (a['work_desc'] ?? '').toString().toLowerCase()
                  .compareTo((b['work_desc'] ?? '').toString().toLowerCase()));

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return _buildSearchSheetBody(
                  title: 'Select Job',
                  countLabel: '${filteredJobs.length} jobs',
                  searchHint: 'Search job name or ID...',
                  searchController: searchController,
                  searchQuery: searchQuery,
                  onQueryChanged: (value) => setModalState(() => searchQuery = value),
                  emptyText: 'No jobs found',
                  scrollController: scrollController,
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    final jobId = job['job_id'] as int;
                    final jobUid = job['job_uid'] ?? 'N/A';
                    final jobDesc = job['work_desc'] ?? 'Unknown Job';
                    final isSelected = jobId == _selectedJobId;

                    return _PickerTile(
                      title: jobDesc,
                      subtitle: jobUid,
                      titleMaxLines: 2,
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedJobId = jobId;
                          _selectedTaskId = null;
                          _selectedRecurrent = null;
                          _selectedRecperId = null;
                          _tasks = [];
                          _recurrentPeriods = [];
                        });
                        Navigator.pop(context);
                        _loadTasksForJob(jobId);
                        _loadRecurrentPeriodsForJob(jobId);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRecurrentDropdown() {
    final p = SoftPalette.of(context);

    // Enable dropdown only if job is selected and recurrent periods are loaded
    final isEnabled = _selectedJobId != null && _recurrentPeriods.isNotEmpty;

    // Determine hint text based on state
    String hintText;
    if (_selectedJobId == null) {
      hintText = 'Select a job first';
    } else if (_recurrentPeriods.isEmpty) {
      hintText = 'No recurrent periods available';
    } else {
      hintText = 'Select recurrence';
    }

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: InputDecorator(
        decoration: softInputDecoration(context, icon: Icons.repeat_rounded, filled: true)
            .copyWith(contentPadding: const EdgeInsets.fromLTRB(0, 1, 12, 1)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedRecurrent,
            hint: Text(hintText, style: SoftText.body(p, color: p.muted)),
            isExpanded: true,
            icon: Icon(Icons.expand_more_rounded, color: p.muted, size: 20),
            dropdownColor: p.surface,
            borderRadius: BorderRadius.circular(16),
            style: softInputTextStyle(context),
            items: isEnabled
                ? _recurrentPeriods.map((period) {
                    final recperIdStr = period['recper_id'].toString();
                    final recurPeriod = period['recur_period'] as String? ?? 'Unknown';
                    return DropdownMenuItem<String>(
                      value: recperIdStr, // Use recper_id as value
                      child: Text(recurPeriod), // Display recur_period text
                    );
                  }).toList()
                : null,
            onChanged: isEnabled
                ? (String? newValue) {
                    setState(() {
                      _selectedRecurrent = newValue;
                      // Store recper_id as integer
                      _selectedRecperId = newValue != null ? int.tryParse(newValue) : null;
                    });
                  }
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskDropdown() {
    final isEnabled = _selectedRecurrent != null;

    // Get selected task name for display
    String? selectedTaskName;
    if (_selectedTaskId != null && _tasks.isNotEmpty) {
      final selectedTask = _tasks.firstWhere(
        (t) => t['task_id'] == _selectedTaskId,
        orElse: () => {'task_desc': null},
      );
      selectedTaskName = selectedTask['task_desc'] as String?;
    }

    // Determine hint text
    String hintText;
    if (!isEnabled) {
      hintText = 'Select a recurrence first';
    } else if (_tasks.isEmpty) {
      hintText = 'No tasks available';
    } else {
      hintText = 'Select a task';
    }

    return SoftPickerField(
      value: selectedTaskName,
      placeholder: hintText,
      icon: Icons.task_alt_rounded,
      filled: true,
      enabled: isEnabled,
      onTap: !isEnabled || _tasks.isEmpty
          ? null
          : () => _showTaskSearchDialog(),
    );
  }

  /// Show searchable task selection dialog
  Future<void> _showTaskSearchDialog() async {
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter tasks based on search query
            var filteredTasks = searchQuery.isEmpty
                ? _tasks
                : _tasks.where((task) {
                    final taskDesc = (task['task_desc'] ?? '').toString().toLowerCase();
                    return taskDesc.contains(searchQuery.toLowerCase());
                  }).toList();

            // Sort alphabetically by task description
            filteredTasks = List.from(filteredTasks)
              ..sort((a, b) => (a['task_desc'] ?? '').toString().toLowerCase()
                  .compareTo((b['task_desc'] ?? '').toString().toLowerCase()));

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return _buildSearchSheetBody(
                  title: 'Select Task',
                  countLabel: '${filteredTasks.length} tasks',
                  searchHint: 'Search task name...',
                  searchController: searchController,
                  searchQuery: searchQuery,
                  onQueryChanged: (value) => setModalState(() => searchQuery = value),
                  emptyText: 'No tasks found',
                  scrollController: scrollController,
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    final taskId = task['task_id'] as int;
                    final taskDesc = task['task_desc'] ?? 'Unknown Task';
                    final isSelected = taskId == _selectedTaskId;

                    return _PickerTile(
                      title: taskDesc,
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedTaskId = taskId;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDescriptionField() {
    final p = SoftPalette.of(context);

    return Scrollbar(
      controller: _descriptionScrollController,
      thumbVisibility: false,
      interactive: true,
      thickness: 4,
      radius: const Radius.circular(4),
      child: TextFormField(
        controller: _descriptionController,
        scrollController: _descriptionScrollController,
        minLines: 4,
        maxLines: 4,
        maxLength: 200,
        cursorColor: p.ink,
        onChanged: (_) => setState(() {}),
        style: softInputTextStyle(context),
        decoration: softInputDecoration(
          context,
          hint: 'Describe the work performed...',
          counterText: '', // Hide default counter
          filled: true,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a work description';
          }
          return null;
        },
      ),
    );
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

  // Status configurations for job categorization
  final List<Map<String, dynamic>> _statusConfigs = [
    {
      'status': 'Waiting',
      'code': 'W',
      'icon': Icons.hourglass_empty_rounded,
      'color': const Color(0xFFF59E0B),
    },
    {
      'status': 'Planning',
      'code': 'A',
      'icon': Icons.architecture_rounded,
      'color': const Color(0xFF3B82F6),
    },
    {
      'status': 'Progress',
      'code': 'P',
      'icon': Icons.rocket_launch_rounded,
      'color': const Color(0xFF10B981),
    },
    {
      'status': 'Work Done',
      'code': 'G',
      'icon': Icons.task_alt_rounded,
      'color': const Color(0xFF0D9488),
    },
    {
      'status': 'Delivery',
      'code': 'D',
      'icon': Icons.local_shipping_rounded,
      'color': const Color(0xFF8B5CF6),
    },
  ];

  // Map status code to display name (Closer status 'C' excluded - not needed)
  String _getStatusName(String? statusCode) {
    final statusMap = {
      'W': 'Waiting',
      'P': 'Progress',
      'D': 'Delivery',
      'A': 'Planning',
      'G': 'Work Done',
      'L': 'Planning',
    };
    return statusMap[statusCode?.trim()] ?? 'Waiting';
  }

  // Get jobs by status
  List<Map<String, dynamic>> _getJobsByStatus(String status) {
    return _allJobs.where((job) {
      final jobStatus = _getStatusName(job['job_status']?.toString());
      return jobStatus == status;
    }).toList();
  }

  // Get client name by client_id for search (uses _allClients for priority dialog search)
  String _getClientNameById(int? clientId) {
    if (clientId == null) return '';
    // Use _allClients which contains all clients with jobs (not just priority-filtered ones)
    final client = _allClients.firstWhere(
      (c) => c['client_id'] == clientId,
      orElse: () => {'clientname': ''},
    );
    return (client['clientname'] ?? '').toString();
  }

  // Get filtered jobs by status and search query
  List<Map<String, dynamic>> _getFilteredJobsByStatus(String status, String searchQuery) {
    var jobs = _getJobsByStatus(status);
    if (searchQuery.isEmpty) return jobs;

    final query = searchQuery.toLowerCase();
    return jobs.where((job) {
      final clientName = _getClientNameById(job['client_id']).toLowerCase();
      final jobDesc = (job['work_desc'] ?? '').toString().toLowerCase();
      final jobUid = (job['job_uid'] ?? '').toString().toLowerCase();
      return clientName.contains(query) || jobDesc.contains(query) || jobUid.contains(query);
    }).toList();
  }

  /// Flat list of matching jobs across every status, each with a status
  /// badge in the right corner. Used inside the priority selection sheet
  /// when there's an active search query.
  List<Widget> _buildFlatSearchResults({
    required String searchQuery,
    required Set<int> tempSelectedIds,
    required void Function(int jobId) onToggleJob,
  }) {
    final p = SoftPalette.of(context);
    final matches = <Map<String, dynamic>>[];
    for (final config in _statusConfigs) {
      final status = config['status'] as String;
      final color = config['color'] as Color;
      final jobs = _getFilteredJobsByStatus(status, searchQuery);
      for (final job in jobs) {
        matches.add({'job': job, 'status': status, 'color': color});
      }
    }

    if (matches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'No jobs match "$searchQuery"',
              style: SoftText.body(p, size: 13, color: p.muted),
            ),
          ),
        ),
      ];
    }

    return matches.map((match) {
      final job = match['job'] as Map<String, dynamic>;
      final jobId = job['job_id'] as int;

      return _PriorityJobRow(
        job: job,
        clientName: _getClientNameById(job['client_id']),
        color: match['color'] as Color,
        selected: tempSelectedIds.contains(jobId),
        statusLabel: match['status'] as String,
        boxed: true,
        onTap: () => onToggleJob(jobId),
      );
    }).toList();
  }

  /// Show priority job selection sheet
  Future<void> _showPrioritySelectionDialog() async {
    final p = SoftPalette.of(context);

    Set<int> tempSelectedIds = Set<int>.from(_selectedPriorityJobIds);
    String? expandedStatus;
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.background,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void toggleJob(int jobId) {
              setModalState(() {
                if (tempSelectedIds.contains(jobId)) {
                  tempSelectedIds.remove(jobId);
                } else {
                  tempSelectedIds.add(jobId);
                }
              });
            }

            // One white card with a row per status; tapping a row expands
            // its jobs underneath.
            Widget statusCard() {
              final rows = <Widget>[];
              for (int i = 0; i < _statusConfigs.length; i++) {
                final config = _statusConfigs[i];
                final status = config['status'] as String;
                final color = config['color'] as Color;
                final jobs = _getFilteredJobsByStatus(status, searchQuery);
                final isExpanded = expandedStatus == status;
                final selectedInCategory =
                    jobs.where((j) => tempSelectedIds.contains(j['job_id'])).length;
                final empty = jobs.isEmpty;

                if (i > 0) rows.add(Divider(height: 1, color: p.border));
                rows.add(
                  InkWell(
                    onTap: empty
                        ? null
                        : () => setModalState(() {
                              expandedStatus = isExpanded ? null : status;
                            }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status,
                                  style: SoftText.body(p, size: 15, color: empty ? p.inkSoft : p.ink)
                                      .copyWith(fontWeight: FontWeight.w500),
                                ),
                                if (selectedInCategory > 0)
                                  Text(
                                    '$selectedInCategory selected',
                                    style: SoftText.caption(p, size: 11.5).copyWith(color: p.accent),
                                  ),
                              ],
                            ),
                          ),
                          Text('${jobs.length}', style: SoftText.heading(p, size: 15)),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            turns: isExpanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                if (isExpanded && jobs.isNotEmpty) {
                  rows.add(
                    ColoredBox(
                      color: p.background,
                      child: Column(
                        children: jobs.map((job) {
                          final jobId = job['job_id'] as int;
                          return _PriorityJobRow(
                            job: job,
                            clientName: _getClientNameById(job['client_id']),
                            color: color,
                            selected: tempSelectedIds.contains(jobId),
                            onTap: () => toggleJob(jobId),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }
              }
              return SoftCard(
                radius: 22,
                padding: EdgeInsets.zero,
                child: Column(children: rows),
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Priority jobs', style: SoftText.heading(p, size: 20)),
                              ),
                              Text(
                                '${tempSelectedIds.length} selected',
                                style: SoftText.caption(p, size: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pick jobs to show first when you log work',
                            style: SoftText.caption(p, size: 12.5),
                          ),
                        ],
                      ),
                    ),
                    // Search Field
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: TextField(
                        controller: searchController,
                        cursorColor: p.ink,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        style: softInputTextStyle(context),
                        decoration: softInputDecoration(
                          context,
                          hint: 'Search by client or job',
                          icon: Icons.search_rounded,
                          pill: true,
                          suffix: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    // Status card (no search) OR flat job list with status
                    // badges (when searching).
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        children: searchQuery.isNotEmpty
                            ? _buildFlatSearchResults(
                                searchQuery: searchQuery,
                                tempSelectedIds: tempSelectedIds,
                                onToggleJob: toggleJob,
                              )
                            : [statusCard()],
                      ),
                    ),
                    // Bottom action bar
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        8,
                        20,
                        12 + MediaQuery.of(context).padding.bottom,
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: tempSelectedIds.isEmpty
                                ? null
                                : () => setModalState(() => tempSelectedIds.clear()),
                            style: TextButton.styleFrom(
                              foregroundColor: p.danger,
                              disabledForegroundColor: p.muted,
                            ),
                            child: const Text('Clear'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SoftPillButton(
                              label: 'Save priorities',
                              variant: SoftPillVariant.blue,
                              height: 50,
                              onPressed: tempSelectedIds.isEmpty
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      await _savePrioritySelections(tempSelectedIds);
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Save priority selections to database
  Future<void> _savePrioritySelections(Set<int> selectedJobIds) async {
    setState(() => _isLoading = true);

    try {
      // Clear existing priorities
      await PriorityService.clearAllPriorities();

      // Add new priorities
      for (final jobId in selectedJobIds) {
        await PriorityService.addPriorityJob(jobId);
      }

      // Reload form data with new priorities
      await _loadFormData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedJobIds.length} priority jobs saved'),
            backgroundColor: SoftPalette.of(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving priorities: $e'),
            backgroundColor: SoftPalette.of(context).danger,
          ),
        );
      }
    }
  }

}

/// Pill toggle used for the work-hours input mode (From / To vs Hours / Min).
class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final activeBg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
    final fg = selected ? (p.isDark ? p.background : Colors.white) : p.inkSoft;
    return Material(
      color: selected ? activeBg : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(label, style: SoftText.heading(p, size: 13).copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row in the client / job / task picker sheets.
class _PickerTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final int? titleMaxLines;

  const _PickerTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.titleMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? p.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: titleMaxLines,
                        overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
                        style: SoftText.heading(p, size: 14.5).copyWith(
                          color: selected ? p.accent : p.ink,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: SoftText.caption(p)),
                      ],
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_rounded, color: p.accent, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable job row in the priority sheet (checkbox, job, client, UID).
/// [boxed] renders it as its own card (search results); otherwise it is a
/// divided row inside an expanded status category.
class _PriorityJobRow extends StatelessWidget {
  final Map<String, dynamic> job;
  final String clientName;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? statusLabel;
  final bool boxed;

  const _PriorityJobRow({
    required this.job,
    required this.clientName,
    required this.color,
    required this.selected,
    required this.onTap,
    this.statusLabel,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final hasClient = clientName.isNotEmpty;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: selected ? color : p.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? color : p.muted.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job['work_desc'] ?? 'Unknown Job',
                style: SoftText.heading(p, size: 13.5).copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.business_rounded, size: 12, color: p.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hasClient ? clientName : 'No client assigned',
                      style: SoftText.caption(p, size: 11.5).copyWith(
                        color: hasClient ? p.accent : p.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(job['job_uid'] ?? 'N/A', style: SoftText.caption(p)),
            ],
          ),
        ),
        if (statusLabel != null) ...[
          const SizedBox(width: 8),
          SoftStatusPill(label: statusLabel!, color: color, showDot: false),
        ],
      ],
    );

    if (boxed) {
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? color.withValues(alpha: 0.5) : p.border),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: p.surface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: content,
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.border, width: 0.5)),
          ),
          child: content,
        ),
      ),
    );
  }
}


/// Custom TextInputFormatter that limits input to a range of values
class _RangeTextInputFormatter extends TextInputFormatter {
  final int min;
  final int max;

  _RangeTextInputFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final int? value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }

    if (value > max) {
      return TextEditingValue(
        text: max.toString(),
        selection: TextSelection.collapsed(offset: max.toString().length),
      );
    }

    return newValue;
  }
}
