import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

const String _supportEmail = 'contact@powerca.in';
const String _supportPhoneLabel = '+91 98422 24635';
const String _supportPhone = '+919842224635';
const String _supportWebsiteLabel = 'www.powerca.in';
const String _supportWebsite = 'https://www.powerca.in';
const String _supportHours = 'Mon – Sat, 9:30 AM – 6:00 PM IST · Sunday closed';

typedef _HelpItem = ({String title, String body});

const List<_HelpItem> _faqItems = [
  (
    title: 'How do I log my work hours?',
    body:
        'Navigate to any job from the Job List, then tap "Add Work Log" to record your work hours. You can specify the date, start time, end time, and add notes about the work performed. Your logged hours will be synced automatically.',
  ),
  (
    title: 'How do I apply for leave?',
    body:
        'Go to the Leave Requests section from the bottom navigation. Tap the "+" button to create a new leave request. Select your leave type, specify the dates, and add any relevant notes. Your manager will be notified and can approve or reject your request.',
  ),
  (
    title: 'How do I book a client meeting?',
    body:
        'On the Home page, tap "Add meeting" in the Appointments card. Choose whether you are meeting an existing client or a new contact (you can create a new contact from the picker), pick Direct or Virtual, set the date, time and duration, and add the purpose or agenda. Tap Save - the meeting then appears in your Appointments list on Home.',
  ),
  (
    title: 'How do I record a meeting\'s outcome?',
    body:
        'Open the meeting from the Appointments list on Home and switch to the Outcome tab (it unlocks once the meeting has been saved). Enter the actual time spent and the key person you met, then save. Once the outcome is recorded, the appointment details are locked.',
  ),
  (
    title: 'Can I reschedule or cancel a meeting?',
    body:
        'Yes. To reschedule, open the meeting, go to the Outcome tab and turn on "Reschedule this meeting", then choose the new date and time - a new appointment is created for that date. To cancel, open the meeting and tap "Cancel meeting" at the bottom of the Appointment tab.',
  ),
  (
    title: 'What do the job status colors mean?',
    body: 'Jobs are color-coded by status:\n'
        '- Blue (In Progress): Work is currently ongoing\n'
        '- Green (Completed): Job has been finished\n'
        '- Orange (Pending): Awaiting assignment or start\n'
        '- Red (On Hold): Job is temporarily paused\n'
        '- Gray (Draft): Job is not yet active',
  ),
  (
    title: 'How do I complete a task checklist?',
    body:
        'Open a job and navigate to the Tasks tab. You\'ll see a list of tasks with checkboxes. Tap on each task to mark it as complete. The job progress percentage updates automatically based on completed tasks.',
  ),
  (
    title: 'Why can\'t I see certain jobs?',
    body:
        'You can only see jobs that are assigned to you or your team. If you believe a job should be visible to you, please contact your administrator to verify your assignment.',
  ),
  (
    title: 'How do I update my profile information?',
    body:
        'Profile information is managed by your organization\'s administrator through the desktop application. If you need to update your details (phone number, email, etc.), please contact your HR department or admin.',
  ),
  (
    title: 'What is the Pinboard?',
    body:
        'The Pinboard is your organization\'s notice board for announcements, events, and important updates. You can view posts, like them, and add comments. Categories help organize different types of announcements.',
  ),
  (
    title: 'How does data sync work?',
    body:
        'The app automatically syncs your data with the server when you have an internet connection. Work logs, task completions, and leave requests are uploaded immediately. If you\'re offline, changes are saved locally and synced when connectivity is restored.',
  ),
  (
    title: 'How do I enable/disable notifications?',
    body:
        'Go to Settings from your profile menu. Under the Notifications section, you can toggle notifications on or off globally, and also control specific notification types like leave updates and pinboard reminders.',
  ),
  (
    title: 'What should I do if the app is running slow?',
    body: 'Try these steps:\n'
        '1. Close and reopen the app\n'
        '2. Check your internet connection\n'
        '3. Clear the app cache from your device settings\n'
        '4. Ensure your app is updated to the latest version\n'
        '5. If issues persist, contact support',
  ),
];

/// Feature guides; the dot color is resolved from the soft palette.
const List<_HelpItem> _featureGuides = [
  (
    title: 'Dashboard',
    body:
        'Your home screen showing today\'s summary, pending tasks, upcoming deadlines, and quick access to recent jobs.',
  ),
  (
    title: 'Job Management',
    body:
        'View all assigned jobs, track progress, complete task checklists, and log work hours for each job.',
  ),
  (
    title: 'Work Diary',
    body:
        'Record daily work entries with start/end times. Track total hours worked per job and generate timesheets.',
  ),
  (
    title: 'Leave Requests',
    body:
        'Apply for leave, view leave balance, track request status (pending, approved, rejected), and see leave history.',
  ),
  (
    title: 'Pinboard',
    body:
        'Stay updated with company announcements, events, policies, and team updates. Engage with likes and comments.',
  ),
  (
    title: 'Appointments',
    body:
        'Book meetings with existing clients or new contacts, in person (Direct) or online (Virtual). Your upcoming meetings show on Home; open one to edit it, record the outcome (time spent and key person met), reschedule it or cancel it.',
  ),
];

Color _featureColor(SoftPalette p, int index) {
  switch (index) {
    case 0:
      return p.accent;
    case 1:
      return p.success;
    case 2:
      return p.leave;
    case 3:
      return p.warning;
    case 4:
      return p.danger;
    default:
      // Appointments: teal, matching the "Work Done" accent used elsewhere.
      return p.isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
  }
}

const List<_HelpItem> _troubleshootingTips = [
  (
    title: 'Connection issues',
    body: 'Check your internet connection and try switching between WiFi and mobile data.',
  ),
  (
    title: 'Sync problems',
    body:
        'Pull down to refresh on any list screen. If data doesn\'t update, sign out and sign back in.',
  ),
  (
    title: 'App running slow',
    body:
        'Close other apps running in background. Clear app cache from device settings if needed.',
  ),
  (
    title: 'Login issues',
    body:
        'Ensure you\'re using the correct username. Contact your admin if your account is locked.',
  ),
  (
    title: 'Not receiving notifications',
    body:
        'Check notification permissions in device settings and ensure notifications are enabled in app settings.',
  ),
  (
    title: 'Appointments not loading',
    body:
        'If the Appointments card on Home shows "Couldn\'t load appointments", check your internet connection and tap the card to retry. If it keeps failing, sign out and sign back in, then contact support.',
  ),
];

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

/// Help & Support page with contact options, FAQs, guides and quick fixes.
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    return HomeSubPage(
      eyebrow: 'Help & support',
      headline: const [
        (text: 'How can we ', strong: false),
        (text: 'help', strong: true),
        (text: '?', strong: false),
      ],
      children: [
        HomeSectionCard(
          title: 'Contact',
          subtitle: _supportHours,
          trailing: HomeRoundAction(
            icon: Icons.north_east_rounded,
            tooltip: 'Visit website',
            onTap: () => _HelpLinks.website(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpRow(
                first: true,
                label: 'Email support',
                caption: _supportEmail,
                onTap: () => _HelpLinks.email(context),
              ),
              _HelpRow(
                label: 'Call support',
                caption: _supportPhoneLabel,
                onTap: () => _HelpLinks.phone(context),
              ),
              _HelpRow(
                label: 'Visit website',
                caption: _supportWebsiteLabel,
                onTap: () => _HelpLinks.website(context),
              ),
              const SizedBox(height: 10),
              Text(
                'We usually reply within 24 business hours. For urgent issues, please call.',
                style: SoftText.caption(p, size: 12.5).copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  HomeBluePill(
                    label: 'Email us',
                    icon: Icons.mail_outline_rounded,
                    onTap: () => _HelpLinks.email(context),
                  ),
                  HomeBluePill(
                    label: 'Call',
                    icon: Icons.phone_outlined,
                    onTap: () => _HelpLinks.phone(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        HomeSectionCard(
          title: 'Frequently asked questions',
          subtitle: '${_faqItems.length} answers',
          child: Column(
            children: [
              for (int i = 0; i < _faqItems.length; i++)
                _HelpRow(
                  first: i == 0,
                  label: _faqItems[i].title,
                  onTap: () => _openDetail(context, _HelpKind.faq, i),
                ),
            ],
          ),
        ),
        HomeSectionCard(
          title: 'Feature guides',
          subtitle: 'What each part of the app does',
          child: Column(
            children: [
              for (int i = 0; i < _featureGuides.length; i++)
                _HelpRow(
                  first: i == 0,
                  dot: _featureColor(p, i),
                  label: _featureGuides[i].title,
                  onTap: () => _openDetail(context, _HelpKind.feature, i),
                ),
            ],
          ),
        ),
        HomeSectionCard(
          title: 'Troubleshooting',
          subtitle: 'Quick fixes for common problems',
          child: Column(
            children: [
              for (int i = 0; i < _troubleshootingTips.length; i++)
                _HelpRow(
                  first: i == 0,
                  label: _troubleshootingTips[i].title,
                  onTap: () => _openDetail(context, _HelpKind.troubleshooting, i),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail page (FAQ / feature guide / troubleshooting)
// ---------------------------------------------------------------------------

enum _HelpKind { faq, feature, troubleshooting }

void _openDetail(BuildContext context, _HelpKind kind, int index, {bool replace = false}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => _HelpDetailPage(kind: kind, index: index),
  );
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

class _HelpDetailPage extends StatelessWidget {
  final _HelpKind kind;
  final int index;

  const _HelpDetailPage({required this.kind, required this.index});

  List<_HelpItem> get _items {
    switch (kind) {
      case _HelpKind.faq:
        return _faqItems;
      case _HelpKind.feature:
        return _featureGuides;
      case _HelpKind.troubleshooting:
        return _troubleshootingTips;
    }
  }

  String get _eyebrow {
    switch (kind) {
      case _HelpKind.faq:
        return 'Help · FAQ';
      case _HelpKind.feature:
        return 'Help · Feature guide';
      case _HelpKind.troubleshooting:
        return 'Help · Troubleshooting';
    }
  }

  String get _othersTitle {
    switch (kind) {
      case _HelpKind.faq:
        return 'Related questions';
      case _HelpKind.feature:
        return 'Other features';
      case _HelpKind.troubleshooting:
        return 'Other fixes';
    }
  }

  /// Indices of the other entries to suggest: the next three (wrapping) for
  /// FAQs and fixes, every other guide for features.
  List<int> get _otherIndices {
    final items = _items;
    final count = kind == _HelpKind.feature ? items.length - 1 : 3;
    return [
      for (int k = 1; k <= count && k < items.length; k++) (index + k) % items.length,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final item = _items[index];
    final others = _otherIndices;

    return HomeSubPage(
      eyebrow: _eyebrow,
      headline: [(text: item.title, strong: true)],
      children: [
        SoftCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              item.body,
              style: SoftText.body(p, size: 14).copyWith(height: 1.55),
            ),
          ),
        ),
        if (others.isNotEmpty)
          HomeSectionCard(
            title: _othersTitle,
            child: Column(
              children: [
                for (int i = 0; i < others.length; i++)
                  _HelpRow(
                    first: i == 0,
                    dot: kind == _HelpKind.feature ? _featureColor(p, others[i]) : null,
                    label: _items[others[i]].title,
                    onTap: () => _openDetail(context, kind, others[i], replace: true),
                  ),
              ],
            ),
          ),
        HomeSectionCard(
          title: 'Still need help?',
          subtitle: 'Our team usually replies within 24 business hours',
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: HomeBluePill(
                label: 'Email us',
                icon: Icons.mail_outline_rounded,
                onTap: () => _HelpLinks.email(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared row
// ---------------------------------------------------------------------------

/// Chevron row inside a [HomeSectionCard]: optional colored dot, ink label,
/// optional caption, with a divider above unless [first].
class _HelpRow extends StatelessWidget {
  final String label;
  final String? caption;
  final Color? dot;
  final VoidCallback? onTap;
  final bool first;

  const _HelpRow({
    required this.label,
    this.caption,
    this.dot,
    this.onTap,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Column(
      children: [
        if (!first) Divider(height: 1, color: p.border),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: caption != null ? 15 : 13),
            child: Row(
              children: [
                if (dot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: SoftText.body(p, size: 15, color: p.ink)),
                      if (caption != null) ...[
                        const SizedBox(height: 3),
                        Text(caption!, style: SoftText.caption(p, size: 12)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// URL launcher helpers
// ---------------------------------------------------------------------------

/// Links call launchUrl directly instead of gating on canLaunchUrl, which
/// returns false on Android 11+ unless the scheme is declared in <queries>
/// (see AndroidManifest.xml). Any failure shows an error snackbar.
class _HelpLinks {
  static Future<void> email(BuildContext context) => _launchEmail(context, _supportEmail);

  static Future<void> phone(BuildContext context) => _launchPhone(context, _supportPhone);

  static Future<void> website(BuildContext context) => _launchUrl(context, _supportWebsite);

  static Future<void> _launchEmail(BuildContext context, String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      // Encode manually: queryParameters would turn spaces into '+'.
      query: 'subject=${Uri.encodeComponent('PowerCA App Support Request')}',
    );
    await _openLink(context, emailUri, 'Could not open an email app');
  }

  static Future<void> _launchPhone(BuildContext context, String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone.replaceAll(RegExp(r'[^0-9+]'), ''),
    );
    await _openLink(context, phoneUri, 'Could not open the phone dialer');
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    await _openLink(
      context,
      Uri.parse(url),
      'Could not open the website',
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> _openLink(
    BuildContext context,
    Uri uri,
    String errorMessage, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: mode);
    } catch (e) {
      debugPrint('HelpSupport: failed to open $uri: $e');
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
