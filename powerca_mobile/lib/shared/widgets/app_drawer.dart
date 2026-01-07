import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/config/injection.dart';
import '../../features/auth/domain/entities/staff.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../app/theme.dart';

/// Professional drawer menu that slides from left to right
class AppDrawer extends StatefulWidget {
  final Staff currentStaff;

  const AppDrawer({
    super.key,
    required this.currentStaff,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () => _handleMenuTap(context, 'Profile'),
                  ),
                ],
              ),
            ),

            // Logout Button
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close button row
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36.w,
                height: 36.h,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.close,
                    size: 20.sp,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Staff name
          Text(
            widget.currentStaff.name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6.h),
          // Staff ID
          Text(
            'Staff ID: ${widget.currentStaff.staffId}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(
          icon,
          size: 20.sp,
          color: AppTheme.primaryColor,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20.sp,
        color: const Color(0xFF9CA3AF),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _handleLogout(context),
          icon: Icon(
            Icons.logout,
            size: 18.sp,
            color: const Color(0xFFDC2626),
          ),
          label: Text(
            'Logout',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFDC2626),
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            side: const BorderSide(color: Color(0xFFDC2626), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        ),
      ),
    );
  }

  void _handleMenuTap(BuildContext context, String title) {
    Navigator.pop(context); // Close drawer

    if (title == 'Profile') {
      // Navigate to Profile page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(
            currentStaff: widget.currentStaff,
          ),
        ),
      );
    }
  }

  void _handleLogout(BuildContext context) {
    // Get navigator before any async operations
    final navigator = Navigator.of(context);

    // Show confirmation dialog FIRST (before closing drawer)
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close dialog first
              Navigator.pop(dialogContext);

              // Clear the saved session
              try {
                final authRepository = getIt<AuthRepository>();
                await authRepository.signOut();
                debugPrint('Session cleared successfully');
              } catch (e) {
                debugPrint('Error clearing session: $e');
              }

              // Navigate to splash page and clear ALL navigation stack
              // This removes drawer, dialog, and all screens
              navigator.pushNamedAndRemoveUntil(
                '/splash',
                (route) => false, // Remove all routes
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
