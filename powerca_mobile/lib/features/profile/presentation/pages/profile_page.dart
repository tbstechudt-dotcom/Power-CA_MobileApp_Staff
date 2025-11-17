import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../auth/domain/entities/staff.dart';

class ProfilePage extends StatelessWidget {
  final Staff currentStaff;

  const ProfilePage({
    super.key,
    required this.currentStaff,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Top App Bar
            _buildModernAppBar(context),

            // Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 100.w,
                            height: 100.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF0846B1), Color(0xFF2255FC)],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                currentStaff.name.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 40.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            currentStaff.name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            currentStaff.email ?? 'No email',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.sp,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Profile Options
                    _buildProfileOption(
                      icon: Icons.person_outline,
                      title: 'Edit Profile',
                      onTap: () {},
                    ),
                    _buildProfileOption(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () {},
                    ),
                    _buildProfileOption(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      onTap: () {},
                    ),
                    _buildProfileOption(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {},
                    ),
                    _buildProfileOption(
                      icon: Icons.logout,
                      title: 'Logout',
                      onTap: () {},
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 3,
        currentStaff: currentStaff,
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
          children: [
            // Profile Avatar
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0846B1), Color(0xFF2255FC)],
                ),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0846B1).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  currentStaff.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Name and role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentStaff.name.split(' ').first,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF080E29),
                    ),
                  ),
                  Text(
                    'Staff Member',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8F8E90),
                    ),
                  ),
                ],
              ),
            ),
            // Notifications
            Container(
              width: 40.w,
              height: 40.h,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 20.sp,
                      color: const Color(0xFF080E29),
                    ),
                  ),
                  Positioned(
                    right: 10.w,
                    top: 10.h,
                    child: Container(
                      width: 8.w,
                      height: 8.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF1E05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : AppTheme.primaryColor,
                size: 24.sp,
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isDestructive ? Colors.red : AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondaryColor,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
