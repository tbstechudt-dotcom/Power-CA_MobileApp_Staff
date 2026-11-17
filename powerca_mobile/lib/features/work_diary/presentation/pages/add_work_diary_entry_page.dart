import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/soft_page.dart';
import '../../../../shared/widgets/soft_ui.dart';
import '../../../auth/domain/entities/staff.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/work_diary_entry.dart';
import '../bloc/work_diary_bloc.dart';
import '../bloc/work_diary_event.dart';

class AddWorkDiaryEntryPage extends StatefulWidget {
  final Job job;
  final WorkDiaryEntry? entry; // For editing
  final Staff? currentStaff;

  const AddWorkDiaryEntryPage({
    super.key,
    required this.job,
    this.entry,
    this.currentStaff,
  });

  @override
  State<AddWorkDiaryEntryPage> createState() => _AddWorkDiaryEntryPageState();
}

class _AddWorkDiaryEntryPageState extends State<AddWorkDiaryEntryPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TextEditingController _hoursController;
  late TextEditingController _minutesController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry?.date ?? DateTime.now();

    final hours = widget.entry?.hoursWorked.floor() ?? 0;
    final minutes = widget.entry != null
        ? ((widget.entry!.hoursWorked - hours) * 60).round()
        : 0;

    _hoursController = TextEditingController(text: hours.toString());
    _minutesController = TextEditingController(text: minutes.toString());
    _notesController = TextEditingController(text: widget.entry?.notes ?? '');
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _notesController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return SoftScaffold(
      title: isEditing ? 'Edit Entry' : 'Add Entry',
      onBack: () => Navigator.pop(context),
      bottomBar: _buildSaveButton(isEditing),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // Job name
            _buildInfoCard(),

            const SizedBox(height: 20),

            // Date picker
            _buildDatePicker(),

            const SizedBox(height: 18),

            // Hours input
            _buildHoursInput(),

            const SizedBox(height: 18),

            // Notes input
            _buildNotesInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final p = SoftPalette.of(context);
    return SoftCard(
      child: Row(
        children: [
          SoftIconBadge(icon: Icons.work_outline_rounded, color: p.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('JOB', style: SoftText.overline(p)),
                const SizedBox(height: 4),
                Text(widget.job.jobName, style: SoftText.heading(p, size: 15)),
                const SizedBox(height: 4),
                Text(
                  widget.job.clientName ?? 'No Client',
                  style: SoftText.body(p, size: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SoftFieldLabel('Date'),
        SoftPickerField(
          value: _formatDate(_selectedDate),
          placeholder: 'Select date',
          icon: Icons.calendar_today_rounded,
          onTap: () async {
            // Get current date at midnight (00:00:00) for firstDate
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            final pickedDate = await showDatePicker(
              context: context,
              initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
              firstDate: today, // Only allow current date and future dates
              lastDate: DateTime(2030),
            );
            if (pickedDate != null) {
              setState(() {
                _selectedDate = pickedDate;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildHoursInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SoftFieldLabel('Actual Hours'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hours
            Expanded(
              child: TextFormField(
                controller: _hoursController,
                keyboardType: TextInputType.number,
                style: softInputTextStyle(context),
                decoration: softInputDecoration(
                  context,
                  hint: 'Hours',
                  icon: Icons.schedule_rounded,
                ).copyWith(suffixText: 'hrs'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final hours = int.tryParse(value);
                  if (hours == null || hours < 0) {
                    return 'Invalid';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            // Minutes
            Expanded(
              child: TextFormField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                style: softInputTextStyle(context),
                decoration: softInputDecoration(
                  context,
                  hint: 'Minutes',
                  icon: Icons.timer_outlined,
                ).copyWith(suffixText: 'min'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final minutes = int.tryParse(value);
                  if (minutes == null || minutes < 0 || minutes >= 60) {
                    return 'Invalid';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SoftFieldLabel('Notes'),
        TextFormField(
          controller: _notesController,
          maxLines: 5,
          style: softInputTextStyle(context),
          decoration: softInputDecoration(
            context,
            hint: 'Enter details about the work done...',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter some notes';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return SoftPillButton(
      label: isEditing ? 'Update Entry' : 'Save Entry',
      icon: Icons.check_rounded,
      onPressed: _saveEntry,
    );
  }

  void _saveEntry() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final hours = int.parse(_hoursController.text);
    final minutes = int.parse(_minutesController.text);
    final totalHours = hours + (minutes / 60.0);

    final entry = WorkDiaryEntry(
      wdId: widget.entry?.wdId,
      jobId: widget.job.jobId,
      jobReference: widget.job.jobReference,
      staffId: widget.currentStaff?.staffId ?? 1, // TODO: Get from auth
      date: _selectedDate,
      hoursWorked: totalHours,
      notes: _notesController.text,
      createdAt: widget.entry?.createdAt,
      updatedAt: DateTime.now(),
    );

    if (widget.entry != null) {
      context.read<WorkDiaryBloc>().add(UpdateEntryEvent(entry));
    } else {
      context.read<WorkDiaryBloc>().add(AddEntryEvent(entry));
    }

    Navigator.pop(context);
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
