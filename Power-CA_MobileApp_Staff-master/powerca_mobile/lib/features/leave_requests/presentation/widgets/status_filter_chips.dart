import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';

class StatusFilterChips extends StatelessWidget {
  final String? selectedStatus;
  final Map<String, int> statusCounts;
  final Function(String?) onStatusChanged;

  const StatusFilterChips({
    super.key,
    this.selectedStatus,
    required this.statusCounts,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            'All',
            null,
            statusCounts['All'] ?? 0,
          ),
          SizedBox(width: AppSpacing.sm.w),
          _buildFilterChip(
            'Pending',
            'P',
            statusCounts['P'] ?? 0,
          ),
          SizedBox(width: AppSpacing.sm.w),
          _buildFilterChip(
            'Approved',
            'A',
            statusCounts['A'] ?? 0,
          ),
          SizedBox(width: AppSpacing.sm.w),
          _buildFilterChip(
            'Rejected',
            'R',
            statusCounts['R'] ?? 0,
          ),
          SizedBox(width: AppSpacing.sm.w),
          _buildFilterChip(
            'Cancelled',
            'C',
            statusCounts['C'] ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, int count) {
    final isSelected = selectedStatus == value;

    return InkWell(
      onTap: () => onStatusChanged(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(AppRadius.xs.r),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
