import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../domain/entities/job.dart';
import '../bloc/work_diary_bloc.dart';
import '../bloc/work_diary_event.dart';
import '../bloc/work_diary_state.dart';
import '../widgets/work_diary_entry_card.dart';
import 'add_work_diary_entry_page.dart';

class WorkDiaryListPage extends StatelessWidget {
  final Job job;

  const WorkDiaryListPage({
    super.key,
    required this.job,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<WorkDiaryBloc>()
        ..add(LoadEntriesEvent(jobId: job.jobId)),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context),
        body: BlocConsumer<WorkDiaryBloc, WorkDiaryState>(
          listener: (context, state) {
            if (state is WorkDiaryError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }

            if (state is WorkDiaryEntryAdded) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entry added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }

            if (state is WorkDiaryEntryDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Entry deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is WorkDiaryLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is WorkDiaryLoaded || state is WorkDiaryLoadingMore) {
              final entries = state is WorkDiaryLoaded
                  ? state.entries
                  : (state as WorkDiaryLoadingMore).currentEntries;

              final totalHours = state is WorkDiaryLoaded
                  ? state.totalHours
                  : (state as WorkDiaryLoadingMore).totalHours;

              if (entries.isEmpty) {
                return _buildEmptyState();
              }

              return Column(
                children: [
                  // Total hours header
                  _buildTotalHoursHeader(totalHours),

                  // Entries list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        context.read<WorkDiaryBloc>().add(
                              RefreshEntriesEvent(jobId: job.jobId),
                            );
                      },
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (scrollInfo) {
                          if (state is WorkDiaryLoaded &&
                              state.hasMore &&
                              scrollInfo.metrics.pixels >=
                                  scrollInfo.metrics.maxScrollExtent - 200) {
                            context.read<WorkDiaryBloc>().add(
                                  LoadMoreEntriesEvent(
                                    jobId: job.jobId,
                                    offset: entries.length,
                                  ),
                                );
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          itemCount:
                              entries.length + (state is WorkDiaryLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == entries.length) {
                              return Padding(
                                padding: EdgeInsets.all(16.w),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final entry = entries[index];
                            return WorkDiaryEntryCard(
                              entry: entry,
                              onTap: () {
                                // TODO: Navigate to edit entry
                              },
                              onDelete: () {
                                _showDeleteConfirmation(context, entry.wdId!);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<WorkDiaryBloc>(),
                  child: AddWorkDiaryEntryPage(job: job),
                ),
              ),
            );
          },
          backgroundColor: AppTheme.primaryColor,
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 28.sp,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Entries List',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          Text(
            job.jobName,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1.5,
          color: const Color(0xFFE9F0F8),
        ),
      ),
    );
  }

  Widget _buildTotalHoursHeader(double totalHours) {
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();
    final formattedHours =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} Hrs';

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE3EFFF),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Hours Logged',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          Text(
            formattedHours,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64.sp,
            color: AppTheme.textSecondaryColor,
          ),
          SizedBox(height: 16.h),
          Text(
            'No entries yet',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Tap + to add your first entry',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int wdId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<WorkDiaryBloc>().add(
                    DeleteEntryEvent(wdId: wdId, jobId: job.jobId),
                  );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
