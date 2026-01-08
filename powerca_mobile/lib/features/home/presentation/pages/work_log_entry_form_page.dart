import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/services/priority_service.dart';
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

  DateTime? _selectedDate;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  int? _selectedClientId;
  int? _selectedJobId;
  int? _selectedTaskId;

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

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _loadFormData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
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

      // STEP 1: Load jobs assigned to current staff from jobshead
      // Note: work_desc maps to job_name
      // Filter by sporg_id to match jobs_page.dart behavior
      // Exclude Closer jobs (status code 'C') - they should not appear in the app
      final jobsResponse = await supabase
          .from('jobshead')
          .select('job_id, job_uid, work_desc, client_id, job_status')
          .eq('sporg_id', widget.staffId)
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

  Future<void> _selectDate() async {
    // Get current date at midnight (00:00:00) for firstDate
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today, // Only allow current date and future dates
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isFromTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
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

    if (_fromTime == null || _toTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select from and to times')),
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

    if (_selectedTaskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a task')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Check for time overlap with existing entries
    final overlap = await _checkTimeOverlap();
    if (overlap != null) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Time overlap! You already have an entry from ${overlap['fromTime']} to ${overlap['toTime']}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final hours = _calculateHours();
      final minutes = (hours * 60).round(); // Convert hours to minutes

      // IMPORTANT: workdiary columns are: date, minutes, tasknotes (NOT wd_date, actual_hrs, wd_notes)
      // Format times as TIME ONLY (HH:mm:ss) - timefrom/timeto columns are time type
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final fromTimeStr = _fromTime != null
          ? '${_fromTime!.hour.toString().padLeft(2, '0')}:${_fromTime!.minute.toString().padLeft(2, '0')}:00'
          : null;
      final toTimeStr = _toTime != null
          ? '${_toTime!.hour.toString().padLeft(2, '0')}:${_toTime!.minute.toString().padLeft(2, '0')}:00'
          : null;

      await supabase.from('workdiary').insert({
        'staff_id': widget.staffId,
        'job_id': _selectedJobId,
        'client_id': _selectedClientId,
        'task_id': _selectedTaskId,
        'date': dateStr, // Column is 'date'
        'tasknotes': _descriptionController.text.trim(), // Column is 'tasknotes'
        'minutes': minutes, // Column is 'minutes' (integer)
        'timefrom': fromTimeStr, // From time (full timestamp format)
        'timeto': toTimeStr, // To time (full timestamp format)
        'source': 'M', // Mobile source
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work log entry created successfully'),
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDF3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD1D9E6),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18.sp,
                    color: AppTheme.textSecondaryColor,
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
            const Text('Create Work Log Entry'),
            if (_hasPriorities)
              Text(
                'Showing ${_priorityJobIds.length} priority jobs',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFEF4444),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF080E29),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.w,
                bottom: 20.w + MediaQuery.of(context).padding.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority Selection Banner (always show - staff can add/edit priorities anytime)
                    _buildPrioritySelectionBanner(),

                    // Date Selector
                    _buildSectionTitle('Select Date'),
                    SizedBox(height: 8.h),
                    _buildDateSelector(),
                    SizedBox(height: 20.h),

                    // Time Selectors
                    _buildSectionTitle('Work Hours'),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Expanded(child: _buildTimeSelector(true)),
                        SizedBox(width: 12.w),
                        Expanded(child: _buildTimeSelector(false)),
                      ],
                    ),
                    if (_fromTime != null && _toTime != null) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'Total Hours: ${_formatMinutesToHours((_calculateHours() * 60).round())}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                    SizedBox(height: 20.h),

                    // Client Selector
                    _buildSectionTitle('Select Client'),
                    SizedBox(height: 8.h),
                    _buildClientDropdown(),
                    SizedBox(height: 20.h),

                    // Job Selector
                    _buildSectionTitle('Select Job'),
                    SizedBox(height: 8.h),
                    _buildJobDropdown(),
                    SizedBox(height: 20.h),

                    // Task Selector (Required)
                    _buildSectionTitle('Select Task'),
                    SizedBox(height: 8.h),
                    _buildTaskDropdown(),
                    SizedBox(height: 20.h),

                    // Work Description
                    _buildSectionTitle('Work Description'),
                    SizedBox(height: 8.h),
                    _buildDescriptionField(),
                    SizedBox(height: 32.h),

                    // Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF080E29),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE9F0F8)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20.sp,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _selectedDate != null
                    ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)
                    : 'Select a date',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: _selectedDate != null
                      ? const Color(0xFF080E29)
                      : const Color(0xFF8F8E90),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(bool isFromTime) {
    final time = isFromTime ? _fromTime : _toTime;
    final label = isFromTime ? 'From Time' : 'To Time';

    return InkWell(
      onTap: () => _selectTime(isFromTime),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE9F0F8)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: 20.sp,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8F8E90),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    time != null ? time.format(context) : 'Select time',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: time != null
                          ? const Color(0xFF080E29)
                          : const Color(0xFF8F8E90),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    return InkWell(
      onTap: () => _showClientSearchDialog(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE9F0F8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedClientName ?? 'Select a client',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: selectedClientName != null
                      ? const Color(0xFF080E29)
                      : const Color(0xFF8F8E90),
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: const Color(0xFF8F8E90),
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }

  /// Show searchable client selection dialog
  Future<void> _showClientSearchDialog() async {
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
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
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: EdgeInsets.only(top: 8.h),
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Client',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF080E29),
                            ),
                          ),
                          Text(
                            '${filteredClients.length} clients',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8F8E90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Field
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search client name...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18.sp, color: const Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8F9FC),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    // Client list
                    Expanded(
                      child: filteredClients.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48.sp,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'No clients found',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF8F8E90),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              itemCount: filteredClients.length,
                              itemBuilder: (context, index) {
                                final client = filteredClients[index];
                                final clientId = client['client_id'] as int;
                                final clientName = client['clientname'] ?? 'Unknown Client';
                                final isSelected = clientId == _selectedClientId;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedClientId = clientId;
                                      _selectedJobId = null;
                                      _selectedTaskId = null;
                                      _tasks = [];
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            clientName,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14.sp,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                              color: isSelected ? AppTheme.primaryColor : const Color(0xFF080E29),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: AppTheme.primaryColor,
                                            size: 20.sp,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
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

    return InkWell(
      onTap: _selectedClientId == null || filteredJobs.isEmpty
          ? null
          : () => _showJobSearchDialog(filteredJobs),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE9F0F8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedJobDisplay ?? (filteredJobs.isEmpty ? 'No jobs available' : 'Select a job'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: selectedJobDisplay != null
                      ? const Color(0xFF080E29)
                      : const Color(0xFF8F8E90),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: const Color(0xFF8F8E90),
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }

  /// Show searchable job selection dialog
  Future<void> _showJobSearchDialog(List<Map<String, dynamic>> jobs) async {
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
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
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: EdgeInsets.only(top: 8.h),
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Job',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF080E29),
                            ),
                          ),
                          Text(
                            '${filteredJobs.length} jobs',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8F8E90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Field
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search job name or ID...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18.sp, color: const Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8F9FC),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    // Job list
                    Expanded(
                      child: filteredJobs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48.sp,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'No jobs found',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF8F8E90),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              itemCount: filteredJobs.length,
                              itemBuilder: (context, index) {
                                final job = filteredJobs[index];
                                final jobId = job['job_id'] as int;
                                final jobUid = job['job_uid'] ?? 'N/A';
                                final jobDesc = job['work_desc'] ?? 'Unknown Job';
                                final isSelected = jobId == _selectedJobId;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedJobId = jobId;
                                      _selectedTaskId = null;
                                      _tasks = [];
                                    });
                                    Navigator.pop(context);
                                    _loadTasksForJob(jobId);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                jobDesc,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 14.sp,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF080E29),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 2.h),
                                              Text(
                                                jobUid,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w400,
                                                  color: const Color(0xFF8F8E90),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: AppTheme.primaryColor,
                                            size: 20.sp,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
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

  Widget _buildTaskDropdown() {
    // Get selected task name for display
    String? selectedTaskName;
    if (_selectedTaskId != null && _tasks.isNotEmpty) {
      final selectedTask = _tasks.firstWhere(
        (t) => t['task_id'] == _selectedTaskId,
        orElse: () => {'task_desc': null},
      );
      selectedTaskName = selectedTask['task_desc'] as String?;
    }

    return InkWell(
      onTap: _selectedJobId == null || _tasks.isEmpty
          ? null
          : () => _showTaskSearchDialog(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE9F0F8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedTaskName ?? (_tasks.isEmpty ? 'No tasks available' : 'Select a task'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: selectedTaskName != null
                      ? const Color(0xFF080E29)
                      : const Color(0xFF8F8E90),
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: const Color(0xFF8F8E90),
              size: 24.sp,
            ),
          ],
        ),
      ),
    );
  }

  /// Show searchable task selection dialog
  Future<void> _showTaskSearchDialog() async {
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
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
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: EdgeInsets.only(top: 8.h),
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Task',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF080E29),
                            ),
                          ),
                          Text(
                            '${filteredTasks.length} tasks',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8F8E90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Field
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search task name...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18.sp, color: const Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8F9FC),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    // Task list
                    Expanded(
                      child: filteredTasks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48.sp,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'No tasks found',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF8F8E90),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              itemCount: filteredTasks.length,
                              itemBuilder: (context, index) {
                                final task = filteredTasks[index];
                                final taskId = task['task_id'] as int;
                                final taskDesc = task['task_desc'] ?? 'Unknown Task';
                                final isSelected = taskId == _selectedTaskId;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTaskId = taskId;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            taskDesc,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14.sp,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                              color: isSelected ? AppTheme.primaryColor : const Color(0xFF080E29),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: AppTheme.primaryColor,
                                            size: 20.sp,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
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

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8)),
      ),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Describe the work performed...',
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppTheme.textDisabledColor,
          ),
          filled: true,
          fillColor: Colors.white,
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
        ),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF080E29),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Create Work Log Entry',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
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

  /// Show priority job selection dialog
  Future<void> _showPrioritySelectionDialog() async {
    Set<int> tempSelectedIds = Set<int>.from(_selectedPriorityJobIds);
    String? expandedStatus;
    String searchQuery = '';
    final searchController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: EdgeInsets.only(top: 8.h),
                      width: 36.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: const Color(0xFFEF4444),
                                size: 20.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Select Priority Jobs',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF080E29),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '${tempSelectedIds.length} selected',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    // Search Field
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by client, job description...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 20.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18.sp, color: const Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8F9FC),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    // Status categories with jobs
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        children: _statusConfigs.map((config) {
                          final status = config['status'] as String;
                          final icon = config['icon'] as IconData;
                          final color = config['color'] as Color;
                          final jobs = _getFilteredJobsByStatus(status, searchQuery);
                          final isExpanded = expandedStatus == status;
                          final selectedInCategory = jobs.where((j) => tempSelectedIds.contains(j['job_id'])).length;

                          return Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: isExpanded ? color.withValues(alpha: 0.5) : Colors.grey[200]!,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Category header
                                InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      expandedStatus = isExpanded ? null : status;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Padding(
                                    padding: EdgeInsets.all(12.w),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36.w,
                                          height: 36.h,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Icon(icon, size: 18.sp, color: color),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                status,
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF080E29),
                                                ),
                                              ),
                                              Text(
                                                '${jobs.length} jobs${selectedInCategory > 0 ? ' • $selectedInCategory selected' : ''}',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w400,
                                                  color: selectedInCategory > 0 ? color : const Color(0xFF8F8E90),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isExpanded ? Icons.expand_less : Icons.expand_more,
                                          color: Colors.grey[400],
                                          size: 20.sp,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Expanded job list
                                if (isExpanded && jobs.isNotEmpty)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(12.r),
                                        bottomRight: Radius.circular(12.r),
                                      ),
                                    ),
                                    child: Column(
                                      children: jobs.map((job) {
                                        final jobId = job['job_id'] as int;
                                        final isSelected = tempSelectedIds.contains(jobId);

                                        return InkWell(
                                          onTap: () {
                                            setModalState(() {
                                              if (isSelected) {
                                                tempSelectedIds.remove(jobId);
                                              } else {
                                                tempSelectedIds.add(jobId);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                top: BorderSide(color: Colors.grey[200]!, width: 0.5),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 22.w,
                                                  height: 22.h,
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? color : Colors.white,
                                                    borderRadius: BorderRadius.circular(6.r),
                                                    border: Border.all(
                                                      color: isSelected ? color : Colors.grey[300]!,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: isSelected
                                                      ? Icon(Icons.check, size: 14.sp, color: Colors.white)
                                                      : null,
                                                ),
                                                SizedBox(width: 10.w),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        job['work_desc'] ?? 'Unknown Job',
                                                        style: TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 13.sp,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                          color: const Color(0xFF080E29),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      // Client name row - always show
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.business_rounded,
                                                            size: 12.sp,
                                                            color: AppTheme.textMutedColor,
                                                          ),
                                                          SizedBox(width: 4.w),
                                                          Expanded(
                                                            child: Text(
                                                              _getClientNameById(job['client_id']).isNotEmpty
                                                                  ? _getClientNameById(job['client_id'])
                                                                  : 'No client assigned',
                                                              style: TextStyle(
                                                                fontFamily: 'Inter',
                                                                fontSize: 11.sp,
                                                                fontWeight: FontWeight.w500,
                                                                color: _getClientNameById(job['client_id']).isNotEmpty
                                                                    ? AppTheme.primaryColor
                                                                    : const Color(0xFF8F8E90),
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 2.h),
                                                      // Job UID row
                                                      Text(
                                                        job['job_uid'] ?? 'N/A',
                                                        style: TextStyle(
                                                          fontFamily: 'Inter',
                                                          fontSize: 10.sp,
                                                          fontWeight: FontWeight.w400,
                                                          color: const Color(0xFF8F8E90),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Bottom action bar
                    Container(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        children: [
                          // Clear button
                          TextButton(
                            onPressed: tempSelectedIds.isEmpty
                                ? null
                                : () {
                                    setModalState(() => tempSelectedIds.clear());
                                  },
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: tempSelectedIds.isEmpty ? Colors.grey[400] : Colors.red,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Save button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: tempSelectedIds.isEmpty
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      await _savePrioritySelections(tempSelectedIds);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                disabledBackgroundColor: Colors.grey[300],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                elevation: 0,
                              ),
                              child: Text(
                                'Save Priorities',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving priorities: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build priority selection banner - minimalistic design
  /// Shows different text based on whether priorities are already set
  Widget _buildPrioritySelectionBanner() {
    final hasPriorities = _priorityJobIds.isNotEmpty;
    final priorityCount = _priorityJobIds.length;

    return InkWell(
      onTap: _showPrioritySelectionDialog,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: hasPriorities ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: hasPriorities ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: hasPriorities
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                hasPriorities ? Icons.star_rounded : Icons.star_outline_rounded,
                color: hasPriorities ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPriorities ? 'Edit Priority Jobs' : 'Set Priority Jobs',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: hasPriorities ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                  Text(
                    hasPriorities
                        ? '$priorityCount jobs selected • Tap to add more'
                        : 'Tap to select jobs for quick access',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      color: hasPriorities ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: hasPriorities ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }
}
