import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/modern_bottom_navigation.dart';
import '../../../auth/domain/entities/staff.dart';

class LeavePage extends StatefulWidget {
  final Staff currentStaff;

  const LeavePage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Leave balance (mock data - replace with API)
  final int _totalLeaves = 24;
  final int _usedLeaves = 8;
  final int _pendingLeaves = 3;

  // Leave requests from database
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _isLoadingLeaveRequests = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() {
      _isLoadingLeaveRequests = true;
    });

    try {
      final supabase = Supabase.instance.client;

      // Fetch leave requests for current staff
      final response = await supabase
          .from('learequest')
          .select()
          .eq('staff_id', widget.currentStaff.staffId)
          .order('requestdate', ascending: false);

      // Map leave type codes to display names
      final leaveTypeNames = {
        'SL': 'Sick Leave',
        'CL': 'Casual Leave',
        'EL': 'Earned Leave',
        'EM': 'Emergency Leave',
      };

      // Map approval status to display names and colors
      final statusMap = {
        'P': {'name': 'Pending', 'color': AppTheme.warningColor},
        'A': {'name': 'Approved', 'color': AppTheme.successColor},
        'R': {'name': 'Rejected', 'color': AppTheme.errorColor},
      };

      // Transform database records to UI format
      final leaveRequests = response.map<Map<String, dynamic>>((record) {
        final fromDate = DateTime.parse(record['fromdate']);
        final toDate = DateTime.parse(record['todate']);
        final days = toDate.difference(fromDate).inDays + 1;
        final status = statusMap[record['approval_status']] ??
            {'name': 'Unknown', 'color': AppTheme.warningColor};

        return {
          'id': record['learequest_id'],
          'fromDate': fromDate,
          'toDate': toDate,
          'days': days,
          'type': leaveTypeNames[record['leavetype']] ?? 'Unknown',
          'reason': record['leaveremarks'] ?? '',
          'status': status['name'],
          'statusColor': status['color'],
          'appliedDate': record['requestdate'] != null
              ? DateTime.parse(record['requestdate'])
              : DateTime.now(),
        };
      }).toList();

      setState(() {
        _leaveRequests = leaveRequests;
        _isLoadingLeaveRequests = false;
      });
    } catch (e) {
      print('Error loading leave requests: $e');
      setState(() {
        _isLoadingLeaveRequests = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Modern Top App Bar
            _buildModernAppBar(context),

            // Leave Balance Cards
            _buildLeaveBalanceCards(),

            // Tab Bar
            _buildTabBar(),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaveHistoryTab(),
                  _buildApplyLeaveTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 2,
        currentStaff: widget.currentStaff,
      ),
    );
  }

  Widget _buildModernAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Avatar
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0846B1), Color(0xFF2255FC)],
              ),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0846B1).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.currentStaff.name.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Name and role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave Requests',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF080E29),
                  ),
                ),
                Text(
                  widget.currentStaff.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ],
            ),
          ),
          // Notifications
          Container(
            width: 40.w,
            height: 40.h,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 20.sp,
                    color: const Color(0xFF080E29),
                  ),
                ),
                Positioned(
                  right: 10.w,
                  top: 10.h,
                  child: Container(
                    width: 8.w,
                    height: 8.h,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF1E05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCards() {
    final availableLeaves = _totalLeaves - _usedLeaves;

    return Container(
      margin: EdgeInsets.all(16.w),
      child: Row(
        children: [
          // Available Leaves
          Expanded(
            child: _buildBalanceCard(
              title: 'Available',
              count: availableLeaves,
              icon: Icons.beach_access,
              gradientColors: const [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ),
          ),
          SizedBox(width: 12.w),
          // Used Leaves
          Expanded(
            child: _buildBalanceCard(
              title: 'Used',
              count: _usedLeaves,
              icon: Icons.event_busy,
              gradientColors: const [Color(0xFF2196F3), Color(0xFF42A5F5)],
            ),
          ),
          SizedBox(width: 12.w),
          // Pending Leaves
          Expanded(
            child: _buildBalanceCard(
              title: 'Pending',
              count: _pendingLeaves,
              icon: Icons.pending_actions,
              gradientColors: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required int count,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            count.toString(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8F8E90),
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Leave History'),
          Tab(text: 'Apply Leave'),
        ],
      ),
    );
  }

  Widget _buildLeaveHistoryTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _leaveRequests.length,
      itemBuilder: (context, index) {
        final leave = _leaveRequests[index];
        return _buildLeaveRequestCard(leave);
      },
    );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> leave) {
    final fromDate = leave['fromDate'] as DateTime;
    final toDate = leave['toDate'] as DateTime;
    final days = leave['days'] as int;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Type and Status
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 14.sp,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      leave['type'],
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: (leave['statusColor'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  leave['status'],
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: leave['statusColor'],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Date Range
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16.sp,
                color: const Color(0xFF8F8E90),
              ),
              SizedBox(width: 8.w),
              Text(
                '${DateFormat('dd MMM yyyy').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF080E29),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  '$days ${days == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // Reason
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.description_outlined,
                size: 16.sp,
                color: const Color(0xFF8F8E90),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  leave['reason'],
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8F8E90),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 8.h),

          // Applied Date
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14.sp,
                color: const Color(0xFFA8A8A8),
              ),
              SizedBox(width: 6.w),
              Text(
                'Applied on ${DateFormat('dd MMM yyyy').format(leave['appliedDate'])}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFA8A8A8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplyLeaveTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions Card
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryColor,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'Fill in the form below to submit a new leave request',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Apply Leave Form
          _buildLeaveApplicationForm(),
        ],
      ),
    );
  }

  Widget _buildLeaveApplicationForm() {
    DateTime? fromDate;
    DateTime? toDate;
    String? leaveType;
    final reasonController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setFormState) {
        // Calculate number of days
        int? numberOfDays;
        if (fromDate != null && toDate != null) {
          numberOfDays = toDate!.difference(fromDate!).inDays + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Leave Type Dropdown
            Text(
              'Leave Type',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE9F0F8)),
              ),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  hintText: 'Select leave type',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    color: const Color(0xFFA8A8A8),
                  ),
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
                items: ['Sick Leave', 'Casual Leave', 'Earned Leave', 'Emergency Leave']
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.sp,
                            ),
                          ),
                        ),)
                    .toList(),
                onChanged: (value) {
                  setFormState(() {
                    leaveType = value;
                  });
                },
              ),
            ),

            SizedBox(height: 20.h),

            // From Date
            Text(
              'From Date',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppTheme.primaryColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setFormState(() {
                    fromDate = date;
                    // Reset toDate if it's before fromDate
                    if (toDate != null && toDate!.isBefore(fromDate!)) {
                      toDate = null;
                    }
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE9F0F8)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20.sp,
                      color: const Color(0xFF8F8E90),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      fromDate != null
                          ? DateFormat('dd MMM yyyy').format(fromDate!)
                          : 'Select start date',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.sp,
                        color: fromDate != null
                            ? const Color(0xFF080E29)
                            : const Color(0xFFA8A8A8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // To Date
            Text(
              'To Date',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            InkWell(
              onTap: fromDate == null
                  ? null
                  : () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: fromDate!,
                        firstDate: fromDate!,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppTheme.primaryColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setFormState(() {
                          toDate = date;
                        });
                      }
                    },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: fromDate == null
                      ? const Color(0xFFF5F7FA)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE9F0F8)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20.sp,
                      color: fromDate == null
                          ? const Color(0xFFA8A8A8)
                          : const Color(0xFF8F8E90),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      toDate != null
                          ? DateFormat('dd MMM yyyy').format(toDate!)
                          : 'Select end date',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.sp,
                        color: toDate != null
                            ? const Color(0xFF080E29)
                            : const Color(0xFFA8A8A8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Number of Days Display
            if (numberOfDays != null) ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 18.sp,
                      color: AppTheme.successColor,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Total: $numberOfDays ${numberOfDays == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 20.h),

            // Reason
            Text(
              'Reason',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF080E29),
              ),
            ),
            SizedBox(height: 8.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE9F0F8)),
              ),
              child: TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter reason for leave...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    color: const Color(0xFFA8A8A8),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16.w),
                ),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  color: const Color(0xFF080E29),
                ),
              ),
            ),

            SizedBox(height: 32.h),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: () async {
                  // Validate form
                  if (leaveType == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select leave type'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (fromDate == null || toDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select dates'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter reason'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // Show loading indicator
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  try {
                    final supabase = Supabase.instance.client;

                    // Map leave type to code
                    final leaveTypeCode = {
                      'Sick Leave': 'SL',
                      'Casual Leave': 'CL',
                      'Earned Leave': 'EL',
                      'Emergency Leave': 'EM',
                    }[leaveType] ?? 'CL';

                    // Generate unique learequest_id (max 99999 due to numeric(5,0) precision)
                    // Use timestamp modulo to get a 5-digit number
                    final requestId = DateTime.now().millisecondsSinceEpoch % 100000;

                    final leaveData = {
                      'org_id': widget.currentStaff.orgId,
                      'con_id': widget.currentStaff.conId,
                      'loc_id': widget.currentStaff.locId,
                      'learequest_id': requestId,
                      'staff_id': widget.currentStaff.staffId,
                      'requestdate': DateTime.now().toIso8601String(),
                      'fromdate': fromDate!.toIso8601String(),
                      'todate': toDate!.toIso8601String(),
                      'leavetype': leaveTypeCode,
                      'leaveremarks': reasonController.text.trim(),
                      'createdby': widget.currentStaff.username,
                      'createddate': DateTime.now().toIso8601String(),
                      'approval_status': 'P', // P = Pending
                      'source': 'M', // M = Mobile
                    };

                    print('DEBUG: About to insert leave request');
                    print('DEBUG: Leave data = $leaveData');

                    // Insert leave request
                    final response = await supabase.from('learequest').insert(leaveData);

                    print('DEBUG: Insert completed');
                    print('DEBUG: Response = $response');

                    // Close loading dialog
                    if (!context.mounted) return;
                    Navigator.of(context).pop();

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Leave request submitted successfully!\n'
                          'Type: $leaveType\n'
                          'From: ${DateFormat('dd MMM yyyy').format(fromDate!)}\n'
                          'To: ${DateFormat('dd MMM yyyy').format(toDate!)}\n'
                          'Days: $numberOfDays',
                        ),
                        backgroundColor: AppTheme.successColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );

                    // Clear form
                    setFormState(() {
                      leaveType = null;
                      fromDate = null;
                      toDate = null;
                      reasonController.clear();
                    });

                    // Reload leave requests to show the newly created one
                    await _loadLeaveRequests();

                    // Switch to history tab
                    _tabController.animateTo(0);
                  } catch (e) {
                    // Log full error to console
                    print('ERROR inserting leave request: $e');
                    print('ERROR details: ${e.runtimeType}');

                    // Close loading dialog
                    if (!context.mounted) return;
                    Navigator.of(context).pop();

                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating leave request: ${e.toString()}'),
                        backgroundColor: AppTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Submit Leave Request',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.h),
          ],
        );
      },
    );
  }
}
