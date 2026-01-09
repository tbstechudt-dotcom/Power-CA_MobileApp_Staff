import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../../shared/widgets/app_header.dart';
import '../../../../shared/widgets/app_drawer.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color _getStatusColor() {
    switch (widget.statusFilter) {
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'Approved':
        return const Color(0xFF10B981);
      case 'Rejected':
        return const Color(0xFFEF4444);
      default:
        return AppTheme.primaryColor;
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

  @override
  void initState() {
    super.initState();
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
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final backBtnBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backBtnBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final backBtnIconColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textSecondaryColor;
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    // Update status bar style based on theme
    _updateStatusBarStyle(isDarkMode);

    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scaffoldBgColor,
      drawer: AppDrawer(currentStaff: widget.currentStaff),
      body: Column(
        children: [
          // Custom Header with Back Button - extends into status bar area
          Container(
            padding: EdgeInsets.only(
              left: 16.w,
              right: 16.w,
              top: MediaQuery.of(context).padding.top + 12.h,
              bottom: 12.h,
            ),
            decoration: BoxDecoration(
              color: headerBgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
              child: Row(
                children: [
                  // Back Button - circular design matching app header buttons
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42.w,
                      height: 42.h,
                      decoration: BoxDecoration(
                        color: backBtnBgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: backBtnBorderColor,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 18.sp,
                          color: backBtnIconColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Status Icon and Title
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      statusIcon,
                      size: 20.sp,
                      color: statusColor,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.statusFilter,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          '${widget.leaves.length} ${widget.leaves.length == 1 ? 'request' : 'requests'}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search leaves...',
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20.sp,
                    color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18.sp, color: isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF8F9FC),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.sp,
                  color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937),
                ),
              ),
            ),

            // Leave List
            Expanded(
              child: Container(
                color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC),
                child: _filteredLeaves.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        itemCount: _filteredLeaves.length,
                        itemBuilder: (context, index) {
                          final leave = _filteredLeaves[index];
                          return _buildLeaveCard(context, leave);
                        },
                      ),
              ),
            ),
          ],
        ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 2,
        currentStaff: widget.currentStaff,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final emptyBgColor = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8F9FC);
    final iconColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);
    final titleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final subtitleColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: emptyBgColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              _getStatusIcon(),
              size: 40.sp,
              color: iconColor,
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No leaves found',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'No ${widget.statusFilter.toLowerCase()} leaves available',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, Map<String, dynamic> leave) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final textMutedColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFF9CA3AF);
    final dividerColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

    final statusColor = leave['statusColor'] as Color;
    final fromDate = leave['fromDate'] as DateTime;
    final toDate = leave['toDate'] as DateTime;
    final days = leave['days'] as double;
    final daysDisplay = days == days.toInt() ? days.toInt().toString() : days.toStringAsFixed(1);

    return GestureDetector(
      onTap: () => _navigateToLeaveDetail(leave),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Leave Type and Days
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: isDarkMode ? 0.15 : 0.06),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(11.r),
                  topRight: Radius.circular(11.r),
                ),
              ),
              child: Row(
                children: [
                  // Leave Type Icon
                  Container(
                    width: 36.w,
                    height: 36.h,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: isDarkMode ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.event_available_rounded,
                      size: 18.sp,
                      color: statusColor,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Leave Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave Type',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: textSecondaryColor,
                          ),
                        ),
                        Text(
                          leave['type'],
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Days Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '$daysDisplay ${days == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14.sp,
                        color: textSecondaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          fromDate == toDate
                              ? DateFormat('dd MMM yyyy').format(fromDate)
                              : '${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: textPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),

                  // Reason
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 14.sp,
                        color: textMutedColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          leave['displayReason'] ?? leave['reason'],
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: textSecondaryColor,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),

                  // Divider
                  Divider(height: 1, color: dividerColor),
                  SizedBox(height: 6.h),

                  // Applied Date
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14.sp,
                        color: textMutedColor,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Applied ${DateFormat('dd MMM yyyy').format(leave['appliedDate'])}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF374151),
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
