import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import 'work_log_detail_page.dart';

/// Monthly Work Log Summary Page
/// Shows all work log entries for a given month with summary stats.
class MonthlyWorkLogSummaryPage extends StatefulWidget {
  final DateTime month;
  final int staffId;

  const MonthlyWorkLogSummaryPage({
    super.key,
    required this.month,
    required this.staffId,
  });

  @override
  State<MonthlyWorkLogSummaryPage> createState() =>
      _MonthlyWorkLogSummaryPageState();
}

class _MonthlyWorkLogSummaryPageState extends State<MonthlyWorkLogSummaryPage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _entries = [];
  final Map<int, String> _clientNames = {};
  final Map<int, String> _jobNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMonthEntries();
  }

  Future<void> _fetchMonthEntries() async {
    try {
      final startOfMonth = DateTime(widget.month.year, widget.month.month, 1);
      final endOfMonth =
          DateTime(widget.month.year, widget.month.month + 1, 0);
      final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

      final response = await _supabase
          .from('workdiary')
          .select()
          .eq('staff_id', widget.staffId)
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date', ascending: false);

      final entries = List<Map<String, dynamic>>.from(response);

      // Fetch client and job names
      final clientIds = entries
          .map((e) => e['client_id'])
          .where((id) => id != null)
          .toSet()
          .toList();
      final jobIds = entries
          .map((e) => e['job_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (clientIds.isNotEmpty) {
        final clientResponse = await _supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', clientIds);
        for (var c in clientResponse) {
          _clientNames[c['client_id']] = c['clientname'] ?? 'Unknown';
        }
      }

      if (jobIds.isNotEmpty) {
        final jobResponse = await _supabase
            .from('jobshead')
            .select('job_id, work_desc')
            .inFilter('job_id', jobIds);
        for (var j in jobResponse) {
          _jobNames[j['job_id']] = j['work_desc'] ?? 'Unknown';
        }
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching monthly entries: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _totalMinutes() =>
      _entries.fold<int>(0, (sum, e) => sum + ((e['minutes'] as num?)?.toInt() ?? 0));

  int _loggedDaysCount() {
    final dates = _entries
        .map((e) => e['date']?.toString())
        .where((d) => d != null)
        .toSet();
    return dates.length;
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBg =
        isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          Container(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            child: SafeArea(
              bottom: false,
              child: _buildHeader(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchMonthEntries,
                        color: AppTheme.primaryColor,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryRow(),
                              SizedBox(height: 16.h),
                              _buildSectionTitle(),
                              SizedBox(height: 14.h),
                              ..._buildGroupedEntries(),
                              SizedBox(height: 24.h),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final headerBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final backBtnBg =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backBtnBorder =
        isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final titleColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor =
        isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      color: headerBg,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42.w,
              height: 42.h,
              decoration: BoxDecoration(
                color: backBtnBg,
                shape: BoxShape.circle,
                border: Border.all(color: backBtnBorder, width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18.sp,
                  color: isDarkMode
                      ? const Color(0xFF94A3B8)
                      : AppTheme.textSecondaryColor,
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
                  'Monthly Work Log',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  DateFormat('MMMM yyyy').format(widget.month),
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

  Widget _buildSummaryRow() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final valueColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final labelColor =
        isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;

    Widget summaryCard({
      required String title,
      required String value,
      required IconData icon,
      required Color color,
    }) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: cardBg,
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
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDarkMode ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, size: 20.sp, color: color),
              ),
              SizedBox(height: 10.h),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        summaryCard(
          title: 'Total Time',
          value: _formatMinutes(_totalMinutes()),
          icon: Icons.schedule_rounded,
          color: AppTheme.primaryColor,
        ),
        SizedBox(width: 10.w),
        summaryCard(
          title: 'Entries',
          value: '${_entries.length}',
          icon: Icons.assignment_rounded,
          color: const Color(0xFF10B981),
        ),
        SizedBox(width: 10.w),
        summaryCard(
          title: 'Days Logged',
          value: '${_loggedDaysCount()}',
          icon: Icons.calendar_today_rounded,
          color: const Color(0xFF3B82F6),
        ),
      ],
    );
  }

  Widget _buildSectionTitle() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final titleColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final mutedColor =
        isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Row(
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
            color: titleColor,
          ),
        ),
        const Spacer(),
        Text(
          '${_entries.length} ${_entries.length == 1 ? 'entry' : 'entries'}',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: mutedColor,
          ),
        ),
      ],
    );
  }

  /// Group entries by date and build date-sectioned list.
  List<Widget> _buildGroupedEntries() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final dateLabelColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dateBg =
        isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);

    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final entry in _entries) {
      final dateStr = entry['date']?.toString() ?? 'Unknown';
      grouped.putIfAbsent(dateStr, () => []).add(entry);
    }

    // Sort dates descending
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final dateStr in sortedDates) {
      final dayEntries = grouped[dateStr]!;
      final dayMinutes = dayEntries.fold<int>(
          0, (sum, e) => sum + ((e['minutes'] as num?)?.toInt() ?? 0));

      // Date header
      String formattedDate;
      try {
        formattedDate =
            DateFormat('EEE, MMM d').format(DateTime.parse(dateStr));
      } catch (_) {
        formattedDate = dateStr;
      }

      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8.h, top: widgets.isEmpty ? 0 : 8.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: dateBg,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  formattedDate,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: dateLabelColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${dayEntries.length} ${dayEntries.length == 1 ? 'entry' : 'entries'} - ${_formatMinutes(dayMinutes)}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: dateLabelColor,
                ),
              ),
            ],
          ),
        ),
      );

      for (var i = 0; i < dayEntries.length; i++) {
        widgets.add(_buildEntryCard(dayEntries[i], dateStr));
      }
    }

    return widgets;
  }

  Widget _buildEntryCard(Map<String, dynamic> entry, String dateStr) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final subtitleColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final iconBgColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final dividerColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final timeBg =
        isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF);
    final timeText =
        isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    final tasknotes = entry['tasknotes'] ?? '';
    final minutes = (entry['minutes'] as num?)?.toInt() ?? 0;
    final hours = _formatMinutes(minutes);
    final jobId = entry['job_id'];
    final clientId = entry['client_id'];
    final timeFrom = entry['timefrom'];
    final timeTo = entry['timeto'];
    final hasTimeRange = timeFrom != null && timeTo != null;

    final clientName = clientId != null ? _clientNames[clientId] : null;
    final jobName = jobId != null ? _jobNames[jobId] : null;

    return GestureDetector(
      onTap: () {
        DateTime selectedDate;
        try {
          selectedDate = DateTime.parse(dateStr);
        } catch (_) {
          selectedDate = widget.month;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkLogDetailPage(
              entry: entry,
              entryIndex: 1,
              selectedDate: selectedDate,
              staffId: widget.staffId,
              jobName: jobName,
              clientName: clientName,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: job name + duration
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jobName ?? 'Job #$jobId',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (clientId != null) ...[
                          SizedBox(height: 5.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  color: iconBgColor,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Icon(Icons.business_rounded,
                                    size: 12.sp, color: subtitleColor),
                              ),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  clientName ?? 'Client #$clientId',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.sp,
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
                  SizedBox(width: 10.w),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      hours,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              // Task notes
              if (tasknotes.toString().trim().isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Container(height: 1, color: dividerColor),
                ),
                Text(
                  tasknotes.toString(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: subtitleColor,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Time range
              if (hasTimeRange) ...[
                SizedBox(height: 8.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: timeBg,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12.sp, color: timeText),
                      SizedBox(width: 4.w),
                      Text(
                        '$timeFrom - $timeTo',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: timeText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final titleColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor =
        isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor
                    .withValues(alpha: isDarkMode ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_busy_rounded,
                  size: 48.sp, color: AppTheme.primaryColor),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Entries',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'No work log entries found for ${DateFormat('MMMM yyyy').format(widget.month)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
