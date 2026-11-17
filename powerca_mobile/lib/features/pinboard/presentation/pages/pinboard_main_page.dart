import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/theme.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/tab_data_cache.dart';
import '../../../auth/domain/entities/staff.dart';
import 'pinboard_detail_page.dart';

class PinboardMainPage extends StatefulWidget {
  final Staff currentStaff;

  const PinboardMainPage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<PinboardMainPage> createState() => _PinboardMainPageState();
}

class _PinboardMainPageState extends State<PinboardMainPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Show the last loaded reminders instantly; the load refreshes quietly.
    final cached = TabDataCache.read<List<Map<String, dynamic>>>(_cacheKey);
    if (cached != null) {
      _reminders = cached;
      _isLoading = false;
    }
    _loadReminders();

    // Listen to tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Refresh to show filtered reminders
      }
    });
  }

  /// Check for new pinboard items and trigger notifications
  Future<void> _checkNewPinboardItems(List<Map<String, dynamic>> reminders) async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

    // Skip if notifications are disabled
    if (!notificationProvider.pinboardNotificationsEnabled) return;

    final lastCheckTimestamp = notificationProvider.lastPinboardCheckTimestamp;
    final dateFormat = DateFormat('dd MMM yyyy');

    // If no previous check, just update timestamp and return (first time setup)
    if (lastCheckTimestamp == null) {
      await notificationProvider.updatePinboardCheckTimestamp();
      return;
    }

    // Find reminders created after the last check
    for (final reminder in reminders) {
      final remDate = reminder['remdate'] as DateTime?;
      final remDueDate = reminder['remduedate'] as DateTime?;

      // Use remdate as the creation indicator (when the reminder was assigned)
      if (remDate != null && remDate.isAfter(lastCheckTimestamp)) {
        final displayDate = remDueDate ?? remDate;

        await NotificationService().showPinboardNotification(
          remId: reminder['rem_id'] as String,
          title: reminder['remtitle'] as String,
          clientName: reminder['clientName'] as String,
          dueDate: dateFormat.format(displayDate),
        );
      }
    }

    // Update the last check timestamp
    await notificationProvider.updatePinboardCheckTimestamp();
  }

  String get _cacheKey => 'pinboard:${widget.currentStaff.staffId}';

  Future<void> _loadReminders() async {
    // Spinner only when there's nothing to show yet.
    final hasCache = TabDataCache.read<List<Map<String, dynamic>>>(_cacheKey) != null;
    setState(() {
      _isLoading = !hasCache;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final staffId = widget.currentStaff.staffId;

      // Fetch reminders assigned to this staff
      // Filter by staff_id = logged in staff's ID
      final remindersResponse = await supabase
          .from('reminder')
          .select('''
            rem_id,
            staff_id,
            client_id,
            client_name,
            remtype,
            remtitle,
            remnotes,
            remdate,
            remduedate,
            remtime,
            remstatus,
            color
          ''')
          .eq('staff_id', staffId)
          .order('remduedate', ascending: true);

      // Transform reminders to pinboard format
      final reminders = (remindersResponse as List).map<Map<String, dynamic>>((record) {
        final remDate = record['remdate'] != null
            ? DateTime.parse(record['remdate'].toString())
            : null;
        final remDueDate = record['remduedate'] != null
            ? DateTime.parse(record['remduedate'].toString())
            : null;

        // Determine category based on remtype
        String category = 'due_date';
        if (record['remtype'] != null) {
          final remType = record['remtype'].toString().toLowerCase();
          if (remType.contains('meeting')) {
            category = 'meetings';
          }
        }

        return {
          'rem_id': record['rem_id']?.toString() ?? '',
          'staff_id': record['staff_id'],
          'client_id': record['client_id'],
          'clientName': record['client_name'] ?? 'Unknown Client',
          'remtype': record['remtype'] ?? 'Reminder',
          'category': category,
          'remdate': remDate,
          'remduedate': remDueDate,
          'remtime': record['remtime']?.toString() ?? '',
          'remtitle': record['remtitle'] ?? 'No Title',
          'remnotes': record['remnotes'] ?? '',
          'remstatus': record['remstatus'] ?? 0,
          'color': record['color'],
        };
      }).toList();

      // Check for new reminders and trigger notifications
      await _checkNewPinboardItems(reminders);

      TabDataCache.write(_cacheKey, reminders);
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reminders: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredReminders() {
    List<Map<String, dynamic>> filtered;

    // Get today's date at start of day for comparison
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Filter pinboard items based on current tab (using category field)
    switch (_tabController.index) {
      case 0: // Due Date category
        filtered = _reminders.where((r) {
          final category = (r['category'] as String?) ?? '';
          return category == 'due_date';
        }).toList();
        break;

      case 1: // Meetings category
        filtered = _reminders.where((r) {
          final category = (r['category'] as String?) ?? '';
          return category == 'meetings';
        }).toList();
        break;

      default:
        filtered = _reminders;
    }

    // Filter to show only current and future reminders (today or later)
    filtered = filtered.where((r) {
      final remdate = r['remdate'] as DateTime?;
      final remduedate = r['remduedate'] as DateTime?;
      final displayDate = remduedate ?? remdate;

      if (displayDate == null) return false;

      // Normalize to start of day for comparison
      final normalizedDate = DateTime(displayDate.year, displayDate.month, displayDate.day);
      return normalizedDate.compareTo(today) >= 0; // Today or future
    }).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        final title = (r['remtitle'] as String).toLowerCase();
        final client = (r['clientName'] as String).toLowerCase();
        final notes = (r['remnotes'] as String).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || client.contains(query) || notes.contains(query);
      }).toList();
    }

    // Sort by date (nearest first)
    filtered.sort((a, b) {
      final dateA = (a['remduedate'] ?? a['remdate']) as DateTime?;
      final dateB = (b['remduedate'] ?? b['remdate']) as DateTime?;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });

    return filtered;
  }

  Color _getCategoryColor(SoftPalette p, int tabIndex) {
    switch (tabIndex) {
      case 0:
        return p.accent; // Accent blue for Due Date
      case 1:
        return p.isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488); // Teal for Meetings
      default:
        return p.muted;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Due-date reminders falling between today and this Sunday.
  int _dueThisWeekCount() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(Duration(days: DateTime.sunday - today.weekday));
    return _reminders.where((r) {
      if (r['category'] != 'due_date') return false;
      final d = (r['remduedate'] ?? r['remdate']) as DateTime?;
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(today) && !day.isAfter(weekEnd);
    }).length;
  }

  List<({String text, bool strong})> _headlineParts() {
    if (_isLoading) {
      return const [
        (text: 'Loading your ', strong: false),
        (text: 'pinboard', strong: true),
        (text: '...', strong: false),
      ];
    }
    final n = _dueThisWeekCount();
    if (n == 0) {
      return const [
        (text: 'Nothing is ', strong: false),
        (text: 'due', strong: true),
        (text: ' this ', strong: false),
        (text: 'week.', strong: true),
      ];
    }
    return [
      (text: 'You have ', strong: false),
      (text: '$n ${n == 1 ? 'item' : 'items'}', strong: true),
      (text: ' due ', strong: false),
      (text: 'this week.', strong: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Eyebrow + headline
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeEyebrow('Pinboard'),
              HomeInlineHeadline(parts: _headlineParts()),
            ],
          ),
        ),

        // Tab switch (blue pill for the active tab, drives the TabController)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SoftTabSwitch(
            controller: _tabController,
            labels: const ['Due dates', 'Meetings'],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: softInputTextStyle(context),
            decoration: softInputDecoration(
              context,
              hint: 'Search reminders...',
              icon: Icons.search_rounded,
              pill: true,
              suffix: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Tab Views
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: p.ink, strokeWidth: 2.4))
              : _errorMessage != null
                  ? SoftMessage(
                      icon: Icons.error_outline_rounded,
                      title: 'Could not load reminders',
                      message: _errorMessage,
                      color: p.danger,
                      actionLabel: 'Retry',
                      onAction: _loadReminders,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReminderList(context, 0), // Due Date
                        _buildReminderList(context, 1), // Meetings
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildReminderList(BuildContext context, int tabIndex) {
    final p = SoftPalette.of(context);
    final filteredReminders = _getFilteredReminders();
    final categoryColor = _getCategoryColor(p, tabIndex);

    if (filteredReminders.isEmpty) {
      // Plain text empty state (no icon), as in the design.
      return RefreshIndicator(
        onRefresh: _loadReminders,
        color: p.ink,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 48, 32, 120),
          children: [
            Text(
              tabIndex == 0 ? 'No upcoming due dates.' : 'No upcoming meetings.',
              textAlign: TextAlign.center,
              style: SoftText.body(p, size: 15, color: p.inkSoft)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Only current and future items are shown.',
              textAlign: TextAlign.center,
              style: SoftText.caption(p, size: 12.5),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      color: p.ink,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        itemCount: filteredReminders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final reminder = filteredReminders[index];
          return _buildReminderCard(context, reminder, tabIndex, categoryColor);
        },
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Map<String, dynamic> reminder, int tabIndex, Color categoryColor) {
    final p = SoftPalette.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    // Parse the date
    final remdate = reminder['remdate'] as DateTime?;
    final remduedate = reminder['remduedate'] as DateTime?;
    final displayDate = remduedate ?? remdate ?? DateTime.now();

    // Check if due today
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final normalizedDate = DateTime(displayDate.year, displayDate.month, displayDate.day);
    final isDueToday = normalizedDate.compareTo(today) == 0;
    final daysUntil = normalizedDate.difference(today).inDays;
    final notes = reminder['remnotes'] as String;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PinboardDetailPage(
              currentStaff: widget.currentStaff,
              reminder: reminder,
            ),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftIconBadge(
            icon: tabIndex == 0 ? Icons.calendar_today_rounded : Icons.people_rounded,
            color: isDueToday ? p.warning : categoryColor,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: type and days-until pills
                Row(
                  children: [
                    Flexible(
                      child: SoftStatusPill(
                        label: reminder['remtype'] as String,
                        color: categoryColor,
                        showDot: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Spacer(),
                    SoftStatusPill(
                      label: isDueToday
                          ? 'Today'
                          : daysUntil == 1
                              ? 'Tomorrow'
                              : 'In $daysUntil days',
                      color: isDueToday ? p.warning : p.inkSoft,
                      showDot: isDueToday,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  reminder['remtitle'] as String,
                  style: SoftText.heading(p, size: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: SoftText.body(p, size: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),

                // Footer: Client and Date
                Row(
                  children: [
                    Icon(Icons.business_rounded, size: 13, color: p.muted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        reminder['clientName'] as String,
                        style: SoftText.caption(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.event_rounded, size: 13, color: p.inkSoft),
                    const SizedBox(width: 5),
                    Text(
                      dateFormat.format(displayDate),
                      style: SoftText.caption(p).copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
          ),
        ],
      ),
    );
  }
}

/// Tab switch bound to a [TabController] (keeps swipe + tap): the active
/// tab is a deep-blue pill, the others plain text.
class _SoftTabSwitch extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const _SoftTabSwitch({required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final activeBg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
    final activeFg = p.isDark ? p.background : Colors.white;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: controller.index == i ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => controller.animateTo(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: controller.index == i ? activeFg : p.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
