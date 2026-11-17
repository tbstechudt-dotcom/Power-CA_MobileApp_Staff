import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_drawer.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../../auth/domain/entities/staff.dart';
import 'leave_detail_page.dart';

class LeaveFilteredPage extends StatefulWidget {
  final Staff currentStaff;
  final String statusFilter;
  final List<Map<String, dynamic>> leaves;

  const LeaveFilteredPage({
    super.key,
    required this.currentStaff,
    required this.statusFilter,
    required this.leaves,
  });

  @override
  State<LeaveFilteredPage> createState() => _LeaveFilteredPageState();
}

class _LeaveFilteredPageState extends State<LeaveFilteredPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static Color _colorForStatus(SoftPalette p, String? status) {
    switch (status) {
      case 'Pending':
        return p.warning;
      case 'Approved':
        return p.success;
      case 'Rejected':
        return p.danger;
      default:
        return p.accent;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.statusFilter) {
      case 'Pending':
        return Icons.pending_actions_rounded;
      case 'Approved':
        return Icons.check_circle_rounded;
      case 'Rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }

  List<Map<String, dynamic>> get _filteredLeaves {
    List<Map<String, dynamic>> filtered = widget.leaves;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((leave) {
        final type = (leave['type'] as String).toLowerCase();
        final reason = (leave['displayReason'] ?? leave['reason'] as String).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return type.contains(query) || reason.contains(query);
      }).toList();
    }

    return filtered;
  }

  void _navigateToLeaveDetail(Map<String, dynamic> leave) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LeaveDetailPage(
          leave: leave,
          onDeleted: () {
            // Go back to main leave page after deletion
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  /// Update status bar style based on theme
  void _updateStatusBarStyle(bool isDarkMode) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    // Update status bar style based on theme
    _updateStatusBarStyle(p.isDark);

    final statusColor = _colorForStatus(p, widget.statusFilter);
    final leaves = _filteredLeaves;

    return SoftScaffold(
      title: widget.statusFilter,
      subtitle:
          '${widget.leaves.length} ${widget.leaves.length == 1 ? 'request' : 'requests'}',
      actions: [SoftIconBadge(icon: _getStatusIcon(), color: statusColor)],
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 2,
        currentStaff: widget.currentStaff,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                hint: 'Search leaves...',
                icon: Icons.search_rounded,
                pill: true,
                dense: true,
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

          // Leave List
          Expanded(
            child: leaves.isEmpty
                ? SoftMessage(
                    icon: _getStatusIcon(),
                    title: 'No leaves found',
                    message: 'No ${widget.statusFilter.toLowerCase()} leaves available',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: leaves.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildLeaveCard(context, leaves[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, Map<String, dynamic> leave) {
    final p = SoftPalette.of(context);
    final status = leave['status'] as String?;
    final statusColor = _colorForStatus(p, status);
    final fromDate = leave['fromDate'] as DateTime;
    final toDate = leave['toDate'] as DateTime;
    final days = leave['days'] as double;
    final daysDisplay = days == days.toInt() ? days.toInt().toString() : days.toStringAsFixed(1);

    return SoftCard(
      onTap: () => _navigateToLeaveDetail(leave),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Leave Type and Days
          Row(
            children: [
              SoftIconBadge(icon: Icons.event_available_rounded, color: statusColor, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave['type'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftText.heading(p, size: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fromDate == toDate
                          ? DateFormat('dd MMM yyyy').format(fromDate)
                          : '${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                      style: SoftText.caption(p, size: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$daysDisplay ${days == 1 ? 'day' : 'days'}',
                  style: SoftText.caption(p, size: 11.5)
                      .copyWith(color: p.ink, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reason
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notes_rounded, size: 16, color: p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  leave['displayReason'] ?? leave['reason'],
                  style: SoftText.body(p, size: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: p.border),
          const SizedBox(height: 10),

          // Applied Date + status
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 15, color: p.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Applied ${DateFormat('dd MMM yyyy').format(leave['appliedDate'])}',
                  style: SoftText.caption(p),
                ),
              ),
              if (status != null) SoftStatusPill(label: status, color: statusColor),
            ],
          ),
        ],
      ),
    );
  }
}
