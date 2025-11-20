import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/entities/staff.dart';

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
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          .order('remdate', ascending: false);

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
    // Filter reminders based on current tab
    switch (_tabController.index) {
      case 0: // Due Date - work-related reminders
        return _reminders.where((r) {
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

      case 1: // Meetings - meeting related
        return _reminders.where((r) {
          final remtype = (r['remtype'] as String).toLowerCase();
          final remtitle = (r['remtitle'] as String).toLowerCase();
          final remnotes = (r['remnotes'] as String).toLowerCase();
          return remtype.contains('meeting') ||
                 remtitle.contains('meeting') ||
                 remnotes.contains('meeting') ||
                 remtype.contains('board') ||
                 remtype.contains('discussion');
        }).toList();

      case 2: // Greetings - birthdays, celebrations
        return _reminders.where((r) {
          final remtype = (r['remtype'] as String).toLowerCase();
          return remtype.contains('birthday') ||
                 remtype.contains('greeting') ||
                 remtype.contains('celebration') ||
                 remtype.contains('anniversary') ||
                 remtype.contains('festival');
        }).toList();

      default:
        return _reminders;
    }
  }

  Color _getCategoryColor(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.calendar_today, size: 20),
                text: 'Due Date',
              ),
              Tab(
                icon: Icon(Icons.people, size: 20),
                text: 'Meetings',
              ),
              Tab(
                icon: Icon(Icons.celebration, size: 20),
                text: 'Greetings',
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
                        _buildReminderList(2), // Greetings
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
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filteredReminders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final reminder = filteredReminders[index];
          return _buildReminderCard(reminder, tabIndex);
        },
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder, int tabIndex) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final categoryColor = _getCategoryColor(tabIndex);

    // Parse the date
    final remdate = reminder['remdate'] as DateTime?;
    final remduedate = reminder['remduedate'] as DateTime?;
    final displayDate = remduedate ?? remdate ?? DateTime.now();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // You can add navigation to detail page here if needed
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Type Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reminder['remtitle'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reminder['remtype'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: categoryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Description
              Text(
                reminder['remnotes'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // Client Name
              Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 16,
                    color: categoryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reminder['clientName'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date and Time
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: categoryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${dateFormat.format(displayDate)}${reminder['remtime'] != '' ? ' at ${reminder['remtime']}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Status
              Row(
                children: [
                  Icon(
                    reminder['remstatus'] == 1 ? Icons.check_circle : Icons.pending,
                    size: 16,
                    color: reminder['remstatus'] == 1 ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reminder['remstatus'] == 1 ? 'Completed' : 'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      color: reminder['remstatus'] == 1 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
