import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/providers/theme_provider.dart';

/// Reusable bottom sheet for notification settings
/// Can be used on Leave page and Pinboard page
class NotificationSettingsBottomSheet extends StatelessWidget {
  final String featureName;
  final bool Function(NotificationProvider) getCurrentValue;
  final Future<void> Function(NotificationProvider, bool) onChanged;

  const NotificationSettingsBottomSheet({
    super.key,
    required this.featureName,
    required this.getCurrentValue,
    required this.onChanged,
  });

  /// Show the bottom sheet for Leave notifications
  static void showForLeave(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationSettingsBottomSheet(
        featureName: 'Leave',
        getCurrentValue: (provider) => provider.leaveNotificationsToggle,
        onChanged: (provider, value) =>
            provider.setLeaveNotificationsEnabled(value),
      ),
    );
  }

  /// Show the bottom sheet for Pinboard notifications
  static void showForPinboard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationSettingsBottomSheet(
        featureName: 'Pinboard',
        getCurrentValue: (provider) => provider.pinboardNotificationsToggle,
        onChanged: (provider, value) =>
            provider.setPinboardNotificationsEnabled(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final notificationProvider = Provider.of<NotificationProvider>(context);

    final sheetBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final handleColor =
        isDarkMode ? const Color(0xFF475569) : const Color(0xFFE5E7EB);
    final titleColor =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final cardColor =
        isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC);
    final warningBgColor =
        isDarkMode ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    final warningBorderColor =
        isDarkMode ? const Color(0xFFF59E0B) : const Color(0xFFFCD34D);
    final warningTextColor =
        isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFFB45309);

    final isEnabled = getCurrentValue(notificationProvider);
    final globalEnabled = notificationProvider.notificationsEnabled;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: sheetBgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),

          // Title
          Text(
            '$featureName Notification Settings',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          SizedBox(height: 8.h),

          // Subtitle
          Text(
            'Configure notifications for ${featureName.toLowerCase()} updates',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              color: subtitleColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),

          // Global notifications warning if disabled
          if (!globalEnabled)
            Container(
              padding: EdgeInsets.all(12.w),
              margin: EdgeInsets.only(bottom: 16.h),
              decoration: BoxDecoration(
                color: warningBgColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: warningBorderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: warningTextColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Global notifications are disabled. Enable them in Settings first.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        color: warningTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Toggle card
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: isEnabled && globalEnabled
                      ? AppTheme.primaryColor
                      : subtitleColor,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$featureName Notifications',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        featureName == 'Leave'
                            ? 'Get notified when leave requests are approved or rejected'
                            : 'Get notified when new reminders are assigned to you',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isEnabled,
                  onChanged: globalEnabled
                      ? (value) => onChanged(notificationProvider, value)
                      : null,
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
