import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch reminders for current staff
      final remindersResponse = await supabase
          .from('reminder')
          .select('rem_id, staff_id, client_id, remtype, remdate, remduedate, remtime, remtitle, remnotes, remstatus')
          .eq('staff_id', widget.currentStaff.staffId)
          .order('remdate', ascending: true);

      // Get unique client IDs
      final clientIds = remindersResponse
          .map((reminder) => reminder['client_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // Fetch client names for all client IDs
      Map<int, String> clientNames = {};
      if (clientIds.isNotEmpty) {
        final clientsResponse = await supabase
            .from('climaster')
            .select('client_id, clientname')
            .inFilter('client_id', clientIds);

        for (var client in clientsResponse) {
          clientNames[client['client_id'] as int] = client['clientname'] ?? 'Unknown Client';
        }
      }

      // Transform database records to UI format
      final reminders = remindersResponse.map<Map<String, dynamic>>((record) {
        final clientId = record['client_id'] as int?;
        final clientName = clientId != null ? (clientNames[clientId] ?? 'Unknown Client') : 'No Client';

        return {
          'rem_id': record['rem_id'],
          'staff_id': record['staff_id'],
          'client_id': clientId,
          'clientName': clientName,
          'remtype': record['remtype'] ?? 'General',
          'remdate': record['remdate'] != null ? DateTime.parse(record['remdate']) : null,
          'remduedate': record['remduedate'] != null ? DateTime.parse(record['remduedate']) : null,
          'remtime': record['remtime'] ?? '',
          'remtitle': record['remtitle'] ?? 'No Title',
          'remnotes': record['remnotes'] ?? 'No description',
          'remstatus': record['remstatus'] ?? 0,
        };
      }).toList();

      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reminders: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredReminders() {
    List<Map<String, dynamic>> filtered;

    // Filter reminders based on current tab
    switch (_tabController.index) {
      case 0: // Due Date - work-related reminders
        filtered = _reminders.where((r) {
          final remtype = (r['remtype'] as String).toLowerCase();
          return remtype.contains('gst') ||
                 remtype.contains('tds') ||
                 remtype.contains('income') ||
                 remtype.contains('tax') ||
                 remtype.contains('companies') ||
                 remtype.contains('office') ||
                 remtype.contains('work') ||
                 remtype.contains('tcs') ||
                 remtype.contains('llp') ||
                 remtype.contains('filing') ||
                 remtype.contains('renewal');
        }).toList();
        break;

      case 1: // Meetings - meeting related
        filtered = _reminders.where((r) {
          final remtype = (r['remtype'] as String).toLowerCase();
          final remtitle = (r['remtitle'] as String).toLowerCase();
          final remnotes = (r['remnotes'] as String).toLowerCase();
          return remtype.contains('meeting') ||
                 remtitle.contains('meeting') ||
                 remnotes.contains('meeting') ||
                 remtype.contains('board') ||
                 remtype.contains('discussion');
        }).toList();
        break;

      default:
        filtered = _reminders;
    }

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

    return filtered;
  }

  Color _getCategoryColor(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
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
    return Column(
      children: [
        // Search/Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search reminders...',
              hintStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF1F2937),
            ),
          ),
        ),

        // Tab Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF6B7280),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 16),
                    SizedBox(width: 6),
                    Text('Due Date'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people, size: 16),
                    SizedBox(width: 6),
                    Text('Meetings'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
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
                        _buildReminderList(0), // Due Date
                        _buildReminderList(1), // Meetings
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildReminderList(int tabIndex) {
    final filteredReminders = _getFilteredReminders();

    if (filteredReminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      color: const Color(0xFF2563EB),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: filteredReminders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final reminder = filteredReminders[index];
          return _buildReminderCard(reminder, tabIndex);
        },
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder, int tabIndex) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final categoryColor = _getCategoryColor(tabIndex);

    // Parse the date
    final remdate = reminder['remdate'] as DateTime?;
    final remduedate = reminder['remduedate'] as DateTime?;
    final displayDate = remduedate ?? remdate ?? DateTime.now();


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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Type and Status
            Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tabIndex == 0 ? Icons.calendar_today : Icons.people,
                    size: 18,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 8),
                // Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Type',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        reminder['remtype'] as String,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: categoryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  reminder['remtitle'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Description
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes_outlined,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reminder['remnotes'] as String,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Divider
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 6),

                // Client and Date Row
                Row(
                  children: [
                    // Client
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reminder['clientName'] as String,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF374151),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Due Date
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dateFormat.format(displayDate),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: categoryColor,
                              ),
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
        ],
      ),
      ),
    );
  }
}
