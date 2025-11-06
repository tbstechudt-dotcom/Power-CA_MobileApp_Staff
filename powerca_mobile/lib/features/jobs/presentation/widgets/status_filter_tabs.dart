import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';

class StatusFilterTabs extends StatelessWidget {
  final String selectedStatus;
  final Map<String, int> statusCounts;
  final Function(String) onStatusChanged;

  const StatusFilterTabs({
    super.key,
    required this.selectedStatus,
    required this.statusCounts,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      'All',
      'Waiting',
      'Planning',
      'Progress',
      'Work Done',
      'Delivery',
      'Closed',
    ];

    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (context, index) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final status = statuses[index];
          final count = statusCounts[status] ?? 0;
          final isSelected = selectedStatus == status;

          return _buildTab(
            status: status,
            count: count,
            isSelected: isSelected,
            onTap: () => onStatusChanged(status),
          );
        },
      ),
    );
  }

  Widget _buildTab({
    required String status,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE9F0F8),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            '$status ${count > 0 ? "($count)" : ""}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF080E29),
            ),
          ),
        ),
      ),
    );
  }
}
