import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';

class LeaveBalanceCard extends StatelessWidget {
  final Map<String, double> balance;

  const LeaveBalanceCard({
    super.key,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2255FC), Color(0xFF4A7BFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave Balance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Wrap(
            spacing: AppSpacing.md.w,
            runSpacing: AppSpacing.sm.h,
            children: balance.entries.map((entry) {
              return _buildBalanceItem(
                context,
                _getLeaveTypeName(entry.key),
                entry.value,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(BuildContext context, String type, double days) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          SizedBox(height: 2.h),
          Text(
            '${days.toStringAsFixed(1)} days',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _getLeaveTypeName(String code) {
    switch (code) {
      case 'AL':
        return 'Annual Leave';
      case 'SL':
        return 'Sick Leave';
      case 'CL':
        return 'Casual Leave';
      case 'ML':
        return 'Maternity';
      case 'PL':
        return 'Paternity';
      case 'UL':
        return 'Unpaid';
      default:
        return code;
    }
  }
}
