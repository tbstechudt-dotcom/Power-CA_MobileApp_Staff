import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';

import '../../../../app/theme.dart';

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
  bool _isLoading = true;
  String? _errorMessage;
  EventList<Event> _markedDateMap = EventList<Event>(events: {});

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
          .select('wdate')
          .eq('staff_id', widget.staffId);

      final Map<DateTime, int> counts = {};
      final Map<DateTime, List<Event>> events = {};

      for (var entry in response) {
        if (entry['wdate'] != null) {
          try {
            final date = DateTime.parse(entry['wdate'] as String);
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;

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
            onDayPressed: (DateTime date, List<Event> events) {
              // Disable selection - only show today highlight
            },
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
        ],
      ),
    );
  }
}
