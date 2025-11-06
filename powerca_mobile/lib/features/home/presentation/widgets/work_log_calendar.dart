import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../app/theme.dart';

class WorkLogCalendar extends StatefulWidget {
  final int staffId;

  const WorkLogCalendar({
    super.key,
    required this.staffId,
  });

  @override
  State<WorkLogCalendar> createState() => _WorkLogCalendarState();
}

class _WorkLogCalendarState extends State<WorkLogCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Sample data - replace with actual data from database
  final Map<DateTime, int> _jobCounts = {
    DateTime(2025, 1, 2): 2,
    DateTime(2025, 1, 3): 3,
    DateTime(2025, 1, 4): 1,
    DateTime(2025, 1, 6): 2,
    DateTime(2025, 1, 7): 3,
    DateTime(2025, 1, 8): 2,
    DateTime(2025, 1, 9): 3,
    DateTime(2025, 1, 10): 2,
    DateTime(2025, 1, 11): 1,
    DateTime(2025, 1, 14): 4,
  };

  final Set<DateTime> _holidays = {
    DateTime(2025, 1, 1),
    DateTime(2025, 1, 5),
    DateTime(2025, 1, 12),
    DateTime(2025, 1, 19),
    DateTime(2025, 1, 26),
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  int _getJobCount(DateTime day) {
    return _jobCounts[DateTime(day.year, day.month, day.day)] ?? 0;
  }

  bool _isHoliday(DateTime day) {
    return _holidays.contains(DateTime(day.year, day.month, day.day));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE9F0F8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'Work Log Calendar',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF080E29),
              ),
            ),
          ),

          // Calendar
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: false,
              leftChevronVisible: false,
              rightChevronVisible: false,
              titleTextFormatter: (date, locale) {
                return _getMonthName(date.month).toUpperCase();
              },
              titleTextStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF080E29),
              ),
            ),
            calendarStyle: CalendarStyle(
              // Today
              todayDecoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE9F0F8),
                  width: 3,
                ),
              ),
              todayTextStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),

              // Selected
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),

              // Default
              defaultTextStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF080E29),
              ),

              // Weekend/Holiday
              weekendTextStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFEF1E05), // Red for holidays
              ),

              // Outside month
              outsideTextStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFA8A8A8),
              ),

              // Day of week labels
              tablePadding: EdgeInsets.symmetric(horizontal: 12.w),
              cellMargin: EdgeInsets.all(4.w),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF080E29),
              ),
              weekendStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF080E29),
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return _buildDayCell(day, false, false);
              },
              selectedBuilder: (context, day, focusedDay) {
                return _buildDayCell(day, true, false);
              },
              todayBuilder: (context, day, focusedDay) {
                return _buildDayCell(day, false, true);
              },
              outsideBuilder: (context, day, focusedDay) {
                return _buildDayCell(day, false, false, isOutside: true);
              },
            ),
          ),

          // Legend
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20.sp,
                  color: const Color(0xFF080E29),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Date Activities',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF080E29),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 22.sp,
                  color: const Color(0xFF080E29),
                ),
              ],
            ),
          ),

          // Job count explanation
          Padding(
            padding: EdgeInsets.only(left: 30.w, right: 35.w, bottom: 16.h),
            child: Row(
              children: [
                _buildJobCountIndicator(3),
                SizedBox(width: 10.w),
                Text(
                  'Work Job Entry Count',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day,
    bool isSelected,
    bool isToday, {
    bool isOutside = false,
  }) {
    final jobCount = _getJobCount(day);
    final isHoliday = _isHoliday(day);
    final hasJobs = jobCount > 0;

    Color textColor;
    if (isOutside) {
      textColor = const Color(0xFFA8A8A8);
    } else if (isHoliday) {
      textColor = const Color(0xFFEF1E05);
    } else if (isSelected || isToday) {
      textColor = Colors.white;
    } else {
      textColor = const Color(0xFF080E29);
    }

    return Container(
      margin: EdgeInsets.all(4.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Date number
          if (isToday)
            Container(
              width: 30.w,
              height: 30.h,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE9F0F8),
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: isOutside ? 'Inter' : 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),

          // Job count indicator
          if (hasJobs && !isOutside)
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: _buildJobCountIndicator(jobCount),
            ),
        ],
      ),
    );
  }

  Widget _buildJobCountIndicator(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count.clamp(0, 4),
        (index) => Container(
          width: 4.w,
          height: 4.h,
          margin: EdgeInsets.symmetric(horizontal: 1.w),
          decoration: BoxDecoration(
            color: count == 4 ? AppTheme.primaryColor : const Color(0xFF2255FC),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
