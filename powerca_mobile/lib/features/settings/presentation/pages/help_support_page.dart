import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';

/// Help & Support page with FAQs, guides, and contact options
class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  // Track expanded FAQ items
  final Set<int> _expandedFaqIndices = {};

  // FAQ Data
  final List<Map<String, String>> _faqItems = [
    {
      'question': 'How do I log my work hours?',
      'answer':
          'Navigate to any job from the Job List, then tap "Add Work Log" to record your work hours. You can specify the date, start time, end time, and add notes about the work performed. Your logged hours will be synced automatically.',
    },
    {
      'question': 'How do I apply for leave?',
      'answer':
          'Go to the Leave Requests section from the bottom navigation. Tap the "+" button to create a new leave request. Select your leave type, specify the dates, and add any relevant notes. Your manager will be notified and can approve or reject your request.',
    },
    {
      'question': 'What do the job status colors mean?',
      'answer':
          'Jobs are color-coded by status:\n'
          '- Blue (In Progress): Work is currently ongoing\n'
          '- Green (Completed): Job has been finished\n'
          '- Orange (Pending): Awaiting assignment or start\n'
          '- Red (On Hold): Job is temporarily paused\n'
          '- Gray (Draft): Job is not yet active',
    },
    {
      'question': 'How do I complete a task checklist?',
      'answer':
          'Open a job and navigate to the Tasks tab. You\'ll see a list of tasks with checkboxes. Tap on each task to mark it as complete. The job progress percentage updates automatically based on completed tasks.',
    },
    {
      'question': 'Why can\'t I see certain jobs?',
      'answer':
          'You can only see jobs that are assigned to you or your team. If you believe a job should be visible to you, please contact your administrator to verify your assignment.',
    },
    {
      'question': 'How do I update my profile information?',
      'answer':
          'Profile information is managed by your organization\'s administrator through the desktop application. If you need to update your details (phone number, email, etc.), please contact your HR department or admin.',
    },
    {
      'question': 'What is the Pinboard?',
      'answer':
          'The Pinboard is your organization\'s notice board for announcements, events, and important updates. You can view posts, like them, and add comments. Categories help organize different types of announcements.',
    },
    {
      'question': 'How does data sync work?',
      'answer':
          'The app automatically syncs your data with the server when you have an internet connection. Work logs, task completions, and leave requests are uploaded immediately. If you\'re offline, changes are saved locally and synced when connectivity is restored.',
    },
    {
      'question': 'How do I enable/disable notifications?',
      'answer':
          'Go to Settings from your profile menu. Under the Notifications section, you can toggle notifications on or off globally, and also control specific notification types like leave updates and pinboard reminders.',
    },
    {
      'question': 'What should I do if the app is running slow?',
      'answer':
          'Try these steps:\n'
          '1. Close and reopen the app\n'
          '2. Check your internet connection\n'
          '3. Clear the app cache from your device settings\n'
          '4. Ensure your app is updated to the latest version\n'
          '5. If issues persist, contact support',
    },
  ];

  // Feature Guide Data
  final List<Map<String, dynamic>> _featureGuides = [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard_rounded,
      'color': Color(0xFF3B82F6),
      'description':
          'Your home screen showing today\'s summary, pending tasks, upcoming deadlines, and quick access to recent jobs.',
    },
    {
      'title': 'Job Management',
      'icon': Icons.list_alt_rounded,
      'color': Color(0xFF10B981),
      'description':
          'View all assigned jobs, track progress, complete task checklists, and log work hours for each job.',
    },
    {
      'title': 'Work Diary',
      'icon': Icons.access_time_rounded,
      'color': Color(0xFF8B5CF6),
      'description':
          'Record daily work entries with start/end times. Track total hours worked per job and generate timesheets.',
    },
    {
      'title': 'Leave Requests',
      'icon': Icons.event_note_rounded,
      'color': Color(0xFFF59E0B),
      'description':
          'Apply for leave, view leave balance, track request status (pending, approved, rejected), and see leave history.',
    },
    {
      'title': 'Pinboard',
      'icon': Icons.push_pin_rounded,
      'color': Color(0xFFEF4444),
      'description':
          'Stay updated with company announcements, events, policies, and team updates. Engage with likes and comments.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // Theme-aware colors
    final headerColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final titleColor =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
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
          'Help & Support',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: surfaceColor,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions Section
              _buildSectionHeader('Quick Actions', titleColor),
              SizedBox(height: 12.h),
              _buildQuickActionsCard(
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                iconColor: iconColor,
              ),

              SizedBox(height: 24.h),

              // Feature Guides Section
              _buildSectionHeader('Feature Guides', titleColor),
              SizedBox(height: 12.h),
              _buildFeatureGuidesCard(
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),

              SizedBox(height: 24.h),

              // FAQ Section
              _buildSectionHeader('Frequently Asked Questions', titleColor),
              SizedBox(height: 12.h),
              _buildFaqSection(
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),

              SizedBox(height: 24.h),

              // Contact Support Section
              _buildSectionHeader('Contact Support', titleColor),
              SizedBox(height: 12.h),
              _buildContactSupportCard(
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                iconColor: iconColor,
              ),

              SizedBox(height: 24.h),

              // Troubleshooting Tips Section
              _buildSectionHeader('Troubleshooting Tips', titleColor),
              SizedBox(height: 12.h),
              _buildTroubleshootingCard(
                isDark: isDark,
                cardColor: cardColor,
                borderColor: borderColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),

              SizedBox(height: 32.h),
            ],
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

  Widget _buildQuickActionsCard({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color subtitleColor,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          _buildQuickActionItem(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFF3B82F6),
            title: 'Email Support',
            subtitle: 'contact@powerca.in',
            onTap: () => _launchEmail('contact@powerca.in'),
            showDivider: true,
            dividerColor: borderColor,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
          ),
          _buildQuickActionItem(
            icon: Icons.phone_outlined,
            iconColor: const Color(0xFF10B981),
            title: 'Call Support',
            subtitle: '+91 98422 24635',
            onTap: () => _launchPhone('+919842224635'),
            showDivider: true,
            dividerColor: borderColor,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
          ),
          _buildQuickActionItem(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Visit Website',
            subtitle: 'www.powerca.in',
            onTap: () => _launchUrl('https://www.powerca.in'),
            showDivider: false,
            dividerColor: borderColor,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool showDivider,
    required Color dividerColor,
    required Color titleColor,
    required Color subtitleColor,
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16.sp,
                  color: subtitleColor,
                ),
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

  Widget _buildFeatureGuidesCard({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: _featureGuides.asMap().entries.map((entry) {
          final index = entry.key;
          final guide = entry.value;
          final isLast = index == _featureGuides.length - 1;

          return _buildFeatureGuideItem(
            icon: guide['icon'] as IconData,
            iconColor: guide['color'] as Color,
            title: guide['title'] as String,
            description: guide['description'] as String,
            showDivider: !isLast,
            dividerColor: borderColor,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureGuideItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool showDivider,
    required Color dividerColor,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                        height: 1.4,
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
            indent: 70.w,
          ),
      ],
    );
  }

  Widget _buildFaqSection({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: _faqItems.asMap().entries.map((entry) {
          final index = entry.key;
          final faq = entry.value;
          final isExpanded = _expandedFaqIndices.contains(index);
          final isLast = index == _faqItems.length - 1;

          return _buildFaqItem(
            index: index,
            question: faq['question']!,
            answer: faq['answer']!,
            isExpanded: isExpanded,
            showDivider: !isLast,
            dividerColor: borderColor,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFaqItem({
    required int index,
    required String question,
    required String answer,
    required bool isExpanded,
    required bool showDivider,
    required Color dividerColor,
    required Color titleColor,
    required Color subtitleColor,
    required bool isDark,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedFaqIndices.remove(index);
              } else {
                _expandedFaqIndices.add(index);
              }
            });
          },
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28.w,
                  height: 28.h,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Center(
                    child: Text(
                      'Q',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                          height: 1.4,
                        ),
                      ),
                      if (isExpanded) ...[
                        SizedBox(height: 10.h),
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            answer,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: subtitleColor,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 24.sp,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 56.w,
          ),
      ],
    );
  }

  Widget _buildContactSupportCard({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color subtitleColor,
    required Color iconColor,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  size: 26.sp,
                  color: const Color(0xFF10B981),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need More Help?',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Our support team is here to help',
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
            ],
          ),
          SizedBox(height: 16.h),
          Text(
            'Support Hours',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          SizedBox(height: 8.h),
          _buildSupportHoursRow(
            'Monday - Saturday',
            '9:30 AM - 6:00 PM IST',
            subtitleColor,
          ),
          SizedBox(height: 4.h),
          _buildSupportHoursRow(
            'Sunday',
            'Closed',
            subtitleColor,
          ),
          SizedBox(height: 16.h),
          Text(
            'Response Time',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'We typically respond within 24 business hours. For urgent issues, please call our support hotline.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: subtitleColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportHoursRow(String day, String hours, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
        Text(
          hours,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTroubleshootingCard({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    final tips = [
      {
        'icon': Icons.wifi_off_rounded,
        'title': 'Connection Issues',
        'tip': 'Check your internet connection and try switching between WiFi and mobile data.',
      },
      {
        'icon': Icons.sync_problem_rounded,
        'title': 'Sync Problems',
        'tip': 'Pull down to refresh on any list screen. If data doesn\'t update, sign out and sign back in.',
      },
      {
        'icon': Icons.memory_rounded,
        'title': 'App Running Slow',
        'tip': 'Close other apps running in background. Clear app cache from device settings if needed.',
      },
      {
        'icon': Icons.login_rounded,
        'title': 'Login Issues',
        'tip': 'Ensure you\'re using the correct username. Contact your admin if your account is locked.',
      },
      {
        'icon': Icons.notifications_off_rounded,
        'title': 'Not Receiving Notifications',
        'tip': 'Check notification permissions in device settings and ensure notifications are enabled in app settings.',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: tips.asMap().entries.map((entry) {
          final index = entry.key;
          final tip = entry.value;
          final isLast = index == tips.length - 1;

          return Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        tip['icon'] as IconData,
                        size: 20.sp,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip['title'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            tip['tip'] as String,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: subtitleColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: borderColor,
                  indent: 70.w,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // URL Launcher Methods
  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'PowerCA App Support Request',
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open email app'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone app'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open website'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
