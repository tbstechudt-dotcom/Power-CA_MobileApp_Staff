import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../auth/domain/entities/staff.dart';

/// Profile page displaying staff registration details
class ProfilePage extends StatefulWidget {
  final Staff currentStaff;

  const ProfilePage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  Color _getRoleColor(int? staffType) {
    switch (staffType) {
      case 1:
        return const Color(0xFFDC2626); // Red for Admin
      case 2:
        return const Color(0xFFF59E0B); // Amber for Manager
      case 3:
        return const Color(0xFF8B5CF6); // Purple for Senior
      case 4:
        return const Color(0xFF3B82F6); // Blue for Staff
      case 5:
        return const Color(0xFF10B981); // Green for Junior
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final appBarBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final backBtnBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backBtnBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final backBtnIconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: appBarBgColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: backBtnBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: backBtnBorderColor,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18.sp,
                    color: backBtnIconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        leadingWidth: 58.w,
        title: Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2563EB),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.w,
          right: 16.w,
          top: 16.w,
          bottom: 16.w + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          children: [
            // Profile Header Section
            _buildProfileHeaderSection(context),
            SizedBox(height: 16.h),

            // Quick Stats Row
            _buildQuickStatsRow(context),
            SizedBox(height: 16.h),

            // Personal Information Card
            _buildInfoCard(
              context: context,
              title: 'Personal Information',
              icon: Icons.person_rounded,
              iconBgColor: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF6366F1),
              children: [
                _buildInfoItem(
                  context: context,
                  icon: Icons.badge_outlined,
                  label: 'Full Name',
                  value: widget.currentStaff.name,
                ),
                _buildInfoItem(
                  context: context,
                  icon: Icons.alternate_email,
                  label: 'Username',
                  value: widget.currentStaff.username,
                ),
                _buildInfoItem(
                  context: context,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: widget.currentStaff.email ?? 'Not provided',
                  isNotProvided: widget.currentStaff.email == null,
                ),
                _buildInfoItem(
                  context: context,
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: widget.currentStaff.phoneNumber ?? 'Not provided',
                  isNotProvided: widget.currentStaff.phoneNumber == null,
                  showDivider: widget.currentStaff.dateOfBirth != null,
                ),
                if (widget.currentStaff.dateOfBirth != null)
                  _buildInfoItem(
                    context: context,
                    icon: Icons.cake_outlined,
                    label: 'Date of Birth',
                    value: DateFormat('MMMM d, yyyy')
                        .format(widget.currentStaff.dateOfBirth!),
                    showDivider: false,
                  ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderSection(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final nameColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with initials
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF1D4ED8),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(widget.currentStaff.name),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          // Name
          Text(
            widget.currentStaff.name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: nameColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          // Role badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 6.h,
            ),
            decoration: BoxDecoration(
              color: _getRoleColor(widget.currentStaff.staffType)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              _getStaffRole(widget.currentStaff.staffType),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: _getRoleColor(widget.currentStaff.staffType),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              context: context,
              icon: Icons.fingerprint,
              label: 'Staff ID',
              value: '#${widget.currentStaff.staffId}',
              color: const Color(0xFF2563EB),
            ),
          ),
          Container(
            width: 1,
            height: 50.h,
            color: dividerColor,
          ),
          Expanded(
            child: _buildStatItem(
              context: context,
              icon: Icons.business,
              label: 'Org ID',
              value: '${widget.currentStaff.orgId}',
              color: const Color(0xFF8B5CF6),
            ),
          ),
          Container(
            width: 1,
            height: 50.h,
            color: dividerColor,
          ),
          Expanded(
            child: _buildStatusStatItem(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final valueColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final labelColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20.sp,
            color: color,
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStatItem(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final isActive = widget.currentStaff.isActive;
    final statusColor = isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final labelColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      child: Column(
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Status',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required List<Widget> children,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    final darkIconBgColor = isDarkMode ? iconBgColor.withValues(alpha: 0.15) : iconBgColor;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: isDarkMode ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: darkIconBgColor,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 20.sp,
                      color: iconColor,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Widget? valueWidget,
    bool isNotProvided = false,
    bool showDivider = true,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final iconBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8FAFC);
    final iconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);
    final labelColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);
    final valueColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF334155);
    final notProvidedColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFCBD5E1);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18.sp,
                    color: iconColor,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: labelColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    if (valueWidget != null)
                      valueWidget
                    else
                      Text(
                        value,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: isNotProvided ? notProvidedColor : valueColor,
                          fontStyle:
                              isNotProvided ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 48.w,
          ),
      ],
    );
  }
}
