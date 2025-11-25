import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../auth/domain/entities/staff.dart';

class ApplyLeavePage extends StatefulWidget {
  final Staff currentStaff;
  final List<Map<String, dynamic>> existingLeaveRequests;
  final VoidCallback onLeaveCreated;

  const ApplyLeavePage({
    super.key,
    required this.currentStaff,
    required this.existingLeaveRequests,
    required this.onLeaveCreated,
  });

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _leaveType;
  String _fromDayType = 'full';
  String _toDayType = 'full';
  bool _isMultiDay = false;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: _buildLeaveApplicationForm(),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18.sp,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply Leave',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Submit a new leave request',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: _submitLeaveRequest,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.send_rounded,
                  size: 20.sp,
                  color: Colors.white,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Submit Request',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayTypeSelector({
    required String selectedType,
    required Function(String) onChanged,
    required bool enabled,
  }) {
    final options = [
      {'value': 'full', 'label': 'Full Day'},
      {'value': 'first_half', 'label': 'First Half'},
      {'value': 'second_half', 'label': 'Second Half'},
    ];

    return Row(
      children: options.map((option) {
        final isSelected = selectedType == option['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w),
            child: InkWell(
              onTap: enabled ? () => onChanged(option['value']!) : null,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : enabled
                          ? Colors.white
                          : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : const Color(0xFFE9F0F8),
                  ),
                ),
                child: Center(
                  child: Text(
                    option['label']!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : enabled
                              ? const Color(0xFF080E29)
                              : const Color(0xFFA8A8A8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaveApplicationForm() {
    // For single day, toDate is same as fromDate
    DateTime? effectiveToDate = _isMultiDay ? _toDate : _fromDate;

    // Calculate number of days with half-day support
    double? numberOfDays;
    if (_fromDate != null && effectiveToDate != null) {
      if (_fromDate == effectiveToDate) {
        numberOfDays = _fromDayType == 'full' ? 1.0 : 0.5;
      } else {
        int fullDays = effectiveToDate.difference(_fromDate!).inDays - 1;
        if (fullDays < 0) fullDays = 0;
        double firstDayValue = _fromDayType == 'full' ? 1.0 : 0.5;
        double lastDayValue = _toDayType == 'full' ? 1.0 : 0.5;
        numberOfDays = firstDayValue + fullDays + lastDayValue;
      }
    }

    String daysDisplay = numberOfDays != null
        ? (numberOfDays == numberOfDays.toInt()
            ? numberOfDays.toInt().toString()
            : numberOfDays.toStringAsFixed(1))
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leave Type Dropdown
        Text(
          'Leave Type',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF080E29),
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFE9F0F8)),
          ),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              hintText: 'Select leave type',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                color: const Color(0xFFA8A8A8),
              ),
              prefixIcon: const Icon(Icons.category_outlined),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
            value: _leaveType,
            items: ['Sick Leave', 'Casual Leave', 'Earned Leave', 'Emergency Leave']
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(
                        type,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _leaveType = value;
              });
            },
          ),
        ),

        SizedBox(height: 20.h),

        // Leave Duration Toggle
        Text(
          'Leave Duration',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF080E29),
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isMultiDay = false;
                    _toDate = null;
                    _toDayType = 'full';
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: !_isMultiDay ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: !_isMultiDay ? AppTheme.primaryColor : const Color(0xFFE9F0F8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Single Day',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: !_isMultiDay ? Colors.white : const Color(0xFF080E29),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isMultiDay = true;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: _isMultiDay ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: _isMultiDay ? AppTheme.primaryColor : const Color(0xFFE9F0F8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Multiple Days',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: _isMultiDay ? Colors.white : const Color(0xFF080E29),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 20.h),

        // From Date
        Text(
          _isMultiDay ? 'From Date' : 'Date',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF080E29),
          ),
        ),
        SizedBox(height: 8.h),
        _buildDatePicker(
          date: _fromDate,
          hint: 'Select start date',
          onSelect: (date) {
            setState(() {
              _fromDate = date;
              if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
                _toDate = null;
              }
            });
          },
          onClear: () {
            setState(() {
              _fromDate = null;
              _toDate = null;
              _fromDayType = 'full';
              _toDayType = 'full';
            });
          },
        ),

        // From Day Type Selector
        if (_fromDate != null) ...[
          SizedBox(height: 8.h),
          Text(
            _isMultiDay ? 'From Date - Day Type' : 'Day Type',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 4.h),
          _buildDayTypeSelector(
            selectedType: _fromDayType,
            onChanged: (value) {
              setState(() {
                _fromDayType = value;
              });
            },
            enabled: true,
          ),
        ],

        // To Date (only for multi-day)
        if (_isMultiDay) ...[
          SizedBox(height: 20.h),
          Text(
            'To Date',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF080E29),
            ),
          ),
          SizedBox(height: 8.h),
          _buildDatePicker(
            date: _toDate,
            hint: 'Select end date',
            enabled: _fromDate != null,
            minDate: _fromDate,
            onSelect: (date) {
              setState(() {
                _toDate = date;
              });
            },
            onClear: () {
              setState(() {
                _toDate = null;
                _toDayType = 'full';
              });
            },
          ),

          // To Day Type Selector
          if (_fromDate != null && _toDate != null && _fromDate != _toDate) ...[
            SizedBox(height: 8.h),
            Text(
              'To Date - Day Type',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 4.h),
            _buildDayTypeSelector(
              selectedType: _toDayType,
              onChanged: (value) {
                setState(() {
                  _toDayType = value;
                });
              },
              enabled: true,
            ),
          ],
        ],

        // Number of Days Display
        if (numberOfDays != null) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
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
                  'Total: $daysDisplay ${numberOfDays == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
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
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF080E29),
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: const Color(0xFFE9F0F8)),
          ),
          child: TextField(
            controller: _reasonController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter reason for leave...',
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.sp,
                color: const Color(0xFFA8A8A8),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16.w),
            ),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              color: const Color(0xFF080E29),
            ),
          ),
        ),

        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildDatePicker({
    required DateTime? date,
    required String hint,
    required Function(DateTime) onSelect,
    required VoidCallback onClear,
    bool enabled = true,
    DateTime? minDate,
  }) {
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              DateTime initialDate = minDate ?? DateTime.now();
              if (initialDate.weekday == DateTime.sunday) {
                initialDate = initialDate.add(const Duration(days: 1));
              }

              final selectedDate = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: minDate ?? DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                selectableDayPredicate: (DateTime day) {
                  return day.weekday != DateTime.sunday;
                },
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
              if (selectedDate != null) {
                onSelect(selectedDate);
              }
            },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: !enabled ? const Color(0xFFF5F7FA) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFE9F0F8)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20.sp,
              color: !enabled ? const Color(0xFFA8A8A8) : const Color(0xFF8F8E90),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                date != null ? DateFormat('dd MMM yyyy').format(date) : hint,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  color: date != null ? const Color(0xFF080E29) : const Color(0xFFA8A8A8),
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.cancel,
                  size: 20.sp,
                  color: const Color(0xFFA8A8A8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitLeaveRequest() async {
    // Validate form
    if (_leaveType == null) {
      _showError('Please select leave type');
      return;
    }
    if (_fromDate == null) {
      _showError('Please select date');
      return;
    }
    if (_isMultiDay && _toDate == null) {
      _showError('Please select end date');
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      _showError('Please enter reason');
      return;
    }

    final submitToDate = _isMultiDay ? _toDate : _fromDate;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;

      // Map leave type to code
      final leaveTypeCode = {
        'Sick Leave': 'SL',
        'Casual Leave': 'CL',
        'Earned Leave': 'EL',
        'Emergency Leave': 'EM',
      }[_leaveType] ?? 'CL';

      final requestId = DateTime.now().millisecondsSinceEpoch % 100000;

      // Build remarks with half-day info
      String remarks = _reasonController.text.trim();
      if (_fromDayType != 'full' || (submitToDate != _fromDate && _toDayType != 'full')) {
        if (_fromDate == submitToDate) {
          remarks += _fromDayType == 'first_half' ? ' [First Half]' : ' [Second Half]';
        } else {
          if (_fromDayType != 'full') {
            remarks += ' [Start: ${_fromDayType == 'first_half' ? 'First Half' : 'Second Half'}]';
          }
          if (_toDayType != 'full') {
            remarks += ' [End: ${_toDayType == 'first_half' ? 'First Half' : 'Second Half'}]';
          }
        }
      }

      final leaveData = {
        'org_id': widget.currentStaff.orgId,
        'con_id': widget.currentStaff.conId,
        'loc_id': widget.currentStaff.locId,
        'learequest_id': requestId,
        'staff_id': widget.currentStaff.staffId,
        'requestdate': DateTime.now().toIso8601String(),
        'fromdate': _fromDate!.toIso8601String(),
        'todate': submitToDate!.toIso8601String(),
        'leavetype': leaveTypeCode,
        'leaveremarks': remarks,
        'createdby': widget.currentStaff.username,
        'createddate': DateTime.now().toIso8601String(),
        'approval_status': 'P',
        'source': 'M',
      };

      await supabase.from('learequest').insert(leaveData);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Leave request submitted successfully!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onLeaveCreated();
      Navigator.of(context).pop(); // Go back to leave list
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
