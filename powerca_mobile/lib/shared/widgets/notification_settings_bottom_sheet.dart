import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/providers/notification_provider.dart';
import 'soft_page.dart';

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
    final p = SoftPalette.of(context);
    final notificationProvider = Provider.of<NotificationProvider>(context);

    final isEnabled = getCurrentValue(notificationProvider);
    final globalEnabled = notificationProvider.notificationsEnabled;
    final active = isEnabled && globalEnabled;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            SizedBox(height: 20.h),

            // Title
            Text(
              '$featureName Notification Settings',
              style: SoftText.title(p, size: 19),
            ),
            SizedBox(height: 6.h),

            // Subtitle
            Text(
              'Configure notifications for ${featureName.toLowerCase()} updates',
              style: SoftText.body(p, size: 13),
            ),
            SizedBox(height: 18.h),

            // Global notifications warning if disabled
            if (!globalEnabled)
              Container(
                padding: EdgeInsets.all(14.w),
                margin: EdgeInsets.only(bottom: 14.h),
                decoration: BoxDecoration(
                  color: p.tint(p.warning),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: p.warning,
                      size: 20,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'Global notifications are disabled. Enable them in Settings first.',
                        style: SoftText.body(p, size: 12.5, color: p.ink),
                      ),
                    ),
                  ],
                ),
              ),

            // Toggle card
            SoftCard(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  SoftIconBadge(
                    icon: Icons.notifications_active_rounded,
                    color: active ? p.accent : p.muted,
                    size: 40,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$featureName Notifications',
                          style: SoftText.heading(p, size: 15),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          featureName == 'Leave'
                              ? 'Get notified when leave requests are approved or rejected'
                              : 'Get notified when new reminders are assigned to you',
                          style: SoftText.caption(p),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isEnabled,
                    onChanged: globalEnabled
                        ? (value) => onChanged(notificationProvider, value)
                        : null,
                    activeTrackColor: p.pill,
                    activeThumbColor: p.onPill,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
