import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
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
    final p = SoftPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: HomeBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SoftIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    size: 44,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Eyebrow + headline
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 0, 4, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HomeEyebrow('Apply leave'),
                            HomeInlineHeadline(
                              size: 23,
                              parts: [
                                (text: 'Request', strong: false),
                                (text: ' time off', strong: true),
                                (text: ' in a', strong: false),
                                (text: ' few steps.', strong: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildLeaveApplicationForm(context),
                    ],
                  ),
                ),
              ),
              // Submit
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: SoftPillButton(
                  label: 'Submit request',
                  icon: Icons.send_rounded,
                  variant: SoftPillVariant.blue,
                  height: 54,
                  loading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitLeaveRequest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// White section card with a title and caption.
  Widget _section({required String title, required String subtitle, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: HomeSectionCard(
        title: title,
        subtitle: subtitle,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          title: 'Leave details',
          subtitle: 'Type and duration',
          children: [
            // Leave Type Dropdown
            const SoftFieldLabel('Leave type', required: true),
            _buildLeaveTypeDropdown(context),
            const SizedBox(height: 18),

            // Leave Duration Toggle
            const SoftFieldLabel('Leave duration'),
            _buildDurationToggle(context),
          ],
        ),
        _section(
          title: 'Dates',
          subtitle: 'Sundays are not counted',
          children: [
        // From Date
        SoftFieldLabel(_isMultiDay ? 'From date' : 'Date', required: true),
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
          const SizedBox(height: 12),
          SoftFieldLabel(_isMultiDay ? 'From date – day type' : 'Day type'),
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
          const SizedBox(height: 18),
          const SoftFieldLabel('To date', required: true),
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
            const SizedBox(height: 12),
            const SoftFieldLabel('To date – day type'),
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
          const SizedBox(height: 16),
          _buildDaysDisplay(context, numberOfDays, daysDisplay),
        ],
          ],
        ),
        _section(
          title: 'Reason',
          subtitle: 'Shared with your office',
          children: [
            _buildReasonField(context),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaveTypeDropdown(BuildContext context) {
    final p = SoftPalette.of(context);
    final textStyle = softInputTextStyle(context);

    return DropdownButtonFormField<String>(
      dropdownColor: p.surface,
      borderRadius: BorderRadius.circular(16),
      decoration: softInputDecoration(
        context,
        hint: 'Select leave type',
        icon: Icons.category_outlined,
        filled: true,
      ),
      value: _leaveType,
      icon: Icon(Icons.expand_more_rounded, color: p.muted),
      style: textStyle,
      items: ['Sick Leave', 'Casual Leave', 'Earned Leave', 'Emergency Leave']
          .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type, style: textStyle),
              ),)
          .toList(),
      onChanged: (value) {
        setState(() {
          _leaveType = value;
        });
      },
    );
  }

  /// Grey rounded track holding a row of [_SegmentButton]s.
  Widget _segmentTrack(List<Widget> segments) {
    final p = SoftPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: softFieldFill(p),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(children: segments),
    );
  }

  Widget _buildDurationToggle(BuildContext context) {
    return _segmentTrack(
      [
        Expanded(
          child: _SegmentButton(
            label: 'Single day',
            selected: !_isMultiDay,
            onTap: () {
              setState(() {
                _isMultiDay = false;
                _toDate = null;
                _toDayType = 'full';
              });
            },
          ),
        ),
        Expanded(
          child: _SegmentButton(
            label: 'Multiple days',
            selected: _isMultiDay,
            onTap: () {
              setState(() {
                _isMultiDay = true;
              });
            },
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
    return _DateField(
      value: date != null ? DateFormat('EEEE, MMMM d, yyyy').format(date) : null,
      placeholder: hint,
      enabled: enabled,
      onClear: date != null ? onClear : null,
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
              );
              if (selectedDate != null) {
                onSelect(selectedDate);
              }
            },
    );
  }

  Widget _buildDayTypeSelector({
    required BuildContext context,
    required String selectedType,
    required Function(String) onChanged,
    required bool enabled,
  }) {
    final options = [
      {'value': 'full', 'label': 'Full Day'},
      {'value': 'first_half', 'label': 'First Half'},
      {'value': 'second_half', 'label': 'Second Half'},
    ];

    return _segmentTrack(
      [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: _SegmentButton(
              label: options[i]['label']!,
              selected: selectedType == options[i]['value'],
              compact: true,
              onTap: enabled ? () => onChanged(options[i]['value']!) : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDaysDisplay(BuildContext context, double numberOfDays, String daysDisplay) {
    final p = SoftPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.tint(p.success),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, size: 18, color: p.success),
          const SizedBox(width: 8),
          Text(
            'Total: $daysDisplay ${numberOfDays == 1 ? 'day' : 'days'}',
            style: SoftText.heading(p, size: 13.5).copyWith(color: p.success),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonField(BuildContext context) {
    return TextFormField(
      controller: _reasonController,
      maxLines: 5,
      style: softInputTextStyle(context),
      decoration: softInputDecoration(context, hint: 'Enter reason for leave...', filled: true),
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

/// Stadium segment used for the duration and day-type toggles.
class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final enabled = onTap != null;
    final activeBg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
    final activeFg = p.isDark ? p.background : Colors.white;
    return Material(
      color: selected ? activeBg : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 13, horizontal: 6),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SoftText.heading(p, size: compact ? 12.5 : 14).copyWith(
                color: selected ? activeFg : (enabled ? p.inkSoft : p.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Date trigger that looks like a soft input, with a clear button.
class _DateField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final empty = value == null;
    return Material(
      color: enabled ? softFieldFill(p) : softFieldFill(p).withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 20, color: p.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  empty ? placeholder : value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: empty
                      ? SoftText.body(p, color: p.muted)
                      : softInputTextStyle(context),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.cancel_rounded, size: 20, color: p.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
