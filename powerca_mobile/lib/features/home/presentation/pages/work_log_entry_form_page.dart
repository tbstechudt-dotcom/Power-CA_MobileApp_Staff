import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';

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
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _tasks = [];

  bool _isLoading = false;
  bool _isSubmitting = false;

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

      // Load clients
      final clientsResponse = await supabase
          .from('climaster')
          .select('client_id, client_name')
          .order('client_name');

      // Load jobs for staff
      final jobsResponse = await supabase
          .from('jobshead')
          .select('job_id, job_name, client_id')
          .eq('staff_id', widget.staffId)
          .order('job_name');

      // Load tasks
      final tasksResponse = await supabase
          .from('taskmaster')
          .select('task_id, task_name')
          .order('task_name');

      setState(() {
        _clients = List<Map<String, dynamic>>.from(clientsResponse);
        _jobs = List<Map<String, dynamic>>.from(jobsResponse);
        _tasks = List<Map<String, dynamic>>.from(tasksResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading form data: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
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

    try {
      final supabase = Supabase.instance.client;
      final hours = _calculateHours();

      await supabase.from('workdiary').insert({
        'staff_id': widget.staffId,
        'job_id': _selectedJobId,
        'client_id': _selectedClientId,
        'task_id': _selectedTaskId,
        'wdate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'wdescription': _descriptionController.text.trim(),
        'hours': hours,
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
      setState(() => _isSubmitting = false);
      if (mounted) {
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
        title: const Text('Create Work Log Entry'),
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
                        'Total Hours: ${_calculateHours().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
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
        fontFamily: 'Poppins',
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
                  fontFamily: 'Poppins',
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
                      fontFamily: 'Poppins',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8F8E90),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    time != null ? time.format(context) : 'Select time',
                    style: TextStyle(
                      fontFamily: 'Poppins',
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
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
            ),
          ),
          items: _clients.map((client) {
            return DropdownMenuItem<int>(
              value: client['client_id'] as int,
              child: Text(
                client['client_name'] ?? 'Unknown Client',
                style: TextStyle(
                  fontFamily: 'Poppins',
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
    final filteredJobs = _selectedClientId != null
        ? _jobs.where((job) => job['client_id'] == _selectedClientId).toList()
        : _jobs;

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
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
            ),
          ),
          items: filteredJobs.map((job) {
            return DropdownMenuItem<int>(
              value: job['job_id'] as int,
              child: Text(
                job['job_name'] ?? 'Unknown Job',
                style: TextStyle(
                  fontFamily: 'Poppins',
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
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
            ),
          ),
          items: _tasks.map((task) {
            return DropdownMenuItem<int>(
              value: task['task_id'] as int,
              child: Text(
                task['task_name'] ?? 'Unknown Task',
                style: TextStyle(
                  fontFamily: 'Poppins',
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
            fontFamily: 'Poppins',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF8F8E90),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
        ),
        style: TextStyle(
          fontFamily: 'Poppins',
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
          disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
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
                  fontFamily: 'Poppins',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
