import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../features/auth/domain/entities/staff.dart';
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
                  _buildMenuItem(
                    context,
                    icon: Icons.videocam_outlined,
                    title: 'Video Meet',
                    onTap: () => _handleMenuTap(context, 'Video Meet'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.chat_bubble_outline,
                    title: 'Chat',
                    onTap: () => _handleMenuTap(context, 'Chat'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline,
                    title: 'Job Queries',
                    onTap: () => _handleMenuTap(context, 'Job Queries'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.description_outlined,
                    title: 'Responsive Form',
                    onTap: () => _handleMenuTap(context, 'Responsive Form'),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFE5E7EB)),
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => _handleMenuTap(context, 'Settings'),
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
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(widget.currentStaff.name),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.currentStaff.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Staff ID: ${widget.currentStaff.staffId}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
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
          color: const Color(0xFFF3F4F6),
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
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
    } else {
      // Show a snackbar for other menu items
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title - Coming Soon'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _handleLogout(BuildContext context) {
    Navigator.pop(context); // Close drawer

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add logout logic here
              Navigator.pushReplacementNamed(context, '/login');
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
