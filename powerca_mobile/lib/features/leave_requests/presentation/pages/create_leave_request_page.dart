import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../domain/entities/leave_request.dart';
import '../bloc/leave_request_bloc.dart';
import '../bloc/leave_request_event.dart';
import '../bloc/leave_request_state.dart';

class CreateLeaveRequestPage extends StatefulWidget {
  final Staff? currentStaff;

  const CreateLeaveRequestPage({
    super.key,
    this.currentStaff,
  });

  @override
  State<CreateLeaveRequestPage> createState() => _CreateLeaveRequestPageState();
}

class _CreateLeaveRequestPageState extends State<CreateLeaveRequestPage> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  String _selectedLeaveType = 'AL'; // Default to Annual Leave
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String? _firstHalfValue; // null, 'AM', or 'PM'
  String? _secondHalfValue; // null, 'AM', or 'PM'
  late TextEditingController _remarksController;

  // Leave type options
  final Map<String, String> _leaveTypes = {
    'AL': 'Annual Leave',
    'SL': 'Sick Leave',
    'CL': 'Casual Leave',
    'ML': 'Maternity Leave',
    'PL': 'Paternity Leave',
    'UL': 'Unpaid Leave',
  };

  // Half-day options
  final List<String?> _halfDayOptions = [null, 'AM', 'PM'];

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LeaveRequestBloc, LeaveRequestState>(
      listener: (context, state) {
        if (state is LeaveRequestCreated) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave request submitted successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          // Go back to list page
          Navigator.pop(context, true);
        } else if (state is LeaveRequestError) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back,
              color: AppTheme.textPrimaryColor,
              size: 24.sp,
            ),
          ),
          title: Text(
            'New Leave Request',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1.5,
              color: const Color(0xFFE9F0F8),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              // Leave type dropdown
              _buildLeaveTypeDropdown(),

              SizedBox(height: 16.h),

              // Date range
              _buildDateRange(),

              SizedBox(height: 16.h),

              // Half-day options
              _buildHalfDayOptions(),

              SizedBox(height: 16.h),

              // Remarks input
              _buildRemarksInput(),

              SizedBox(height: 24.h),

              // Submit button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveTypeDropdown() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE9F0F8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave Type',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          DropdownButtonFormField<String>(
            initialValue: _selectedLeaveType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: const BorderSide(color: Color(0xFFE9F0F8)),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 12.h,
              ),
            ),
            items: _leaveTypes.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedLeaveType = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateRange() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE9F0F8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave Period',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 12.h),

          // From date
          _buildDatePicker(
            label: 'From Date',
            selectedDate: _fromDate,
            onDateSelected: (date) {
              setState(() {
                _fromDate = date;
                // If to date is before from date, update it
                if (_toDate.isBefore(_fromDate)) {
                  _toDate = _fromDate;
                }
              });
            },
          ),

          SizedBox(height: 12.h),

          // To date
          _buildDatePicker(
            label: 'To Date',
            selectedDate: _toDate,
            onDateSelected: (date) {
              setState(() {
                _toDate = date;
              });
            },
            firstDate: _fromDate, // Can't select before from date
          ),

          SizedBox(height: 12.h),

          // Show calculated days
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFE3EFFF),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16.sp,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Total: ${_calculateTotalDays()} days',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime selectedDate,
    required Function(DateTime) onDateSelected,
    DateTime? firstDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        SizedBox(height: 6.h),
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: firstDate ?? DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (pickedDate != null) {
              onDateSelected(pickedDate);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFE9F0F8),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(selectedDate),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 20.sp,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHalfDayOptions() {
    final isSingleDay = _fromDate.isAtSameMomentAs(_toDate) ||
        _fromDate.difference(_toDate).inDays == 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE9F0F8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Half-Day Options',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // First half (first day)
          Row(
            children: [
              Expanded(
                child: Text(
                  'First Day',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _firstHalfValue,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                  ),
                  items: _halfDayOptions.map((value) {
                    return DropdownMenuItem<String?>(
                      value: value,
                      child: Text(
                        value ?? 'Full Day',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _firstHalfValue = value;
                    });
                  },
                ),
              ),
            ],
          ),

          if (!isSingleDay) ...[
            SizedBox(height: 12.h),

            // Second half (last day)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Last Day',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _secondHalfValue,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                    ),
                    items: _halfDayOptions.map((value) {
                      return DropdownMenuItem<String?>(
                        value: value,
                        child: Text(
                          value ?? 'Full Day',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _secondHalfValue = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemarksInput() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE9F0F8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remarks',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            controller: _remarksController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add any additional information (optional)...',
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.sp,
                color: AppTheme.textSecondaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              contentPadding: EdgeInsets.all(12.w),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<LeaveRequestBloc, LeaveRequestState>(
      builder: (context, state) {
        final isLoading = state is LeaveRequestCreating;

        return ElevatedButton(
          onPressed: isLoading ? null : _submitRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 20.h,
                  width: 20.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Submit Request',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        );
      },
    );
  }

  void _submitRequest() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate date range
    if (_toDate.isBefore(_fromDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Create leave request entity
    final leaveRequest = LeaveRequest(
      orgId: widget.currentStaff?.orgId ?? 1, // TODO: Get from auth
      conId: widget.currentStaff?.conId ?? 1, // TODO: Get from auth
      locId: widget.currentStaff?.locId ?? 1, // TODO: Get from auth
      staffId: widget.currentStaff?.staffId ?? 1, // TODO: Get from auth
      requestDate: DateTime.now(),
      fromDate: _fromDate,
      toDate: _toDate,
      firstHalfValue: _firstHalfValue,
      secondHalfValue: _secondHalfValue,
      leaveType: _selectedLeaveType,
      leaveRemarks: _remarksController.text.isEmpty
          ? null
          : _remarksController.text,
      approvalStatus: 'P', // Pending by default
    );

    // Dispatch create event
    context.read<LeaveRequestBloc>().add(CreateLeaveRequestEvent(leaveRequest));
  }

  double _calculateTotalDays() {
    final daysDiff = _toDate.difference(_fromDate).inDays + 1;
    double adjustment = 0;

    if (_firstHalfValue != null && _firstHalfValue!.isNotEmpty) {
      adjustment -= 0.5;
    }
    if (_secondHalfValue != null && _secondHalfValue!.isNotEmpty) {
      adjustment -= 0.5;
    }

    return daysDiff + adjustment;
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
