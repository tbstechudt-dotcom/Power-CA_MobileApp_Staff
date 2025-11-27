import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
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

  const WorkLogDetailPage({
    super.key,
    required this.entry,
    required this.entryIndex,
    required this.selectedDate,
    required this.staffId,
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
    _loadAllNames();
    _loadExistingAttachments();
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

    debugPrint('Loading names for job_id: $jobId, client_id: $clientId');

    try {
      // Load job name
      if (jobId != null) {
        final jobResponse = await _supabase
            .from('jobshead')
            .select('work_desc')
            .eq('job_id', jobId)
            .maybeSingle();

        debugPrint('Job response: $jobResponse');

        if (jobResponse != null && jobResponse['work_desc'] != null) {
          _jobName = jobResponse['work_desc'].toString();
          debugPrint('Job name loaded: $_jobName');
        }

        // Get task description from jobtasks
        // Note: taskmaster table is empty, so we get task_desc from jobtasks
        final taskResponse = await _supabase
            .from('jobtasks')
            .select('task_desc, task_id')
            .eq('job_id', jobId)
            .limit(1)
            .maybeSingle();

        debugPrint('Task response: $taskResponse');

        if (taskResponse != null) {
          // Use task_desc from jobtasks if available
          if (taskResponse['task_desc'] != null && taskResponse['task_desc'].toString().isNotEmpty) {
            _taskName = taskResponse['task_desc'].toString();
            debugPrint('Task name from jobtasks: $_taskName');
          }
        }
      }

      // Load client name
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
    } catch (e) {
      debugPrint('Error loading names: $e');
      if (mounted) {
        setState(() {
          _isLoadingNames = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2563EB)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Log Details',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
            ),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entry Header Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Entry number and time badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'Entry #${widget.entryIndex}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14.sp,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              hours,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Time range
                  if (timeFrom.isNotEmpty && timeTo.isNotEmpty) ...[
                    _buildDetailRow(
                      icon: Icons.schedule,
                      label: 'Time',
                      value: '${_formatTimeDisplay(timeFrom)} - ${_formatTimeDisplay(timeTo)}',
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Job Name
                  if (jobId != null) ...[
                    _buildDetailRow(
                      icon: Icons.work_outline,
                      label: 'Job',
                      value: jobDisplay,
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Client Name
                  if (clientId != null) ...[
                    _buildDetailRow(
                      icon: Icons.business_outlined,
                      label: 'Client',
                      value: clientDisplay,
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Task Name
                  if (_taskName.isNotEmpty || _isLoadingNames) ...[
                    _buildDetailRow(
                      icon: Icons.task_outlined,
                      label: 'Task',
                      value: taskDisplay,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Description Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 18.sp,
                        color: const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    tasknotes,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF1F2937),
                      height: 1.6,
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
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 18.sp,
                          color: const Color(0xFF6B7280),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Attached Files (${_attachedFiles.length})',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    ...List.generate(_attachedFiles.length, (index) {
                      final file = _attachedFiles[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: index < _attachedFiles.length - 1 ? 8.h : 0),
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: file.type == 'image'
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.1)
                                    : const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(
                                file.type == 'image' ? Icons.image : Icons.insert_drive_file,
                                size: 18.sp,
                                color: file.type == 'image'
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                file.name,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1F2937),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _attachedFiles.removeAt(index);
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 18.sp,
                                color: const Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: const Color(0xFF6366F1)),
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
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18.sp,
          color: const Color(0xFF6B7280),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAttachFileDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
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
                color: const Color(0xFFE5E7EB),
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
                color: const Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 20.h),
            _buildAttachOption(
              context,
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
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
        setState(() {
          _attachedFiles.add(AttachedFile(
            name: image.name,
            path: image.path,
            type: 'image',
          ));
        });
        // Upload to Supabase and update workdiary doc_ref
        if (context.mounted) {
          final bytes = await image.readAsBytes();
          await _uploadFileToSupabase(bytes, image.name, context);
        }
      }
    } catch (e) {
      if (context.mounted) {
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
        setState(() {
          _attachedFiles.add(AttachedFile(
            name: image.name,
            path: image.path,
            type: 'image',
          ));
        });
        // Upload to Supabase and update workdiary doc_ref
        if (context.mounted) {
          final bytes = await image.readAsBytes();
          await _uploadFileToSupabase(bytes, image.name, context);
        }
      }
    } catch (e) {
      if (context.mounted) {
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
        final isImage = ['png', 'jpg', 'jpeg'].contains(file.extension?.toLowerCase());
        setState(() {
          _attachedFiles.add(AttachedFile(
            name: file.name,
            path: file.path ?? '',
            type: isImage ? 'image' : 'document',
            size: file.size,
          ));
        });
        // Upload to Supabase and update workdiary doc_ref
        if (context.mounted && file.bytes != null) {
          await _uploadFileToSupabase(file.bytes!, file.name, context);
        }
      }
    } catch (e) {
      if (context.mounted) {
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22.sp,
              color: const Color(0xFF6B7280),
            ),
            SizedBox(width: 12.w),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1F2937),
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
  Future<void> _uploadFileToSupabase(Uint8List bytes, String fileName, BuildContext context) async {
    final wdId = widget.entry['wd_id'];
    debugPrint('=== _uploadFileToSupabase START ===');
    debugPrint('wd_id: $wdId, fileName: $fileName, bytes length: ${bytes.length}');

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
