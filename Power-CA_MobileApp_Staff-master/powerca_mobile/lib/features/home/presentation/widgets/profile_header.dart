import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String role;
  final String? avatarUrl;
  final VoidCallback onEditPressed;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.role,
    this.avatarUrl,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 70.w,
            height: 70.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0846B1).withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),

          SizedBox(width: 14.w),

          // Name and Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF080E29), // Accent from Figma
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  role,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Edit Button
          ElevatedButton(
            onPressed: onEditPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              minimumSize: Size(0, 36.h),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(Icons.edit_outlined, size: 18.sp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Icon(
        Icons.person,
        size: 40.sp,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
