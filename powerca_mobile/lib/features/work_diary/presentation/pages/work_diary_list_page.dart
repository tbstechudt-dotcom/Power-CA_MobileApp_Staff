import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/injection.dart';
import '../../../../shared/widgets/soft_page.dart';
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
    final p = SoftPalette.of(context);
    return BlocProvider(
      create: (context) => getIt<WorkDiaryBloc>()
        ..add(LoadEntriesEvent(jobId: job.jobId)),
      child: SoftScaffold(
        title: 'Task Entries List',
        subtitle: job.jobName,
        onBack: () => Navigator.pop(context),
        body: BlocConsumer<WorkDiaryBloc, WorkDiaryState>(
          listener: (context, state) {
            if (state is WorkDiaryError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: p.danger,
                ),
              );
            }

            if (state is WorkDiaryEntryAdded) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Entry added successfully'),
                  backgroundColor: p.success,
                ),
              );
            }

            if (state is WorkDiaryEntryDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Entry deleted successfully'),
                  backgroundColor: p.success,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is WorkDiaryLoading) {
              return Center(
                child: CircularProgressIndicator(color: p.ink, strokeWidth: 2.4),
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
                  _buildTotalHoursHeader(p, totalHours),

                  // Entries list
                  Expanded(
                    child: RefreshIndicator(
                      color: p.ink,
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount:
                              entries.length + (state is WorkDiaryLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == entries.length) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: p.ink,
                                    strokeWidth: 2.4,
                                  ),
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
        // Builder gives a context below the BlocProvider above, so
        // context.read<WorkDiaryBloc>() can find the bloc.
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
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
            backgroundColor: p.pill,
            elevation: 2,
            shape: const CircleBorder(),
            child: Icon(
              Icons.add_rounded,
              color: p.onPill,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalHoursHeader(SoftPalette p, double totalHours) {
    final hours = totalHours.floor();
    final minutes = ((totalHours - hours) * 60).round();
    final formattedHours =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} Hrs';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: SoftCard(
        child: Row(
          children: [
            SoftIconBadge(icon: Icons.timer_outlined, color: p.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL HOURS LOGGED', style: SoftText.overline(p)),
                  const SizedBox(height: 4),
                  Text(formattedHours, style: SoftText.title(p, size: 22)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const SoftMessage(
      icon: Icons.event_note_outlined,
      title: 'No entries yet',
      message: 'Tap + to add your first entry',
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, int wdId) async {
    final confirmed = await showSoftConfirmDialog(
      context,
      title: 'Delete Entry',
      message: 'Are you sure you want to delete this entry?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    context.read<WorkDiaryBloc>().add(
          DeleteEntryEvent(wdId: wdId, jobId: job.jobId),
        );
  }
}
