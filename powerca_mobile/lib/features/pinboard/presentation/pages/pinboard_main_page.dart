import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/theme.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/notification_service.dart';
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

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
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

  Color _getCategoryColor(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return AppTheme.primaryColor; // Primary blue for Due Date
      case 1:
        return const Color(0xFF0D9488); // Teal accent for Meetings
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final searchBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final searchFieldColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC);
    final searchHintColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);
    final searchTextColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final tabBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final unselectedTabColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Column(
      children: [
        // Search Bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          color: searchBgColor,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search reminders...',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                color: searchHintColor,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 20.sp,
                color: searchHintColor,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18.sp, color: searchHintColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: searchFieldColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              color: searchTextColor,
            ),
          ),
        ),

        // Tab Bar
        Container(
          color: tabBgColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: unselectedTabColor,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Due Dates'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_rounded, size: 16),
                    SizedBox(width: 6),
                    Text('Meetings'),
                  ],
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 8.h),

        // Tab Views
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
                          SizedBox(height: 16.h),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14.sp, color: isDarkMode ? const Color(0xFFF1F5F9) : null),
                          ),
                          SizedBox(height: 16.h),
                          ElevatedButton.icon(
                            onPressed: _loadReminders,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final filteredReminders = _getFilteredReminders();
    final categoryColor = _getCategoryColor(tabIndex);
    final emptyIconColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFE0E0E0);
    final emptyTextColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF8F8E90);
    final emptySubTextColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFA8A8A8);

    if (filteredReminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tabIndex == 0 ? Icons.event_available_rounded : Icons.event_busy_rounded,
              size: 64.sp,
              color: emptyIconColor,
            ),
            SizedBox(height: 16.h),
            Text(
              tabIndex == 0 ? 'No upcoming due dates' : 'No upcoming meetings',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: emptyTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Only current and future items are shown',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: emptySubTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        itemCount: filteredReminders.length,
        itemBuilder: (context, index) {
          final reminder = filteredReminders[index];
          return _buildReminderCard(context, reminder, tabIndex, categoryColor);
        },
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Map<String, dynamic> reminder, int tabIndex, Color categoryColor) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29);
    final notesColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF8F8E90);
    final notesIconColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFA8A8A8);
    final clientColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final clientIconColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final chevronColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final daysUntilBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF5F7FA);
    final daysUntilTextColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

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

    return GestureDetector(
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
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: isDueToday ? AppTheme.warningColor : categoryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14.r),
                    bottomLeft: Radius.circular(14.r),
                  ),
                ),
              ),
              // Main content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Type badge and date badge
                      Row(
                        children: [
                          // Type badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tabIndex == 0 ? Icons.calendar_today_rounded : Icons.people_rounded,
                                  size: 12.sp,
                                  color: categoryColor,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  reminder['remtype'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: categoryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Days until badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: isDueToday
                                  ? AppTheme.warningColor.withValues(alpha: 0.1)
                                  : daysUntilBgColor,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              isDueToday
                                  ? 'Today'
                                  : daysUntil == 1
                                      ? 'Tomorrow'
                                      : 'In $daysUntil days',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: isDueToday
                                    ? AppTheme.warningColor
                                    : daysUntilTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 10.h),

                      // Title
                      Text(
                        reminder['remtitle'] as String,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 6.h),

                      // Notes
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 14.sp,
                            color: notesIconColor,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              reminder['remnotes'] as String,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                                color: notesColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),

                      // Footer: Client and Date
                      Row(
                        children: [
                          // Client
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 12.sp,
                                  color: clientIconColor,
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    reminder['clientName'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w500,
                                      color: clientColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Date
                          Row(
                            children: [
                              Icon(
                                Icons.event_rounded,
                                size: 12.sp,
                                color: categoryColor,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                dateFormat.format(displayDate),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Right chevron
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20.sp,
                  color: chevronColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
