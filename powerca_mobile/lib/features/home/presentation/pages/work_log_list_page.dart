import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import 'work_log_entry_form_page.dart';
import 'work_log_detail_page.dart';

/// Professional Work Log List Page - Clean Minimal Design
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20.sp, color: const Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Log',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
            Text(
              DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Summary Section
          Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.format_list_numbered,
                    value: _entries.length.toString(),
                    label: 'Entries',
                  ),
                ),
                Container(
                  width: 1,
                  height: 40.h,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    icon: Icons.access_time_filled,
                    value: _calculateTotalHours(),
                    label: 'Total Time',
                  ),
                ),
              ],
            ),
          ),

          // Entries List
          Expanded(
            child: _entries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      return _buildEntryCard(context, _entries[index], index + 1);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewEntry(context),
        backgroundColor: AppTheme.primaryColor,
        elevation: 4,
        icon: Icon(Icons.add, size: 20.sp, color: Colors.white),
        label: Text(
          'Add Entry',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24.sp, color: Colors.white.withValues(alpha: 0.9)),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.sp,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 40.sp,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No entries for this day',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap the + button to log your work',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, Map<String, dynamic> entry, int index) {
    final tasknotes = entry['tasknotes'] ?? '';
    final minutes = entry['minutes'] ?? 0;
    final hours = _formatMinutesToHours(minutes);
    final jobId = entry['job_id'];
    final clientId = entry['client_id'];
    final timeFrom = entry['timefrom'];
    final timeTo = entry['timeto'];

    final clientName = clientId != null ? _clientNames[clientId] : null;
    final jobName = jobId != null ? _jobNames[jobId] : null;
    final hasTimeRange = timeFrom != null && timeTo != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkLogDetailPage(
              entry: entry,
              entryIndex: index,
              selectedDate: widget.selectedDate,
              staffId: widget.staffId,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job Name Title Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.r),
                  topRight: Radius.circular(10.r),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.work_rounded,
                    size: 18.sp,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _isLoadingNames
                          ? 'Loading...'
                          : (jobName ?? 'Job #$jobId'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Duration Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      hours,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Area
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Row
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 18.sp,
                        color: const Color(0xFF374151),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        hasTimeRange ? '$timeFrom - $timeTo' : 'Duration: $hours',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),

                  // Task Notes
                  if (tasknotes.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    Text(
                      'Task Notes:',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      tasknotes,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF000000),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Client Info
                  if (clientId != null) ...[
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 16.sp,
                          color: const Color(0xFF374151),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Client: ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _isLoadingNames
                                ? 'Loading...'
                                : (clientName ?? 'Client #$clientId'),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF000000),
                            ),
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

            // Footer with Entry Number and Arrow
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10.r),
                  bottomRight: Radius.circular(10.r),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      'Entry #$index',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'View Details',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14.sp,
                    color: const Color(0xFF374151),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        Navigator.pop(context, true);
      }
    });
  }

  String _calculateTotalHours() {
    int totalMinutes = 0;
    for (var entry in _entries) {
      final minutes = entry['minutes'] ?? 0;
      totalMinutes += minutes as int;
    }
    return _formatMinutesToHours(totalMinutes);
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
