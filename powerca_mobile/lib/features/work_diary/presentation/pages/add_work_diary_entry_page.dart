import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDF3),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD1D9E6),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        leadingWidth: 58.w,
        title: Text(
          isEditing ? 'Edit Entry' : 'Add Entry',
          style: TextStyle(
            fontFamily: 'Inter',
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
            // Job name
            _buildInfoCard(),

            SizedBox(height: 16.h),

            // Date picker
            _buildDatePicker(),

            SizedBox(height: 16.h),

            // Hours input
            _buildHoursInput(),

            SizedBox(height: 16.h),

            // Notes input
            _buildNotesInput(),

            SizedBox(height: 24.h),

            // Save button
            _buildSaveButton(isEditing),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE3EFFF),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Job',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            widget.job.jobName,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            widget.job.clientName ?? 'No Client',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
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
            'Date',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          InkWell(
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
                    _formatDate(_selectedDate),
                    style: TextStyle(
                      fontFamily: 'Inter',
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
      ),
    );
  }

  Widget _buildHoursInput() {
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
            'Actual Hours',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              // Hours
              Expanded(
                child: TextFormField(
                  controller: _hoursController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Hours',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
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
              SizedBox(width: 16.w),
              // Minutes
              Expanded(
                child: TextFormField(
                  controller: _minutesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Minutes',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
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
      ),
    );
  }

  Widget _buildNotesInput() {
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
            'Notes',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Enter details about the work done...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter some notes';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isEditing) {
    return ElevatedButton(
      onPressed: _saveEntry,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: Text(
        isEditing ? 'Update Entry' : 'Save Entry',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
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
