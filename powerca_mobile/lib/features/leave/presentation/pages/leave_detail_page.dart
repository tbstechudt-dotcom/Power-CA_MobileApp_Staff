import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';

class LeaveDetailPage extends StatelessWidget {
  final Map<String, dynamic> leave;
  final VoidCallback onDeleted;

  const LeaveDetailPage({
    super.key,
    required this.leave,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final backBtnBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backBtnBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final backBtnIconColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textSecondaryColor;
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textMutedColor;

    final fromDate = leave['fromDate'] as DateTime;
    final toDate = leave['toDate'] as DateTime;
    final days = leave['days'] as double;
    final daysDisplay = days == days.toInt() ? days.toInt().toString() : days.toStringAsFixed(1);
    final reason = leave['reason'] as String;

    // Parse half-day information from the original reason stored in database
    String fromDayType = 'Full Day';
    String toDayType = 'Full Day';
    String cleanReason = reason;

    // Check for half-day tags in reason
    if (reason.contains('[First Half]')) {
      fromDayType = 'First Half';
      toDayType = 'First Half';
      cleanReason = reason.replaceAll(RegExp(r'\s*\[First Half\]'), '').trim();
    } else if (reason.contains('[Second Half]')) {
      fromDayType = 'Second Half';
      toDayType = 'Second Half';
      cleanReason = reason.replaceAll(RegExp(r'\s*\[Second Half\]'), '').trim();
    } else if (reason.contains('[Start:') || reason.contains('[End:')) {
      if (reason.contains('[Start: First Half]')) {
        fromDayType = 'First Half';
      } else if (reason.contains('[Start: Second Half]')) {
        fromDayType = 'Second Half';
      }
      if (reason.contains('[End: First Half]')) {
        toDayType = 'First Half';
      } else if (reason.contains('[End: Second Half]')) {
        toDayType = 'Second Half';
      }
      cleanReason = reason
          .replaceAll(RegExp(r'\s*\[Start: (First Half|Second Half)\]'), '')
          .replaceAll(RegExp(r'\s*\[End: (First Half|Second Half)\]'), '')
          .trim();
    }

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Column(
        children: [
          // Header area
          Container(
            color: headerBgColor,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                color: headerBgColor,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                            color: backBtnIconColor,
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
                            'Leave Request',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            leave['type'],
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
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats Row (Status & Duration)
                  Row(
                    children: [
                      // Status Card
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.w,
                                decoration: BoxDecoration(
                                  color: (leave['statusColor'] as Color).withValues(alpha: isDarkMode ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  leave['status'] == 'Approved'
                                      ? Icons.check_circle_rounded
                                      : leave['status'] == 'Rejected'
                                          ? Icons.cancel_rounded
                                          : Icons.schedule_rounded,
                                  size: 20.sp,
                                  color: leave['statusColor'],
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      leave['status'],
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: leave['statusColor'],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Duration Card
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.w,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  Icons.timer_outlined,
                                  size: 20.sp,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Duration',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '$daysDisplay ${days == 1 ? 'Day' : 'Days'}',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  // Date Details Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.w,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFF0EA5E9).withValues(alpha: 0.2) : const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20.sp,
                                    color: const Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Date Details',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, thickness: 1, color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        // Content
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            children: [
                              // Check if single day leave
                              if (fromDate.year == toDate.year &&
                                  fromDate.month == toDate.month &&
                                  fromDate.day == toDate.day) ...[
                                _buildDateItem(
                                  context: context,
                                  label: 'Date',
                                  date: fromDate,
                                  dayType: fromDayType,
                                  iconBgColor: isDarkMode ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFFEEF2FF),
                                  iconColor: const Color(0xFF6366F1),
                                  showDivider: false,
                                ),
                              ] else ...[
                                _buildDateItem(
                                  context: context,
                                  label: 'From',
                                  date: fromDate,
                                  dayType: fromDayType,
                                  iconBgColor: isDarkMode ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFD1FAE5),
                                  iconColor: const Color(0xFF10B981),
                                  showDivider: true,
                                ),
                                _buildDateItem(
                                  context: context,
                                  label: 'To',
                                  date: toDate,
                                  dayType: toDayType,
                                  iconBgColor: isDarkMode ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFFFEE2E2),
                                  iconColor: const Color(0xFFEF4444),
                                  showDivider: false,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Reason Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Row(
                            children: [
                              Container(
                                width: 40.w,
                                height: 40.w,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? const Color(0xFFA855F7).withValues(alpha: 0.2) : const Color(0xFFFDF4FF),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.description_rounded,
                                    size: 20.sp,
                                    color: const Color(0xFFA855F7),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Reason',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, thickness: 1, color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        // Content
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            cleanReason.isEmpty ? 'No reason provided' : cleanReason,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: cleanReason.isEmpty
                                  ? (isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                  : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Applied On Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.access_time_rounded,
                                size: 20.sp,
                                color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Applied On',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                    color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  DateFormat('EEEE, dd MMMM yyyy').format(leave['appliedDate']),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  DateFormat('hh:mm a').format(leave['appliedDate']),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                    color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Delete Button (only for pending)
                  if (leave['status'] == 'Pending')
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: () => _showDeleteConfirmation(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE2E2),
                          foregroundColor: const Color(0xFFEF4444),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'Delete Request',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem({
    required BuildContext context,
    required String label,
    required DateTime date,
    required String dayType,
    required Color iconBgColor,
    required Color iconColor,
    required bool showDivider,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(date),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: textPrimaryColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: dayType == 'Full Day'
                            ? (isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                            : iconBgColor,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        dayType,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: dayType == 'Full Day'
                              ? (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                              : iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 52.w,
          ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              'Delete Request?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this leave request? This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteLeaveRequest(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLeaveRequest(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('learequest')
          .delete()
          .eq('learequest_id', leave['id']);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
              SizedBox(width: 8.w),
              const Text('Leave request deleted successfully'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );

      onDeleted();
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting leave request: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
      );
    }
  }
}
