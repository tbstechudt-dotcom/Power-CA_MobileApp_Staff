import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';

import '../../../../app/theme.dart';
import '../pages/work_log_entry_form_page.dart';

/// Modern calendar widget with proper weekend coloring using flutter_calendar_carousel
class ModernWorkCalendar extends StatefulWidget {
  final int staffId;

  const ModernWorkCalendar({
    super.key,
    required this.staffId,
  });

  @override
  State<ModernWorkCalendar> createState() => _ModernWorkCalendarState();
}

class _ModernWorkCalendarState extends State<ModernWorkCalendar> {
  Map<DateTime, int> _workDays = {};
  Map<DateTime, List<Map<String, dynamic>>> _workEntriesByDate = {};
  List<Map<String, dynamic>> _allWorkEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  EventList<Event> _markedDateMap = EventList<Event>(events: {});
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _selectedDateEntries = [];

  @override
  void initState() {
    super.initState();
    _loadWorkDiaryData();
  }

  Future<void> _loadWorkDiaryData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('workdiary')
          .select('*')
          .eq('staff_id', widget.staffId)
          .order('date', ascending: false);

      final Map<DateTime, int> counts = {};
      final Map<DateTime, List<Event>> events = {};
      final Map<DateTime, List<Map<String, dynamic>>> entriesByDate = {};
      final List<Map<String, dynamic>> allEntries = [];

      for (var entry in response) {
        if (entry['date'] != null) {
          try {
            final date = DateTime.parse(entry['date'] as String);
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;

            // Store full entry data
            allEntries.add(entry as Map<String, dynamic>);

            if (entriesByDate[normalized] == null) {
              entriesByDate[normalized] = [];
            }
            entriesByDate[normalized]!.add(entry as Map<String, dynamic>);

            // Add event marker for this date
            if (events[normalized] == null) {
              events[normalized] = [];
            }
            events[normalized]!.add(Event(
              date: normalized,
              title: 'Work Entry',
              icon: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                width: 6.w,
                height: 6.h,
              ),
            ),);
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      setState(() {
        _workDays = counts;
        _workEntriesByDate = entriesByDate;
        _allWorkEntries = allEntries;
        _markedDateMap = EventList<Event>(events: events);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  void _onDateSelected(DateTime date, List<Event> events) {
    final normalized = DateTime(date.year, date.month, date.day);
    final entries = _workEntriesByDate[normalized] ?? [];

    // If no entries for this date, navigate to work log entry form
    if (entries.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkLogEntryFormPage(
            selectedDate: normalized,
            staffId: widget.staffId,
          ),
        ),
      ).then((result) {
        // Reload data if form was submitted successfully
        if (result == true) {
          _loadWorkDiaryData();
        }
      });
    } else {
      // Show entries for dates that have data
      setState(() {
        _selectedDate = normalized;
        _selectedDateEntries = entries;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE9F0F8), width: 1),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with loading indicator
          Row(
            children: [
              Text(
                'Work Log Calendar',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF080E29),
                ),
              ),
              if (_isLoading) ...{
                SizedBox(width: 12.w),
                SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              },
            ],
          ),
          SizedBox(height: 16.h),

          // Error message (if any)
          if (_errorMessage != null)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Calendar
          CalendarCarousel<Event>(
            onDayPressed: _onDateSelected,
            weekendTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFEF1E05),  // RED for weekends
            ),
            thisMonthDayBorderColor: Colors.transparent,
            weekdayTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF080E29),
            ),
            weekFormat: false,
            markedDatesMap: _markedDateMap,
            height: 350.h,
            selectedDateTime: null,  // No selection
            daysHaveCircularBorder: false,
            showOnlyCurrentMonthDate: false,
            customGridViewPhysics: const NeverScrollableScrollPhysics(),
            markedDateShowIcon: true,
            markedDateIconMaxShown: 1,
            markedDateIconMargin: 4,
            markedDateMoreShowTotal: null,
            showHeader: true,
            todayTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            todayButtonColor: AppTheme.primaryColor,
            selectedDayTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            minSelectedDate: null,
            maxSelectedDate: null,
            prevDaysTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFA8A8A8),  // Gray for previous month
            ),
            inactiveDaysTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFA8A8A8),  // Gray for next month
            ),
            onCalendarChanged: (DateTime date) {
              // Calendar month changed - no action needed
            },
            daysTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF080E29),  // Black for regular days
            ),
            headerTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF080E29),
            ),
            headerMargin: EdgeInsets.only(bottom: 16.h),
            childAspectRatio: 1.2,
            iconColor: const Color(0xFF080E29),
          ),

          SizedBox(height: 12.h),

          // Data summary
          if (!_isLoading && _workDays.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8.w),
                  Text(
                    'Loaded ${_workDays.length} days with work entries',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8F8E90),
                    ),
                  ),
                ],
              ),
            ),

          // No data message
          if (!_isLoading && _workDays.isEmpty && _errorMessage == null)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'No work diary entries found for staff ID ${widget.staffId}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF8F8E90),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Selected Date Work Entries
          if (_selectedDate != null) ...[
            SizedBox(height: 16.h),
            Divider(color: const Color(0xFFE9F0F8), thickness: 1),
            SizedBox(height: 16.h),
            _buildSelectedDateHeader(),
            SizedBox(height: 12.h),
            if (_selectedDateEntries.isEmpty)
              _buildNoEntriesForDate()
            else
              ..._selectedDateEntries.map((entry) => _buildWorkEntryCard(entry)),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDateHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Logs',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'For ${_formatSelectedDate()}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF8F8E90),
              ),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            '${_selectedDateEntries.length} ${_selectedDateEntries.length == 1 ? 'entry' : 'entries'}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoEntriesForDate() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20.sp,
            color: const Color(0xFF8F8E90),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'No work entries for this date',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF8F8E90),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkEntryCard(Map<String, dynamic> entry) {
    final description = entry['wdescription'] ?? 'No description';
    final hours = entry['hours']?.toString() ?? '0';
    final jobName = entry['job_name'] ?? 'N/A';
    final jobId = entry['job_id']?.toString() ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE9F0F8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with hours
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  jobName,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF080E29),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14.sp,
                      color: const Color(0xFF4CAF50),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${hours}h',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (jobId.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              'Job ID: $jobId',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFA8A8A8),
              ),
            ),
          ],

          SizedBox(height: 8.h),

          // Description
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF8F8E90),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatSelectedDate() {
    if (_selectedDate == null) return '';

    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final day = _selectedDate!.day;
    final month = months[_selectedDate!.month - 1];
    final year = _selectedDate!.year;

    return '$day $month $year';
  }
}
