import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/notification_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/work_hours_provider.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';

/// Settings page with app preferences
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final p = SoftPalette.of(context);

    return HomeSubPage(
      eyebrow: 'Settings',
      headline: const [
        (text: 'Make ', strong: false),
        (text: 'PowerCA', strong: true),
        (text: ' work ', strong: false),
        (text: 'your way.', strong: true),
      ],
      children: [
        // Appearance
        HomeSectionCard(
          title: 'Appearance',
          subtitle: 'Theme for the whole app',
          child: _SettingRow(
            title: 'Dark mode',
            subtitle: isDark ? 'Dark theme is on' : 'Light theme is on',
            trailing: _SoftSwitch(
              value: isDark,
              onChanged: (value) {
                themeProvider.setDarkMode(value);
              },
            ),
          ),
        ),

        // Notifications
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, _) {
            return HomeSectionCard(
              title: 'Notifications',
              subtitle: 'Choose what you want to be told about',
              child: Column(
                children: [
                  _SettingRow(
                    title: 'Leave updates',
                    subtitle: 'Approved or rejected leave',
                    trailing: _SoftSwitch(
                      value: notificationProvider.leaveNotificationsToggle,
                      onChanged: (value) {
                        notificationProvider.setLeaveNotificationsEnabled(value);
                      },
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: p.border),
                  _SettingRow(
                    title: 'Pinboard reminders',
                    subtitle: 'New reminder assignments',
                    trailing: _SoftSwitch(
                      value: notificationProvider.pinboardNotificationsToggle,
                      onChanged: (value) {
                        notificationProvider.setPinboardNotificationsEnabled(value);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Work log preferences
        Consumer<WorkHoursProvider>(
          builder: (context, workHoursProvider, _) {
            final isFromToDefault = workHoursProvider.isFromToTimeDefault;
            final isHoursMinDefault = workHoursProvider.isHoursMinutesDefault;

            return HomeSectionCard(
              title: 'Work log preferences',
              subtitle: 'Default way to enter work hours',
              child: Column(
                children: [
                  _WorkHoursOption(
                    title: 'From / To time',
                    subtitle: 'Select start and end time',
                    isSelected: isFromToDefault,
                    onTap: () {
                      workHoursProvider.setDefaultMode(WorkHoursMode.fromToTime);
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: p.border),
                  _WorkHoursOption(
                    title: 'Hours / Minutes',
                    subtitle: 'Enter duration directly',
                    isSelected: isHoursMinDefault,
                    onTap: () {
                      workHoursProvider.setDefaultMode(WorkHoursMode.hoursMinutes);
                    },
                  ),
                ],
              ),
            );
          },
        ),

        // About
        const HomeSectionCard(
          title: 'About',
          subtitle: 'PowerCA Auditor WorkLog',
          padding: EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: HomeStat(
                    label: 'Version',
                    value: AppUpdateService.currentVersionName,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: HomeStat(label: 'Developer', value: 'TBS Technologies'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Title + caption + trailing control, no icon.
class _SettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SoftText.body(p, size: 15, color: p.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: SoftText.caption(p, size: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

/// Switch: blue track + white thumb when on, white track with a dark
/// outline and dark thumb when off.
class _SoftSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SoftSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final onThumb = p.isDark ? p.background : Colors.white;
    return Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbIcon: const WidgetStatePropertyAll(null),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? onThumb : p.ink,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.surface,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.accent : p.ink,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
    );
  }
}

/// Radio row for the default work hours input mode.
class _WorkHoursOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorkHoursOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SoftText.body(p, size: 15, color: p.ink)),
                  const SizedBox(height: 2),
                  Text(
                    isSelected ? '$subtitle • Default' : subtitle,
                    style: SoftText.caption(p, size: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surface,
                border: Border.all(
                  color: isSelected ? p.accent : p.muted,
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: isSelected
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
