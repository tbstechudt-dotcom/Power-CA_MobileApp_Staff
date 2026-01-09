import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import 'work_log_checklist_page.dart';

/// Model to store attached file information
class AttachedFile {
  final String name;
  final String path;
  final String type; // 'image' or 'document'
  final int size;

  AttachedFile({
    required this.name,
    required this.path,
    required this.type,
    this.size = 0,
  });
}

/// Page to display full details of a work log entry
class WorkLogDetailPage extends StatefulWidget {
  final Map<String, dynamic> entry;
  final int entryIndex;
  final DateTime selectedDate;
  final int staffId;
  final String? jobName;
  final String? clientName;

  const WorkLogDetailPage({
    super.key,
    required this.entry,
    required this.entryIndex,
    required this.selectedDate,
    required this.staffId,
    this.jobName,
    this.clientName,
  });

  @override
  State<WorkLogDetailPage> createState() => _WorkLogDetailPageState();
}

class _WorkLogDetailPageState extends State<WorkLogDetailPage> {
  final List<AttachedFile> _attachedFiles = [];
  bool _isUploading = false;
  final _supabase = Supabase.instance.client;

  // Actual names from database
  String _jobName = '';
  String _clientName = '';
  String _taskName = '';
  bool _isLoadingNames = true;

  @override
  void initState() {
    super.initState();
    // Use passed names if available, otherwise fetch from database
    if (widget.jobName != null) {
      _jobName = widget.jobName!;
    }
    if (widget.clientName != null) {
      _clientName = widget.clientName!;
    }
    // If names are already provided, skip loading (except task which isn't passed)
    if (widget.jobName != null && widget.clientName != null) {
      _isLoadingNames = false;
      _loadTaskName(); // Only load task name
    } else {
      _loadAllNames();
    }
    _loadExistingAttachments();
  }

  /// Load only task name from database (when job and client names are already provided)
  Future<void> _loadTaskName() async {
    final jobId = widget.entry['job_id'];
    final taskId = widget.entry['task_id'];

    if (taskId != null && jobId != null) {
      try {
        final taskResponse = await _supabase
            .from('jobtasks')
            .select('task_desc')
            .eq('job_id', jobId)
            .eq('task_id', taskId)
            .maybeSingle();

        if (taskResponse != null && taskResponse['task_desc'] != null) {
          final taskDesc = taskResponse['task_desc'].toString();
          if (taskDesc.isNotEmpty && mounted) {
            setState(() {
              _taskName = taskDesc;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading task name: $e');
      }
    }
  }

  /// Load existing attachments from database (fetch fresh data)
  Future<void> _loadExistingAttachments() async {
    final wdId = widget.entry['wd_id'];
    debugPrint('=== _loadExistingAttachments START ===');
    debugPrint('Entry data: ${widget.entry}');
    debugPrint('wd_id from entry: $wdId (type: ${wdId.runtimeType})');

    if (wdId == null) {
      debugPrint('ERROR: wd_id is null - cannot load attachments');
      return;
    }

    try {
      // Fetch fresh data from database to get latest doc_ref
      debugPrint('Querying workdiary for wd_id: $wdId');
      final response = await _supabase
          .from('workdiary')
          .select('wd_id, doc_ref')
          .eq('wd_id', wdId)
          .maybeSingle();

      debugPrint('Query response: $response');

      if (response == null) {
        debugPrint('ERROR: No record found for wd_id: $wdId');
        return;
      }

      final docRef = response['doc_ref'];
      debugPrint('doc_ref value: $docRef (type: ${docRef.runtimeType})');

      if (docRef != null && docRef.toString().isNotEmpty) {
        // Extract filename from URL
        final url = docRef.toString();
        debugPrint('Processing doc_ref URL: $url');

        String fileName = 'Attached File';
        try {
          final uri = Uri.parse(url);
          fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Attached File';
          debugPrint('Extracted filename: $fileName');
        } catch (e) {
          debugPrint('Error parsing doc_ref URL: $e');
        }

        // Determine file type from extension
        final extension = fileName.split('.').last.toLowerCase();
        final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(extension);
        debugPrint('File extension: $extension, isImage: $isImage');

        if (mounted) {
          setState(() {
            // Clear existing and add fresh data
            _attachedFiles.clear();
            _attachedFiles.add(AttachedFile(
              name: fileName,
              path: url,
              type: isImage ? 'image' : 'document',
            ));
          });
          debugPrint('SUCCESS: Added attachment to list - total: ${_attachedFiles.length}');
        }
      } else {
        debugPrint('doc_ref is null or empty - no attachment to load');
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR loading attachments: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    debugPrint('=== _loadExistingAttachments END ===');
  }

  /// Load job name, client name, and task name from database
  Future<void> _loadAllNames() async {
    final jobId = widget.entry['job_id'];
    final clientId = widget.entry['client_id'];
    final taskId = widget.entry['task_id'];

    debugPrint('Loading names for job_id: $jobId, client_id: $clientId, task_id: $taskId');
    debugPrint('Full entry data: ${widget.entry}');

    try {
      // Load job name from jobshead
      if (jobId != null) {
        final jobResponse = await _supabase
            .from('jobshead')
            .select('work_desc, client_id')
            .eq('job_id', jobId)
            .maybeSingle();

        debugPrint('Job response: $jobResponse');

        if (jobResponse != null && jobResponse['work_desc'] != null) {
          _jobName = jobResponse['work_desc'].toString();
          debugPrint('Job name loaded: $_jobName');
        }
      }

      // Load task description from jobtasks using task_id
      // Note: taskmaster table is empty, so we get task_desc from jobtasks
      if (taskId != null && jobId != null) {
        // Query jobtasks by both job_id and task_id to get the specific task
        final taskResponse = await _supabase
            .from('jobtasks')
            .select('task_desc, task_id, jt_id')
            .eq('job_id', jobId)
            .eq('task_id', taskId)
            .maybeSingle();

        debugPrint('Task response (by task_id): $taskResponse');

        if (taskResponse != null && taskResponse['task_desc'] != null) {
          final taskDesc = taskResponse['task_desc'].toString();
          if (taskDesc.isNotEmpty) {
            _taskName = taskDesc;
            debugPrint('Task name loaded: $_taskName');
          }
        }
      } else if (jobId != null) {
        // Fallback: If no task_id, try to get first task for the job
        final taskResponse = await _supabase
            .from('jobtasks')
            .select('task_desc, task_id')
            .eq('job_id', jobId)
            .limit(1)
            .maybeSingle();

        debugPrint('Task response (fallback): $taskResponse');

        if (taskResponse != null && taskResponse['task_desc'] != null) {
          final taskDesc = taskResponse['task_desc'].toString();
          if (taskDesc.isNotEmpty) {
            _taskName = taskDesc;
            debugPrint('Task name from fallback: $_taskName');
          }
        }
      }

      // Load client name from climaster
      if (clientId != null) {
        final clientResponse = await _supabase
            .from('climaster')
            .select('clientname')
            .eq('client_id', clientId)
            .maybeSingle();

        debugPrint('Client response: $clientResponse');

        if (clientResponse != null && clientResponse['clientname'] != null) {
          _clientName = clientResponse['clientname'].toString();
          debugPrint('Client name loaded: $_clientName');
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingNames = false;
        });
        debugPrint('Names loaded - Job: $_jobName, Client: $_clientName, Task: $_taskName');
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading names: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingNames = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;
    final backButtonBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backButtonBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);

    final tasknotes = widget.entry['tasknotes'] ?? 'No description';
    final minutes = widget.entry['minutes'] ?? 0;
    final hours = _formatMinutesToHours(minutes);
    final jobId = widget.entry['job_id'];
    final clientId = widget.entry['client_id'];
    final timeFrom = widget.entry['timefrom'] ?? '';
    final timeTo = widget.entry['timeto'] ?? '';

    // Display names or loading state
    final jobDisplay = _isLoadingNames
        ? 'Loading...'
        : (_jobName.isNotEmpty ? _jobName : 'Job #${jobId ?? 'N/A'}');
    final clientDisplay = _isLoadingNames
        ? 'Loading...'
        : (_clientName.isNotEmpty ? _clientName : 'Client #${clientId ?? 'N/A'}');
    final taskDisplay = _isLoadingNames
        ? 'Loading...'
        : (_taskName.isNotEmpty ? _taskName : 'No task assigned');

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Column(
        children: [
          // White status bar area with custom header
          Container(
            color: headerBgColor,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                color: headerBgColor,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42.w,
                        height: 42.h,
                        decoration: BoxDecoration(
                          color: backButtonBgColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: backButtonBorderColor,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: 18.sp,
                            color: textSecondaryColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Work Log Details',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: textPrimaryColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16.w,
                    right: 16.w,
                    top: 16.w,
                    bottom: 16.w + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            // Entry Summary Header Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: Entry Title and Time Range
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Entry Title
                        Text(
                          'Entry #${widget.entryIndex}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: textPrimaryColor,
                          ),
                        ),
                        if (timeFrom.isNotEmpty && timeTo.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          // Time Range
                          Text(
                            '${_formatTimeDisplay(timeFrom)} - ${_formatTimeDisplay(timeTo)}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Right side: Duration Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16.sp,
                          color: const Color(0xFF10B981),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          hours,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Work Details Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.work_rounded,
                              size: 20.sp,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Work Details',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),
                  // Details
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        // Job
                        if (jobId != null)
                          _buildDetailItem(
                            icon: Icons.folder_rounded,
                            iconBgColor: isDarkMode ? const Color(0xFF0EA5E9).withValues(alpha: 0.2) : const Color(0xFFF0F9FF),
                            iconColor: const Color(0xFF0EA5E9),
                            label: 'Job',
                            value: jobDisplay,
                            showDivider: clientId != null || (_taskName.isNotEmpty || _isLoadingNames),
                            isDarkMode: isDarkMode,
                          ),
                        // Client
                        if (clientId != null)
                          _buildDetailItem(
                            icon: Icons.business_rounded,
                            iconBgColor: isDarkMode ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
                            iconColor: const Color(0xFFF59E0B),
                            label: 'Client',
                            value: clientDisplay,
                            showDivider: _taskName.isNotEmpty || _isLoadingNames,
                            isDarkMode: isDarkMode,
                          ),
                        // Task
                        if (_taskName.isNotEmpty || _isLoadingNames)
                          _buildDetailItem(
                            icon: Icons.task_alt_rounded,
                            iconBgColor: isDarkMode ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFD1FAE5),
                            iconColor: const Color(0xFF10B981),
                            label: 'Task',
                            value: taskDisplay,
                            showDivider: false,
                            isDarkMode: isDarkMode,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Description Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFFA855F7).withValues(alpha: 0.2) : const Color(0xFFFDF4FF),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.description_rounded,
                              size: 20.sp,
                              color: const Color(0xFFA855F7),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Description',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: textPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),
                  // Content
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      tasknotes,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Attached Files Section
            if (_attachedFiles.isNotEmpty) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.attach_file_rounded,
                                size: 20.sp,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Attachments',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: textPrimaryColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '${_attachedFiles.length}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    ),
                    // Files List
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        children: List.generate(_attachedFiles.length, (index) {
                          final file = _attachedFiles[index];
                          final isImage = file.type == 'image';
                          return Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40.w,
                                      height: 40.w,
                                      decoration: BoxDecoration(
                                        color: isImage
                                            ? const Color(0xFF6366F1).withValues(alpha: isDarkMode ? 0.2 : 0.1)
                                            : const Color(0xFF10B981).withValues(alpha: isDarkMode ? 0.2 : 0.1),
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      child: Icon(
                                        isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                                        size: 20.sp,
                                        color: isImage
                                            ? const Color(0xFF6366F1)
                                            : const Color(0xFF10B981),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.name,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w500,
                                              color: textPrimaryColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            isImage ? 'Image file' : 'Document',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w400,
                                              color: textSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _attachedFiles.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        width: 32.w,
                                        height: 32.w,
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16.sp,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (index < _attachedFiles.length - 1)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  indent: 52.w,
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],

            // Action Buttons
            Row(
              children: [
                // Attach File Button
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showAttachFileDialog(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFF6366F1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 20.sp,
                            color: const Color(0xFF6366F1),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Attach File',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Checklist Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkLogChecklistPage(
                            staffId: widget.staffId,
                            jobId: jobId ?? 0,
                            selectedDate: widget.selectedDate,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.checklist,
                            size: 20.sp,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Checklist',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
                    ],
                  ),
                ),
                // Loading indicator while uploading
                if (_isUploading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String label,
    required String value,
    bool showDivider = true,
    bool isDarkMode = false,
  }) {
    final labelColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);
    final valueColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 20.sp,
                    color: iconColor,
                  ),
                ),
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
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: labelColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: valueColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 52.w,
          ),
      ],
    );
  }

  void _showAttachFileDialog(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final sheetBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final handleColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFE5E7EB);
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: sheetBgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Attach File',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            SizedBox(height: 20.h),
            _buildAttachOption(
              context,
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              isDarkMode: isDarkMode,
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromCamera(context);
              },
            ),
            SizedBox(height: 12.h),
            _buildAttachOption(
              context,
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              isDarkMode: isDarkMode,
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromGallery(context);
              },
            ),
            SizedBox(height: 12.h),
            _buildAttachOption(
              context,
              icon: Icons.insert_drive_file_outlined,
              label: 'Choose Document',
              isDarkMode: isDarkMode,
              onTap: () async {
                Navigator.pop(context);
                await _pickDocument(context);
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        debugPrint('Camera image selected: ${image.name}, path: ${image.path}');
        // Upload to Supabase and update workdiary doc_ref
        // File will be added to UI list only after successful upload
        // Use widget's mounted property instead of context.mounted
        if (mounted) {
          final bytes = await image.readAsBytes();
          debugPrint('Camera image bytes length: ${bytes.length}');
          await _uploadFileToSupabase(bytes, image.name, context, fileType: 'image');
        } else {
          debugPrint('ERROR: Widget unmounted after camera picker');
        }
      } else {
        debugPrint('Camera image selection cancelled');
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing camera: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        debugPrint('Gallery image selected: ${image.name}, path: ${image.path}');
        // Upload to Supabase and update workdiary doc_ref
        // File will be added to UI list only after successful upload
        // Use widget's mounted property instead of context.mounted
        if (mounted) {
          final bytes = await image.readAsBytes();
          debugPrint('Gallery image bytes length: ${bytes.length}');
          await _uploadFileToSupabase(bytes, image.name, context, fileType: 'image');
        } else {
          debugPrint('ERROR: Widget unmounted after gallery picker');
        }
      } else {
        debugPrint('Gallery image selection cancelled');
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accessing gallery: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickDocument(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
        withData: true, // Load file bytes for web compatibility
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('Document picked: name=${file.name}, path=${file.path}, bytes=${file.bytes?.length ?? 'null'}, size=${file.size}');
        final isImage = ['png', 'jpg', 'jpeg'].contains(file.extension?.toLowerCase());

        // Get file bytes - on Android, file.bytes may be null, so read from path
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          debugPrint('file.bytes is null, reading from path: ${file.path}');
          bytes = await File(file.path!).readAsBytes();
          debugPrint('Read ${bytes.length} bytes from file path');
        } else if (bytes == null && file.path == null) {
          debugPrint('ERROR: Both file.bytes and file.path are null!');
        }

        // Upload to Supabase and update workdiary doc_ref
        // File will be added to UI list only after successful upload
        // Use widget's mounted property instead of context.mounted
        if (mounted && bytes != null) {
          debugPrint('Uploading file with ${bytes.length} bytes');
          await _uploadFileToSupabase(bytes, file.name, context, fileType: isImage ? 'image' : 'document');
        } else {
          debugPrint('ERROR: Could not get file bytes for upload (mounted=$mounted, bytes=${bytes?.length ?? 'null'})');
        }
      } else {
        debugPrint('Document picker cancelled or no files selected');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    }
  }

  Widget _buildAttachOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDarkMode = false,
  }) {
    final bgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC);
    final iconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22.sp,
              color: iconColor,
            ),
            SizedBox(width: 12.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
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

  /// Format time value for display with AM/PM (handles both timestamp and time formats)
  /// Input could be: "2025-11-26T12:30:00", "12:30:00", "12:30:00+00", etc.
  /// Output: "12:30 PM" or "11:30 AM"
  String _formatTimeDisplay(dynamic timeValue) {
    if (timeValue == null || timeValue.toString().isEmpty) return '';

    String timeStr = timeValue.toString();

    // If it contains 'T', it's a full datetime - extract just the time part
    if (timeStr.contains('T')) {
      timeStr = timeStr.split('T')[1];
    }

    // Remove timezone info (+00, -05:30, Z, etc.)
    timeStr = timeStr.split('+')[0].split('Z')[0];
    if (timeStr.contains('-') && timeStr.indexOf('-') > 2) {
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

  /// Upload file to Supabase Storage and update workdiary doc_ref
  Future<void> _uploadFileToSupabase(Uint8List bytes, String fileName, BuildContext context, {String fileType = 'document'}) async {
    final wdId = widget.entry['wd_id'];
    debugPrint('=== _uploadFileToSupabase START ===');
    debugPrint('wd_id: $wdId, fileName: $fileName, bytes length: ${bytes.length}, fileType: $fileType');

    if (wdId == null) {
      debugPrint('ERROR: wd_id is null - cannot upload');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error: Work diary entry ID not found'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Generate unique file name with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final uniqueFileName = '${wdId}_$timestamp.$extension';
      final storagePath = 'workdiary/$uniqueFileName';
      debugPrint('Storage path: $storagePath');

      // Upload to Supabase Storage
      debugPrint('Uploading to Supabase Storage...');
      await _supabase.storage
          .from('attachments')
          .uploadBinary(storagePath, bytes);
      debugPrint('Upload to storage successful');

      // Get public URL
      final publicUrl = _supabase.storage
          .from('attachments')
          .getPublicUrl(storagePath);
      debugPrint('Public URL: $publicUrl');

      // Update workdiary doc_ref column
      debugPrint('Updating workdiary doc_ref for wd_id: $wdId');
      await _supabase
          .from('workdiary')
          .update({'doc_ref': publicUrl, 'updated_at': DateTime.now().toIso8601String()})
          .eq('wd_id', wdId);
      debugPrint('Database update successful');

      // Verify the update by fetching the record back
      final verifyResponse = await _supabase
          .from('workdiary')
          .select('wd_id, doc_ref')
          .eq('wd_id', wdId)
          .maybeSingle();
      debugPrint('Verification query result: $verifyResponse');

      // Only add to UI after successful upload and database update
      if (verifyResponse != null && verifyResponse['doc_ref'] != null) {
        setState(() {
          _attachedFiles.clear();
          _attachedFiles.add(AttachedFile(
            name: fileName,
            path: publicUrl,
            type: fileType,
          ));
        });
        debugPrint('SUCCESS: Added file to UI list after successful upload');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.white, size: 20),
                SizedBox(width: 8.w),
                const Expanded(
                  child: Text(
                    'File uploaded successfully!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('=== _uploadFileToSupabase SUCCESS ===');
    } catch (e, stackTrace) {
      debugPrint('ERROR uploading file: $e');
      debugPrint('Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
