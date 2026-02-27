import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../core/providers/theme_provider.dart';
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
  bool _isSubmitting = false;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Count working days between two dates (excluding Sundays)
  /// Sunday is always a holiday and should not be counted as leave
  int _countWorkingDays(DateTime fromDate, DateTime toDate) {
    int count = 0;
    DateTime current = fromDate;
    while (!current.isAfter(toDate)) {
      // Skip Sundays (weekday 7 in Dart)
      if (current.weekday != DateTime.sunday) {
        count += 1;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final scaffoldBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC);
    final headerBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: Center(
            child: _buildBackButton(context),
          ),
        ),
        leadingWidth: 58.w,
        title: _buildAppBarTitle(context),
        backgroundColor: headerBgColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.w,
                bottom: 20.w + MediaQuery.of(context).padding.bottom,
              ),
              child: _buildLeaveApplicationForm(context),
            ),
          ),
          _buildSubmitButton(context),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final backButtonBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backButtonBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textSecondaryColor;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 42.w,
        height: 42.h,
        decoration: BoxDecoration(
          color: backButtonBgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: backButtonBorderColor,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new,
            size: 18.sp,
            color: textSecondaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final textPrimaryColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29);
    final textSecondaryColor = isDarkMode ? const Color(0xFF94A3B8) : AppTheme.textSecondaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Apply Leave',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: textPrimaryColor,
          ),
        ),
        Text(
          'Submit a new leave request',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29),
      ),
    );
  }

  Widget _buildLeaveApplicationForm(BuildContext context) {
    // For single day, toDate is same as fromDate
    DateTime? effectiveToDate = _isMultiDay ? _toDate : _fromDate;

    // Calculate number of days with half-day support (excluding Sundays)
    double? numberOfDays;
    if (_fromDate != null && effectiveToDate != null) {
      if (_fromDate == effectiveToDate) {
        numberOfDays = _fromDayType == 'full' ? 1.0 : 0.5;
      } else {
        int totalWorkingDays = _countWorkingDays(_fromDate!, effectiveToDate);
        double adjustment = 0.0;
        if (_fromDayType != 'full') {
          adjustment -= 0.5;
        }
        if (_toDayType != 'full') {
          adjustment -= 0.5;
        }
        numberOfDays = totalWorkingDays + adjustment;
        if (numberOfDays < 0) numberOfDays = 0;
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
        _buildSectionTitle('Leave Type'),
        SizedBox(height: 8.h),
        _buildLeaveTypeDropdown(context),
        SizedBox(height: 20.h),

        // Leave Duration Toggle
        _buildSectionTitle('Leave Duration'),
        SizedBox(height: 8.h),
        _buildDurationToggle(context),
        SizedBox(height: 20.h),

        // From Date
        _buildSectionTitle(_isMultiDay ? 'From Date' : 'Date'),
        SizedBox(height: 8.h),
        _buildDateSelector(
          context: context,
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
          SizedBox(height: 12.h),
          _buildDayTypeLabel(_isMultiDay ? 'From Date - Day Type' : 'Day Type'),
          SizedBox(height: 6.h),
          _buildDayTypeSelector(
            context: context,
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
          _buildSectionTitle('To Date'),
          SizedBox(height: 8.h),
          _buildDateSelector(
            context: context,
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
            SizedBox(height: 12.h),
            _buildDayTypeLabel('To Date - Day Type'),
            SizedBox(height: 6.h),
            _buildDayTypeSelector(
              context: context,
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
          SizedBox(height: 16.h),
          _buildDaysDisplay(context, numberOfDays, daysDisplay),
        ],

        SizedBox(height: 20.h),

        // Reason
        _buildSectionTitle('Reason'),
        SizedBox(height: 8.h),
        _buildReasonField(context),

        SizedBox(height: 32.h),
      ],
    );
  }

  Widget _buildLeaveTypeDropdown(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final fieldBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final fieldBorderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE9F0F8);
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29);
    final hintColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFA8A8A8);
    final iconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF8F8E90);
    final dropdownBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: fieldBgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: fieldBorderColor),
      ),
      child: DropdownButtonFormField<String>(
        dropdownColor: dropdownBgColor,
        decoration: InputDecoration(
          hintText: 'Select leave type',
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            color: hintColor,
          ),
          prefixIcon: Icon(Icons.category_outlined, color: iconColor),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        ),
        value: _leaveType,
        icon: Icon(Icons.arrow_drop_down, color: iconColor),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.sp,
          color: textColor,
        ),
        items: ['Sick Leave', 'Casual Leave', 'Earned Leave', 'Emergency Leave']
            .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(
                    type,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.sp,
                      color: textColor,
                    ),
                  ),
                ),)
            .toList(),
        onChanged: (value) {
          setState(() {
            _leaveType = value;
          });
        },
      ),
    );
  }

  Widget _buildDurationToggle(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final fieldBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final fieldBorderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE9F0F8);
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29);

    return Row(
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
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: !_isMultiDay ? AppTheme.primaryColor : fieldBgColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: !_isMultiDay ? AppTheme.primaryColor : fieldBorderColor,
                ),
              ),
              child: Center(
                child: Text(
                  'Single Day',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: !_isMultiDay ? Colors.white : textColor,
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
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                color: _isMultiDay ? AppTheme.primaryColor : fieldBgColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _isMultiDay ? AppTheme.primaryColor : fieldBorderColor,
                ),
              ),
              child: Center(
                child: Text(
                  'Multiple Days',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _isMultiDay ? Colors.white : textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector({
    required BuildContext context,
    required DateTime? date,
    required String hint,
    required Function(DateTime) onSelect,
    required VoidCallback onClear,
    bool enabled = true,
    DateTime? minDate,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final fieldBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final disabledBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final fieldBorderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE9F0F8);
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29);
    final hintColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFA8A8A8);

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
                      colorScheme: ColorScheme.light(
                        primary: AppTheme.primaryColor,
                        surface: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
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
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: enabled ? fieldBgColor : disabledBgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: fieldBorderColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20.sp,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                date != null ? DateFormat('EEEE, MMMM d, yyyy').format(date) : hint,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: date != null ? textColor : hintColor,
                ),
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.cancel,
                  size: 20.sp,
                  color: hintColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTypeLabel(String text) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
      ),
    );
  }

  Widget _buildDayTypeSelector({
    required BuildContext context,
    required String selectedType,
    required Function(String) onChanged,
    required bool enabled,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final fieldBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final disabledBgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final fieldBorderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE9F0F8);
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29);
    final disabledTextColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFA8A8A8);

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
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: InkWell(
              onTap: enabled ? () => onChanged(option['value']!) : null,
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : enabled
                          ? fieldBgColor
                          : disabledBgColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : fieldBorderColor,
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
                              ? textColor
                              : disabledTextColor,
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

  Widget _buildDaysDisplay(BuildContext context, double numberOfDays, String daysDisplay) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF064E3B) : AppTheme.successColor.withValues(alpha: 0.1);
    final textColor = isDarkMode ? const Color(0xFF34D399) : AppTheme.successColor;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available,
            size: 18.sp,
            color: textColor,
          ),
          SizedBox(width: 8.w),
          Text(
            'Total: $daysDisplay ${numberOfDays == 1 ? 'day' : 'days'}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonField(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final fieldBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final fieldBorderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE9F0F8);
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF080E29);
    final hintColor = isDarkMode ? const Color(0xFF64748B) : const Color(0xFFA8A8A8);

    return Container(
      decoration: BoxDecoration(
        color: fieldBgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: fieldBorderColor),
      ),
      child: TextFormField(
        controller: _reasonController,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Enter reason for leave...',
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: hintColor,
          ),
          filled: true,
          fillColor: fieldBgColor,
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
        ),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bottomBgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: bottomBgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50.h,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitLeaveRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
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
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
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

    setState(() => _isSubmitting = true);

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

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request submitted successfully!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onLeaveCreated();
      Navigator.of(context).pop(); // Go back to leave list
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
