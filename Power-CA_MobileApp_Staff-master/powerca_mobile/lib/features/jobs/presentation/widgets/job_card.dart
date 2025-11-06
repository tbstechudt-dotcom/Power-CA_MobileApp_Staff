import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/job.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final VoidCallback? onMenuPressed;

  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
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
            // Header: Job reference, status badge, and menu
            Row(
              children: [
                // Job reference icon and number
                Icon(
                  Icons.work_outline,
                  size: 16.sp,
                  color: const Color(0xFF8F8E90),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Job No:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
                SizedBox(width: 4.w),
                Text(
                  job.jobReference,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),

                const Spacer(),

                // Status badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _parseColor(job.statusColor),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    job.status,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: _parseColor(job.statusTextColor),
                    ),
                  ),
                ),

                SizedBox(width: 8.w),

                // Menu button
                InkWell(
                  onTap: onMenuPressed,
                  child: Icon(
                    Icons.more_vert,
                    size: 20.sp,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Client name
            Text(
              job.clientName,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 6.h),

            // Job name/type
            Row(
              children: [
                Text(
                  'Job:',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    job.jobName,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8F8E90),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppTheme.primaryColor;
    }
  }
}
