import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/work_hours_provider.dart';
import '../../../../core/services/app_update_service.dart';

/// Settings page with app preferences
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Theme-aware colors
    final headerColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: headerColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 20.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SizedBox.expand(
        child: Container(
          color: surfaceColor,
          child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance Section
            _buildSectionHeader('Appearance', titleColor),
            SizedBox(height: 12.h),

            // Dark Mode Toggle
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    iconColor: isDark ? const Color(0xFFFBBF24) : AppTheme.primaryColor,
                    title: 'Dark Mode',
                    subtitle: isDark ? 'Dark theme is enabled' : 'Light theme is enabled',
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    trailing: Switch.adaptive(
                      value: isDark,
                      onChanged: (value) {
                        themeProvider.setDarkMode(value);
                      },
                      activeTrackColor: AppTheme.primaryColor,
                    ),
                    showDivider: false,
                    dividerColor: borderColor,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Notifications Section
            _buildSectionHeader('Notifications', titleColor),
            SizedBox(height: 12.h),

            Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Leave Updates Toggle
                      _buildSettingItem(
                        icon: Icons.event_available_rounded,
                        iconColor: notificationProvider.leaveNotificationsToggle
                            ? const Color(0xFF10B981)
                            : iconColor,
                        title: 'Leave Updates',
                        subtitle: 'Approved or rejected leave notifications',
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                        trailing: Switch.adaptive(
                          value: notificationProvider.leaveNotificationsToggle,
                          onChanged: (value) {
                            notificationProvider.setLeaveNotificationsEnabled(value);
                          },
                          activeTrackColor: const Color(0xFF10B981),
                        ),
                        showDivider: true,
                        dividerColor: borderColor,
                      ),

                      // Pinboard Reminders Toggle
                      _buildSettingItem(
                        icon: Icons.push_pin_rounded,
                        iconColor: notificationProvider.pinboardNotificationsToggle
                            ? const Color(0xFFF59E0B)
                            : iconColor,
                        title: 'Pinboard Reminders',
                        subtitle: 'New reminder assignment notifications',
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                        trailing: Switch.adaptive(
                          value: notificationProvider.pinboardNotificationsToggle,
                          onChanged: (value) {
                            notificationProvider.setPinboardNotificationsEnabled(value);
                          },
                          activeTrackColor: const Color(0xFFF59E0B),
                        ),
                        showDivider: false,
                        dividerColor: borderColor,
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 24.h),

            // Work Log Preferences Section
            _buildSectionHeader('Work Log Preferences', titleColor),
            SizedBox(height: 12.h),

            Consumer<WorkHoursProvider>(
              builder: (context, workHoursProvider, _) {
                final isFromToDefault = workHoursProvider.isFromToTimeDefault;
                final isHoursMinDefault = workHoursProvider.isHoursMinutesDefault;

                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    children: [
                      // From/To Time Option
                      _buildWorkHoursOption(
                        icon: Icons.schedule,
                        title: 'From / To Time',
                        subtitle: 'Select start and end time',
                        isSelected: isFromToDefault,
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                        iconColor: iconColor,
                        onTap: () {
                          workHoursProvider.setDefaultMode(WorkHoursMode.fromToTime);
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: borderColor,
                        indent: 70.w,
                      ),
                      // Hours/Minutes Option
                      _buildWorkHoursOption(
                        icon: Icons.timer_outlined,
                        title: 'Hours / Minutes',
                        subtitle: 'Enter duration directly',
                        isSelected: isHoursMinDefault,
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                        iconColor: iconColor,
                        onTap: () {
                          workHoursProvider.setDefaultMode(WorkHoursMode.hoursMinutes);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // Hint text for the setting
            Padding(
              padding: EdgeInsets.only(left: 4.w, top: 8.h),
              child: Text(
                'Select your preferred default input method for work hours',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // App Info Section
            _buildSectionHeader('About', titleColor),
            SizedBox(height: 12.h),

            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: Icons.info_outline_rounded,
                    iconColor: iconColor,
                    title: 'Version',
                    subtitle: AppUpdateService.currentVersionName,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    showDivider: true,
                    dividerColor: borderColor,
                  ),
                  _buildSettingItem(
                    icon: Icons.business_rounded,
                    iconColor: iconColor,
                    title: 'Developer',
                    subtitle: 'TBS Technologies Private Limited',
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                    showDivider: false,
                    dividerColor: borderColor,
                  ),
                ],
              ),
            ),

          ],
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color titleColor) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: titleColor.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
    Widget? trailing,
    bool showDivider = true,
    required Color dividerColor,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    icon,
                    size: 20.sp,
                    color: iconColor,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 70.w,
          ),
      ],
    );
  }

  Widget _buildWorkHoursOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color titleColor,
    required Color subtitleColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final selectedColor = AppTheme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedColor.withValues(alpha: 0.1)
                    : iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                icon,
                size: 20.sp,
                color: isSelected ? selectedColor : iconColor,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? selectedColor : titleColor,
                        ),
                      ),
                      if (isSelected) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: selectedColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: selectedColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            // Radio-style indicator
            Container(
              width: 22.w,
              height: 22.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? selectedColor : iconColor,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
