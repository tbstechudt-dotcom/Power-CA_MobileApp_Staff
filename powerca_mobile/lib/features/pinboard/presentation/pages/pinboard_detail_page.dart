import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/entities/staff.dart';

class PinboardDetailPage extends StatelessWidget {
  final Staff currentStaff;
  final Map<String, dynamic> reminder;

  const PinboardDetailPage({
    super.key,
    required this.currentStaff,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final remdate = reminder['remdate'] as DateTime?;
    final remduedate = reminder['remduedate'] as DateTime?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2563EB)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reminder Details',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2563EB),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Details Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  _buildDetailRow(
                    icon: Icons.title,
                    label: 'Title',
                    value: reminder['remtitle'] as String,
                    isTitle: true,
                  ),
                  const Divider(height: 24),

                  // Type
                  _buildDetailRow(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: reminder['remtype'] as String,
                  ),
                  SizedBox(height: 12.h),

                  // Client
                  _buildDetailRow(
                    icon: Icons.business_outlined,
                    label: 'Client',
                    value: reminder['clientName'] as String,
                  ),
                  SizedBox(height: 12.h),

                  // Created Date
                  if (remdate != null) ...[
                    _buildDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created Date',
                      value: dateFormat.format(remdate),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Due Date
                  if (remduedate != null) ...[
                    _buildDetailRow(
                      icon: Icons.event_outlined,
                      label: 'Due Date',
                      value: dateFormat.format(remduedate),
                      valueColor: const Color(0xFFDC2626),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Time
                  if ((reminder['remtime'] as String).isNotEmpty) ...[
                    _buildDetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Time',
                      value: reminder['remtime'] as String,
                    ),
                    SizedBox(height: 12.h),
                  ],
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Notes Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notes_outlined,
                        size: 18.sp,
                        color: Color(0xFF6B7280),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    reminder['remnotes'] as String,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1F2937),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isTitle = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18.sp,
          color: const Color(0xFF6B7280),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: isTitle ? 16.sp : 13.sp,
                  fontWeight: isTitle ? FontWeight.w600 : FontWeight.w500,
                  color: valueColor ?? const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

