import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import 'work_log_entry_form_page.dart';
import 'work_log_detail_page.dart';

/// Work Log List Page - Redesigned to match Jobs Page style
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
    // Check if dark mode is enabled
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: scaffoldBgColor,
        body: Column(
          children: [
            // Status bar area
            Container(
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              child: SafeArea(
                bottom: false,
                child: _buildHeader(),
              ),
            ),
            Expanded(
                child: _entries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadClientAndJobNames();
                        },
                        color: AppTheme.primaryColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary Cards Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryCard(
                                      title: 'Total Time',
                                      value: _formatMinutesToHours(_calculateTotalMinutes()),
                                      icon: Icons.schedule_rounded,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      title: 'Entries',
                                      value: '${_entries.length}',
                                      icon: Icons.assignment_rounded,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Section Title
                              Row(
                                children: [
                                  Container(
                                    width: 4.w,
                                    height: 18.h,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Work Entries',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_entries.length} ${_entries.length == 1 ? 'entry' : 'entries'}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.h),

                              // Entries List
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: _entries.length,
                                itemBuilder: (context, index) {
                                  return _buildEntryCard(_entries[index], index + 1);
                                },
                              ),
                              SizedBox(height: 80.h), // Space for FAB
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildHeader() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final backBtnBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backBtnBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      color: headerBgColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              width: 42.w,
              height: 42.h,
              decoration: BoxDecoration(
                color: backBtnBgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: backBtnBorderColor,
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18.sp,
                  color: isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textSecondaryColor,
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
                  'Work Log',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final valueColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final labelColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDarkMode ? 0.15 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDarkMode ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  icon,
                  size: 20.sp,
                  color: color,
                ),
              ),
              Icon(
                Icons.trending_up_rounded,
                size: 16.sp,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: isDarkMode ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.post_add_rounded,
                size: 48.sp,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Entries Yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Start logging your work for this day',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: subtitleColor,
              ),
            ),
            SizedBox(height: 24.h),
            GestureDetector(
              onTap: () => _addNewEntry(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18.sp,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Add Entry',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry, int index) {
    final tasknotes = entry['tasknotes'] ?? '';
    final minutes = entry['minutes'] ?? 0;
    final hours = _formatMinutesToHours(minutes);
    final jobId = entry['job_id'];
    final clientId = entry['client_id'];
    final timeFrom = entry['timefrom'];
    final timeTo = entry['timeto'];
    final date = entry['date'];

    final clientName = clientId != null ? _clientNames[clientId] : null;
    final jobName = jobId != null ? _jobNames[jobId] : null;
    final hasTimeRange = timeFrom != null && timeTo != null;

    // Format date for display
    String formattedDate = '';
    if (date != null) {
      try {
        final dateObj = DateTime.parse(date.toString());
        formattedDate = DateFormat('yyyy-MM-dd').format(dateObj);
      } catch (e) {
        formattedDate = date.toString();
      }
    }

    // Check if dark mode is enabled
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    // Theme-aware colors
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final timeBgColor = isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF);
    final timeTextColor = isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF334155);
    final chevronColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

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
              jobName: jobName,
              clientName: clientName,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Main Content
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row - Job name and duration badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoadingNames
                                  ? 'Loading...'
                                  : (jobName ?? 'Job #$jobId'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (clientId != null) ...[
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(4.w),
                                    decoration: BoxDecoration(
                                      color: iconBgColor,
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Icon(
                                      Icons.business_rounded,
                                      size: 12.sp,
                                      color: subtitleColor,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Flexible(
                                    child: Text(
                                      _isLoadingNames
                                          ? 'Loading...'
                                          : (clientName ?? 'Client #$clientId'),
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: subtitleColor,
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
                      SizedBox(width: 12.w),
                      // Duration badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          hours,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Container(
                      height: 1,
                      color: dividerColor,
                    ),
                  ),

                  // Details Section
                  Row(
                    children: [
                      // Time range
                      if (hasTimeRange) ...[
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: timeBgColor,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Icon(
                            Icons.schedule_rounded,
                            size: 14.sp,
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${_formatTimeDisplay(timeFrom)} - ${_formatTimeDisplay(timeTo)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: timeTextColor,
                          ),
                        ),
                        SizedBox(width: 16.w),
                      ],
                      // Date with notes
                      if (formattedDate.isNotEmpty || tasknotes.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Icon(
                            Icons.event_note_rounded,
                            size: 14.sp,
                            color: subtitleColor,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            tasknotes.isNotEmpty
                                ? '$formattedDate - $tasknotes'
                                : formattedDate,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      // Chevron
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: chevronColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _addNewEntry(context),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        icon: Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 22.sp,
        ),
        label: Text(
          'New Entry',
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

  Future<void> _reloadEntries() async {
    try {
      final supabase = Supabase.instance.client;
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

      final response = await supabase
          .from('workdiary')
          .select()
          .eq('staff_id', widget.staffId)
          .eq('date', dateStr)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _entries = List<Map<String, dynamic>>.from(response);
          _isLoadingNames = true;
        });
        await _loadClientAndJobNames();
      }
    } catch (e) {
      debugPrint('Error reloading entries: $e');
    }
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
        // Reload entries to show the new one
        _reloadEntries();
      }
    });
  }

  int _calculateTotalMinutes() {
    int totalMinutes = 0;
    for (var entry in _entries) {
      final minutes = entry['minutes'] ?? 0;
      totalMinutes += minutes as int;
    }
    return totalMinutes;
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
    if (timeValue == null) return '';

    String timeStr = timeValue.toString();

    // If it contains 'T', it's a full datetime - extract just the time part
    if (timeStr.contains('T')) {
      timeStr = timeStr.split('T')[1];
    }

    // Remove timezone info (+00, -05:30, Z, etc.)
    timeStr = timeStr.split('+')[0].split('Z')[0];
    if (timeStr.contains('-') && timeStr.indexOf('-') > 2) {
      // Handle negative timezone like -05:30 but not time like 12:30
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
}
