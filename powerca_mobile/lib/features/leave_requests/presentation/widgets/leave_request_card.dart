import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/leave_request.dart';

class LeaveRequestCard extends StatelessWidget {
  final LeaveRequest request;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const LeaveRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md.h),
        padding: EdgeInsets.all(AppSpacing.md.w),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(
            color: const Color(0xFFE9F0F8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date range and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14.sp,
                        color: AppTheme.textSecondaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          request.formattedDateRange,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                _buildStatusBadge(context, request.approvalStatus),
              ],
            ),

            SizedBox(height: AppSpacing.md.h),

            // Leave type and days
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.event_note,
                    label: 'Type:',
                    value: request.leaveTypeDisplay,
                  ),
                ),
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.access_time,
                    label: 'Days:',
                    value: '${request.totalLeaveDays} days',
                  ),
                ),
              ],
            ),

            // Remarks if available
            if (request.leaveRemarks != null && request.leaveRemarks!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note,
                    size: 14.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      request.leaveRemarks!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Cancel button for pending requests
            if (onCancel != null) ...[
              SizedBox(height: AppSpacing.md.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor, width: 1.5),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: const Text('Cancel Request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'P':
        backgroundColor = const Color(0xFFFFF4E6); // Light orange
        textColor = AppTheme.warningColor;
        break;
      case 'A':
        backgroundColor = const Color(0xFFE8F5E9); // Light green
        textColor = AppTheme.successColor;
        break;
      case 'R':
        backgroundColor = const Color(0xFFFFEBEE); // Light red
        textColor = AppTheme.errorColor;
        break;
      case 'C':
        backgroundColor = const Color(0xFFEEEEEE); // Light gray
        textColor = AppTheme.textSecondaryColor;
        break;
      default:
        backgroundColor = const Color(0xFFE3EFFF);
        textColor = AppTheme.primaryColor;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: Text(
        request.statusDisplay,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14.sp,
          color: AppTheme.textSecondaryColor,
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
