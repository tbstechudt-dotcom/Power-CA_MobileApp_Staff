import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/services/priority_service.dart';

class WorkLogEntryFormPage extends StatefulWidget {
  final DateTime selectedDate;
  final int staffId;

  const WorkLogEntryFormPage({
    super.key,
    required this.selectedDate,
    required this.staffId,
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
  Map<int, Map<int, Map<String, dynamic>>> _jobsByClient = {};
  List<Map<String, dynamic>> _tasks = [];

  bool _isLoading = false;
  bool _isSubmitting = false;

  // Priority filtering
  Set<int> _priorityJobIds = {};
  bool _hasPriorities = false;

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

      // STEP 1: Load ALL jobs from jobshead (including duplicates)
      // Note: work_desc maps to job_name
      // IMPORTANT: Supabase has a default limit of 1000 rows, we need to increase it
      final jobsResponse = await supabase
          .from('jobshead')
          .select('job_id, job_uid, work_desc, client_id')
          .order('work_desc')
          .limit(50000); // Increase limit to get all jobs

      // STEP 1.5: Filter jobs to priority jobs only if priorities are set
      List<dynamic> filteredJobsResponse;
      if (_hasPriorities) {
        filteredJobsResponse = jobsResponse.where((job) {
          final jobId = job['job_id'] as int;
          return _priorityJobIds.contains(jobId);
        }).toList();
        print('DEBUG: Filtered to ${filteredJobsResponse.length} priority jobs out of ${jobsResponse.length} total jobs');
      } else {
        filteredJobsResponse = jobsResponse;
        print('DEBUG: No priorities set, showing all ${jobsResponse.length} jobs');
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

    return to > from ? to - from : 0.0;
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
        Navigator.pop(context, true); // Return true to indicate success
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
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
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
              padding: EdgeInsets.all(20.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                    // Task Selector (Optional)
                    _buildSectionTitle('Select Task (Optional)'),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedClientId,
          hint: Text(
            'Select a client',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
            ),
          ),
          items: _clients.map((client) {
            return DropdownMenuItem<int>(
              value: client['client_id'] as int,
              child: Text(
                client['clientname'] ?? 'Unknown Client',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF080E29),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedClientId = value;
              // Filter jobs by selected client
              _selectedJobId = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildJobDropdown() {
    // Get jobs for the selected client from the pre-grouped structure
    final filteredJobs = _selectedClientId != null && _jobsByClient.containsKey(_selectedClientId)
        ? _jobsByClient[_selectedClientId]!.values.toList()
        : <Map<String, dynamic>>[];

    // Debug logging
    print('DEBUG: Selected client ID: $_selectedClientId');
    print('DEBUG: Filtered jobs count: ${filteredJobs.length}');
    if (filteredJobs.isNotEmpty) {
      print('DEBUG: All filtered jobs for client $_selectedClientId:');
      for (var i = 0; i < filteredJobs.length; i++) {
        print('  ${i + 1}. job_id: ${filteredJobs[i]['job_id']}, work_desc: "${filteredJobs[i]['work_desc']}"');
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedJobId,
          hint: Text(
            filteredJobs.isEmpty
                ? 'No jobs available'
                : 'Select a job',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
            ),
          ),
          items: filteredJobs.map((job) {
            return DropdownMenuItem<int>(
              value: job['job_id'] as int,
              child: Text(
                '${job['job_uid'] ?? 'N/A'} - ${job['work_desc'] ?? 'Unknown Job'}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF080E29),
                ),
              ),
            );
          }).toList(),
          onChanged: filteredJobs.isEmpty
              ? null
              : (value) {
                  setState(() => _selectedJobId = value);
                  // Load tasks for the selected job
                  if (value != null) {
                    _loadTasksForJob(value);
                  }
                },
        ),
      ),
    );
  }

  Widget _buildTaskDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: _selectedTaskId,
          hint: Text(
            _tasks.isEmpty
                ? 'No tasks available'
                : 'Select a task (optional)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
            ),
          ),
          items: _tasks.map((task) {
            return DropdownMenuItem<int>(
              value: task['task_id'] as int, // Use task_id from jobtasks table (references taskmaster)
              child: Text(
                task['task_desc'] ?? 'Unknown Task', // Column is 'task_desc' not 'task_name'
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF080E29),
                ),
              ),
            );
          }).toList(),
          onChanged: _tasks.isEmpty
              ? null
              : (value) {
                  setState(() => _selectedTaskId = value);
                },
        ),
      ),
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
            color: const Color(0xFF8F8E90),
          ),
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
}
