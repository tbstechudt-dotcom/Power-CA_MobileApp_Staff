import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_calendar_carousel/flutter_calendar_carousel.dart';
import 'package:flutter_calendar_carousel/classes/event.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../pages/work_log_entry_form_page.dart';
import '../pages/work_log_list_page.dart';

/// Modern calendar widget with proper weekend coloring using flutter_calendar_carousel
class ModernWorkCalendar extends StatefulWidget {
  final int staffId;
  final VoidCallback? onDataReloaded;

  const ModernWorkCalendar({
    super.key,
    required this.staffId,
    this.onDataReloaded,
  });

  @override
  State<ModernWorkCalendar> createState() => _ModernWorkCalendarState();
}

class _ModernWorkCalendarState extends State<ModernWorkCalendar> {
  Map<DateTime, int> _workDays = {};
  Map<DateTime, List<Map<String, dynamic>>> _workEntriesByDate = {};
  // ignore: unused_field
  List<Map<String, dynamic>> _allWorkEntries = [];
  bool _isLoading = true;
  String? _errorMessage;
  EventList<Event> _markedDateMap = EventList<Event>(events: {});
  int _workingDaysInMonth = 0;
  DateTime _displayedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _calculateHolidays(_displayedMonth);
    _loadWorkDiaryData();
  }

  /// Count Sundays and working days in the given month
  void _calculateHolidays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    int sundays = 0;
    DateTime day = firstDay;
    while (!day.isAfter(lastDay)) {
      if (day.weekday == DateTime.sunday) sundays++;
      day = day.add(const Duration(days: 1));
    }
    setState(() {
      _workingDaysInMonth = lastDay.day - sundays;
      _displayedMonth = month;
    });
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
      final Map<DateTime, List<Map<String, dynamic>>> entriesByDate = {};
      final List<Map<String, dynamic>> allEntries = [];

      for (var entry in response) {
        if (entry['date'] != null) {
          try {
            final date = DateTime.parse(entry['date'] as String);
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;

            // Store full entry data
            allEntries.add(entry);

            if (entriesByDate[normalized] == null) {
              entriesByDate[normalized] = [];
            }
            entriesByDate[normalized]!.add(entry);
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      setState(() {
        _workDays = counts;
        _workEntriesByDate = entriesByDate;
        _allWorkEntries = allEntries;
        // Use empty markedDateMap since we're using customDayBuilder for rendering
        _markedDateMap = EventList<Event>(events: {});
        _isLoading = false;
      });

      // Notify parent that data was reloaded
      widget.onDataReloaded?.call();
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
      // Navigate to Work Log List Page to view entries
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkLogListPage(
            selectedDate: normalized,
            entries: entries,
            staffId: widget.staffId,
          ),
        ),
      ).then((result) {
        // Reload data if any changes were made
        if (result == true) {
          _loadWorkDiaryData();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : AppTheme.textPrimaryColor;
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;
    final iconBgColor = isDarkMode ? const Color(0xFF2563EB).withValues(alpha: 0.2) : const Color(0xFF2563EB).withValues(alpha: 0.1);
    final errorBgColor = isDarkMode ? const Color(0xFF7F1D1D) : const Color(0xFFFFEBEE);
    final errorTextColor = isDarkMode ? const Color(0xFFFCA5A5) : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 16.h, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: const Color(0xFF2563EB),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work Log',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: textPrimaryColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  if (_isLoading)
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: textSecondaryColor,
                      ),
                    )
                  else
                    Text(
                      '${_workDays.length} days logged',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: textSecondaryColor,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Working days & Holidays badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Working days badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.work_rounded,
                          size: 14.sp,
                          color: const Color(0xFF10B981),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '$_workingDaysInMonth Working',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_isLoading) ...[
                SizedBox(width: 8.w),
                SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 16.h),

          // Error message (if any)
          if (_errorMessage != null)
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: errorBgColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: errorTextColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        color: errorTextColor,
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
            // Custom day builder to show green dates with dots
            customDayBuilder: (
              bool isSelectable,
              int index,
              bool isSelectedDay,
              bool isToday,
              bool isPrevMonthDay,
              TextStyle textStyle,
              bool isNextMonthDay,
              bool isThisMonthDay,
              DateTime day,
            ) {
              final normalized = DateTime(day.year, day.month, day.day);
              final entryCount = _workDays[normalized] ?? 0;
              final hasEntries = entryCount > 0;

              // Custom rendering for dates with work log entries
              if (hasEntries && isThisMonthDay) {
                // Use white text and dots for today, green for other dates
                final isCurrentDate = isToday;
                final textColor = isCurrentDate
                    ? Colors.white  // White text for today
                    : isDarkMode
                        ? const Color(0xFF4ADE80)  // Light green for dark mode
                        : const Color(0xFF2E7D32);  // Dark green for light mode
                final dotColor = isCurrentDate
                    ? Colors.white  // White dots for today
                    : const Color(0xFF4CAF50);  // Green dots for others

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Enhanced container with gradient and shadow
                      Container(
                        decoration: BoxDecoration(
                          gradient: isCurrentDate
                              ? LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.primaryColor.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: isDarkMode
                                      ? [
                                          const Color(0xFF4CAF50).withOpacity(0.3),
                                          const Color(0xFF4CAF50).withOpacity(0.2),
                                        ]
                                      : [
                                          const Color(0xFF4CAF50).withOpacity(0.2),
                                          const Color(0xFF4CAF50).withOpacity(0.12),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          shape: BoxShape.circle,
                          boxShadow: isCurrentDate
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50).withOpacity(isDarkMode ? 0.25 : 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        width: 32.w,
                        height: 32.h,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      // Position dots at the bottom with improved styling
                      Positioned(
                        bottom: 3.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            entryCount > 3 ? 3 : entryCount,
                            (index) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 1.5.w),
                                width: 5.w,
                                height: 5.h,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: dotColor.withOpacity(0.5),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Entry count badge for 3+ entries
                      if (entryCount > 3)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: BoxConstraints(
                              minWidth: 14.w,
                              minHeight: 14.h,
                            ),
                            child: Center(
                              child: Text(
                                '$entryCount',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }

              // Return null for default rendering
              return null;
            },
            weekdayTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
            ),
            weekFormat: false,
            markedDatesMap: _markedDateMap,
            height: 310.h,
            selectedDateTime: null,  // No selection
            daysHaveCircularBorder: true,
            showOnlyCurrentMonthDate: false,
            customGridViewPhysics: const NeverScrollableScrollPhysics(),
            markedDateShowIcon: false, // Disabled - using custom dots in customDayBuilder
            markedDateIconMaxShown: 0,
            markedDateMoreShowTotal: null,
            showHeader: true,
            todayTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            todayButtonColor: const Color(0xFF2563EB),
            selectedDayTextStyle: TextStyle(
              fontFamily: 'Inter',
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
              color: isDarkMode ? const Color(0xFF475569) : const Color(0xFFA8A8A8),  // Gray for previous month
            ),
            inactiveDaysTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: isDarkMode ? const Color(0xFF475569) : const Color(0xFFA8A8A8),  // Gray for next month
            ),
            onCalendarChanged: (DateTime date) {
              _calculateHolidays(date);
            },
            daysTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29),  // Text color for regular days
            ),
            headerTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: textPrimaryColor,
            ),
            headerMargin: EdgeInsets.only(bottom: 12.h),
            childAspectRatio: 1.15,
            iconColor: isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}
