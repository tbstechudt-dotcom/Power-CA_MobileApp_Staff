import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/soft_page.dart';
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


  Color get _danger => SoftPalette.of(context).danger;
  Color get _success => SoftPalette.of(context).success;

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

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

    final detailRows = <Widget>[
      if (jobId != null)
        SoftInfoRow(icon: Icons.folder_rounded, label: 'Job', value: jobDisplay),
      if (clientId != null)
        SoftInfoRow(icon: Icons.business_rounded, label: 'Client', value: clientDisplay),
      if (_taskName.isNotEmpty || _isLoadingNames)
        SoftInfoRow(icon: Icons.task_alt_rounded, label: 'Task', value: taskDisplay),
    ];

    return SoftScaffold(
      title: 'Work Log Details',
      subtitle: DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              // Entry summary card
              SoftCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entry #${widget.entryIndex}',
                            style: SoftText.title(p, size: 20),
                          ),
                          if (timeFrom.isNotEmpty && timeTo.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${_formatTimeDisplay(timeFrom)} - ${_formatTimeDisplay(timeTo)}',
                              style: SoftText.caption(p, size: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SoftStatusPill(
                      label: hours,
                      color: p.success,
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Work details card
              _SectionCard(
                icon: Icons.work_rounded,
                color: p.accent,
                title: 'Work Details',
                child: Column(
                  children: [
                    for (var i = 0; i < detailRows.length; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, color: p.border),
                      detailRows[i],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Description card
              _SectionCard(
                icon: Icons.description_rounded,
                color: p.leave,
                title: 'Description',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    tasknotes,
                    style: SoftText.body(p).copyWith(height: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Attached files
              if (_attachedFiles.isNotEmpty) ...[
                _SectionCard(
                  icon: Icons.attach_file_rounded,
                  color: p.danger,
                  title: 'Attachments',
                  trailing: SoftStatusPill(
                    label: '${_attachedFiles.length}',
                    color: p.danger,
                    showDot: false,
                  ),
                  child: Column(
                    children: List.generate(_attachedFiles.length, (index) {
                      final file = _attachedFiles[index];
                      final isImage = file.type == 'image';
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SoftIconBadge(
                                  icon: isImage
                                      ? Icons.image_rounded
                                      : Icons.insert_drive_file_rounded,
                                  color: isImage ? p.accent : p.success,
                                  size: 38,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        file.name,
                                        style: SoftText.body(p, color: p.ink)
                                            .copyWith(fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isImage ? 'Image file' : 'Document',
                                        style: SoftText.caption(p),
                                      ),
                                    ],
                                  ),
                                ),
                                SoftIconButton(
                                  icon: Icons.close_rounded,
                                  size: 34,
                                  tooltip: 'Remove',
                                  onTap: () {
                                    setState(() {
                                      _attachedFiles.removeAt(index);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (index < _attachedFiles.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: p.border,
                              indent: 50,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              const SizedBox(height: 6),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SoftPillButton(
                      label: 'Attach File',
                      icon: Icons.attach_file,
                      variant: SoftPillVariant.outline,
                      onPressed: () => _showAttachFileDialog(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SoftPillButton(
                      label: 'Checklist',
                      icon: Icons.checklist,
                      onPressed: () {
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
                    ),
                  ),
                ],
              ),
            ],
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

  void _showAttachFileDialog(BuildContext context) {
    final p = SoftPalette.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text('Attach File', style: SoftText.heading(p)),
              const SizedBox(height: 18),
              _buildAttachOption(
                context,
                icon: Icons.camera_alt_outlined,
                label: 'Take Photo',
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromCamera(context);
                },
              ),
              const SizedBox(height: 10),
              _buildAttachOption(
                context,
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromGallery(context);
                },
              ),
              const SizedBox(height: 10),
              _buildAttachOption(
                context,
                icon: Icons.insert_drive_file_outlined,
                label: 'Choose Document',
                onTap: () async {
                  Navigator.pop(context);
                  await _pickDocument(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
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
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
    final p = SoftPalette.of(context);

    return Material(
      color: p.surfaceAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: p.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: SoftText.body(p, color: p.ink).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
            ],
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
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
            content: const Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File uploaded successfully!',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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

/// Soft card with an icon badge + title header and a body.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SoftIconBadge(icon: icon, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: SoftText.heading(p, size: 15.5))),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 1, color: p.border),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
