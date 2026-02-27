import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../auth/domain/entities/staff.dart';
import 'leave_detail_page.dart';

class LeaveHistoryPage extends StatelessWidget {
  final Staff currentStaff;
  final List<Map<String, dynamic>> leaves;
  final DateTime financialYearStart;
  final DateTime financialYearEnd;

  const LeaveHistoryPage({
    super.key,
    required this.currentStaff,
    required this.leaves,
    required this.financialYearStart,
    required this.financialYearEnd,
  });

  List<DateTime> _financialYearMonths() {
    final months = <DateTime>[];
    DateTime cursor = DateTime(financialYearStart.year, financialYearStart.month, 1);
    final end = DateTime(financialYearEnd.year, financialYearEnd.month, 1);

    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months;
  }

  List<Map<String, dynamic>> _leavesForMonth(DateTime month) {
    final items = leaves.where((leave) {
      final fromDate = leave['fromDate'] as DateTime;
      return fromDate.year == month.year && fromDate.month == month.month;
    }).toList();

    items.sort((a, b) {
      final aDate = a['fromDate'] as DateTime;
      final bDate = b['fromDate'] as DateTime;
      return aDate.compareTo(bDate);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    final months = _financialYearMonths();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: titleColor,
        elevation: 0,
        title: Text(
          'Leave History',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            child: Text(
              'FY ${DateFormat('MMM yyyy').format(financialYearStart)} - ${DateFormat('MMM yyyy').format(financialYearEnd)}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(12.w),
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final monthLeaves = _leavesForMonth(month);
                final isCurrentMonth = month.year == now.year && month.month == now.month;

                return Container(
                  margin: EdgeInsets.only(bottom: 10.h),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isCurrentMonth ? AppTheme.primaryColor : borderColor,
                      width: isCurrentMonth ? 1.4 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isCurrentMonth ? AppTheme.primaryColor : Colors.black)
                            .withValues(alpha: isCurrentMonth ? 0.18 : (isDarkMode ? 0.18 : 0.06)),
                        blurRadius: isCurrentMonth ? 14 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: isCurrentMonth,
                    tilePadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                    childrenPadding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
                    iconColor: AppTheme.primaryColor,
                    collapsedIconColor: subtitleColor,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy').format(month),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                        ),
                        if (isCurrentMonth)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'Current',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${monthLeaves.length} ${monthLeaves.length == 1 ? 'leave' : 'leaves'}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                    children: monthLeaves.isEmpty
                        ? [
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(
                                'No leave records for this month',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor,
                                ),
                              ),
                            ),
                          ]
                        : monthLeaves.map((leave) {
                            final fromDate = leave['fromDate'] as DateTime;
                            final toDate = leave['toDate'] as DateTime;
                            final type = leave['type'] as String? ?? 'Unknown';
                            final displayReason = leave['displayReason'] as String? ?? '';

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LeaveDetailPage(
                                      leave: leave,
                                      onDeleted: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: EdgeInsets.only(top: 8.h),
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_note_rounded,
                                      size: 18.sp,
                                      color: AppTheme.primaryColor,
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${DateFormat('dd MMM yyyy').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                              color: titleColor,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            '$type${displayReason.isNotEmpty ? ' - $displayReason' : ''}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20.sp,
                                      color: subtitleColor,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 2,
        currentStaff: currentStaff,
      ),
    );
  }
}
