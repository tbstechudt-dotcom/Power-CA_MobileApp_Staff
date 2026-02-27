import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/injection.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/app_update_service.dart';
import '../../features/auth/domain/entities/staff.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/app_update_page.dart';
import '../../features/settings/presentation/pages/help_support_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import 'rating_review_dialog.dart';

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
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  String _getStaffRole(int? staffType) {
    switch (staffType) {
      case 1:
        return 'Administrator';
      case 2:
        return 'Manager';
      case 3:
        return 'Senior Staff';
      case 4:
        return 'Staff Member';
      case 5:
        return 'Junior Staff';
      default:
        return 'Staff Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final versionColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFD1D5DB);

    return Drawer(
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Profile Header with Gradient
          _buildProfileHeader(),

          // Menu Items
          Expanded(
            child: Container(
              color: bgColor,
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: 'My Profile',
                    onTap: () => _handleMenuTap(context, 'Profile'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => _handleMenuTap(context, 'Settings'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.system_update_outlined,
                    title: 'App Update',
                    onTap: () => _handleMenuTap(context, 'AppUpdate'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () => _handleMenuTap(context, 'HelpSupport'),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.star_outline_rounded,
                    title: 'Ratings & Reviews',
                    onTap: () => _handleMenuTap(context, 'RatingsReviews'),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Section
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // Logout Button
                _buildLogoutButton(context),
                SizedBox(height: 12.h),
                // Version Info
                Text(
                  'PowerCA Staff v${AppUpdateService.currentVersionName}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    color: versionColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final closeBtnBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF3F4F6);
    final closeBtnIconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final nameColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final roleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            children: [
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: closeBtnBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 18.sp,
                        color: closeBtnIconColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              // Avatar and Info Row
              Row(
                children: [
                  // Avatar on left
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
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
                  SizedBox(width: 14.w),
                  // Name and Role on right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentStaff.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: nameColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _getStaffRole(widget.currentStaff.staffType),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: roleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF3F4F6);
    final iconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF374151);
    final arrowColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D5DB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: Opacity(
          opacity: isDisabled ? 0.4 : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Icon
                Icon(
                  icon,
                  size: 22.sp,
                  color: iconColor,
                ),
                SizedBox(width: 14.w),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
                ),
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.sp,
                  color: arrowColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleLogout(context),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: const Color(0xFFFECACA),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 20.sp,
                color: const Color(0xFFDC2626),
              ),
              SizedBox(width: 8.w),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
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
    } else if (title == 'Settings') {
      // Navigate to Settings page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsPage(),
        ),
      );
    } else if (title == 'AppUpdate') {
      // Navigate to App Update page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AppUpdatePage(),
        ),
      );
    } else if (title == 'HelpSupport') {
      // Navigate to Help & Support page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HelpSupportPage(),
        ),
      );
    } else if (title == 'RatingsReviews') {
      _handleRatingsReviews(context);
    }
  }

  /// Handle Ratings & Reviews menu tap
  Future<void> _handleRatingsReviews(BuildContext context) async {
    final staffId = widget.currentStaff.staffId;

    // Check if user has already reviewed
    final prefs = await SharedPreferences.getInstance();
    final hasReviewed = prefs.getBool(
      '${StorageConstants.keyHasReviewed}$staffId',
    ) ?? false;

    if (!mounted) return;

    if (hasReviewed) {
      // Already reviewed - show info dialog
      showDialog(
        context: context,
        builder: (dialogContext) {
          final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
          final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
          final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
          final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

          return AlertDialog(
            backgroundColor: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.star_rounded,
                      size: 20.sp,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Already Reviewed',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            content: Text(
              'Thank you! You have already submitted your rating and review.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: subtitleColor,
              ),
            ),
            actionsPadding: EdgeInsets.all(16.w),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          side: BorderSide(color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        // Capture navigator while dialog is still alive
                        final navigator = Navigator.of(dialogContext);
                        Navigator.pop(dialogContext);
                        // Reset reviewed status and show rating dialog
                        _showReviewAgain(navigator, staffId);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        'Review Again',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } else {
      // Not reviewed yet - show rating dialog
      await RatingReviewBottomSheet.show(context, staffId: staffId);
    }
  }

  Future<void> _showReviewAgain(NavigatorState navigator, int staffId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      '${StorageConstants.keyHasReviewed}$staffId',
      false,
    );
    // Wait for dialog to fully close before showing bottom sheet
    await Future.delayed(const Duration(milliseconds: 300));
    final overlayContext = navigator.overlay?.context;
    if (overlayContext == null || !overlayContext.mounted) return;
    await RatingReviewBottomSheet.show(overlayContext, staffId: staffId);
  }

  void _handleLogout(BuildContext context) {
    // Get navigator before any async operations
    final navigator = Navigator.of(context);

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Icon(
                  Icons.logout_rounded,
                  size: 20.sp,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          ),
        ),
        actionsPadding: EdgeInsets.all(16.w),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextButton(
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
                    navigator.pushNamedAndRemoveUntil(
                      '/splash',
                      (route) => false,
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
