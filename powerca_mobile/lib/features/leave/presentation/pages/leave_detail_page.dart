import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with gradient
          SliverAppBar(
            expandedHeight: 180.h,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 20.sp),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave Request',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            leave['type'],
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status and Duration Row
                  Row(
                    children: [
                      // Status Card
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 48.w,
                                height: 48.w,
                                decoration: BoxDecoration(
                                  color: (leave['statusColor'] as Color).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  leave['status'] == 'Approved'
                                      ? Icons.check_circle_rounded
                                      : leave['status'] == 'Rejected'
                                          ? Icons.cancel_rounded
                                          : Icons.schedule_rounded,
                                  size: 24.sp,
                                  color: leave['statusColor'],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8F8E90),
                                ),
                              ),
                              SizedBox(height: 4.h),
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
                      ),
                      SizedBox(width: 12.w),
                      // Duration Card
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 48.w,
                                height: 48.w,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.timer_outlined,
                                  size: 24.sp,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Duration',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8F8E90),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '$daysDisplay ${days == 1 ? 'Day' : 'Days'}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
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
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.date_range_rounded,
                              size: 20.sp,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Date Details',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF080E29),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),

                        // Check if single day leave (same from and to date)
                        if (fromDate.year == toDate.year &&
                            fromDate.month == toDate.month &&
                            fromDate.day == toDate.day) ...[
                          // Single Date
                          _buildDateRow(
                            label: 'Date',
                            date: fromDate,
                            dayType: fromDayType,
                            color: AppTheme.primaryColor,
                          ),
                        ] else ...[
                          // From Date
                          _buildDateRow(
                            label: 'From',
                            date: fromDate,
                            dayType: fromDayType,
                            color: const Color(0xFF10B981),
                          ),

                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            child: Row(
                              children: [
                                SizedBox(width: 20.w),
                                Container(
                                  width: 2,
                                  height: 30.h,
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ],
                            ),
                          ),

                          // To Date
                          _buildDateRow(
                            label: 'To',
                            date: toDate,
                            dayType: toDayType,
                            color: const Color(0xFFEF4444),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Reason Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 20.sp,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Reason',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF080E29),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          cleanReason.isEmpty ? 'No reason provided' : cleanReason,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: cleanReason.isEmpty
                                ? const Color(0xFF8F8E90)
                                : const Color(0xFF374151),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Applied Date Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.access_time_rounded,
                            size: 22.sp,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Applied On',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF8F8E90),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(leave['appliedDate']),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF080E29),
                              ),
                            ),
                            Text(
                              DateFormat('hh:mm a').format(leave['appliedDate']),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                          foregroundColor: AppTheme.errorColor,
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

  Widget _buildDateRow({
    required String label,
    required DateTime date,
    required String dayType,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: color,
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
                  color: const Color(0xFF080E29),
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: dayType == 'Full Day'
                      ? const Color(0xFFF3F4F6)
                      : AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  dayType,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: dayType == 'Full Day'
                        ? const Color(0xFF6B7280)
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
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
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.errorColor,
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
            color: const Color(0xFF6B7280),
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
                color: const Color(0xFF8F8E90),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteLeaveRequest(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
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
        ),
      );
    }
  }
}
