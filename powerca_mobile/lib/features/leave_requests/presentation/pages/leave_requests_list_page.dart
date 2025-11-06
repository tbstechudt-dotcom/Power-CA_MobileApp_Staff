import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme.dart';
import '../../../../core/config/injection.dart';
import '../../../auth/domain/entities/staff.dart';
import '../bloc/leave_request_bloc.dart';
import '../bloc/leave_request_event.dart';
import '../bloc/leave_request_state.dart';
import '../widgets/leave_request_card.dart';
import '../widgets/leave_balance_card.dart';
import '../widgets/status_filter_chips.dart';
import 'create_leave_request_page.dart';

class LeaveRequestsListPage extends StatelessWidget {
  final Staff currentStaff;

  const LeaveRequestsListPage({
    super.key,
    required this.currentStaff,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<LeaveRequestBloc>()
        ..add(LoadLeaveRequestsEvent(staffId: currentStaff.staffId))
        ..add(LoadLeaveBalanceEvent(currentStaff.staffId)),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Leave Requests'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Leave Balance Card
              BlocBuilder<LeaveRequestBloc, LeaveRequestState>(
                builder: (context, state) {
                  if (state is LeaveRequestLoaded && state.leaveBalance != null) {
                    return LeaveBalanceCard(balance: state.leaveBalance!);
                  }
                  return const SizedBox.shrink();
                },
              ),

              SizedBox(height: AppSpacing.sm.h),

              // Status Filter Chips
              BlocBuilder<LeaveRequestBloc, LeaveRequestState>(
                builder: (context, state) {
                  if (state is LeaveRequestLoaded) {
                    return StatusFilterChips(
                      selectedStatus: state.currentFilter,
                      statusCounts: state.statusCounts,
                      onStatusChanged: (status) {
                        context.read<LeaveRequestBloc>().add(
                              FilterLeaveRequestsByStatusEvent(
                                staffId: currentStaff.staffId,
                                status: status,
                              ),
                            );
                      },
                    );
                  }
                  return SizedBox(height: 48.h);
                },
              ),

              SizedBox(height: AppSpacing.md.h),

              // Leave Requests List
              Expanded(
                child: BlocConsumer<LeaveRequestBloc, LeaveRequestState>(
                  listener: (context, state) {
                    if (state is LeaveRequestError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                    if (state is LeaveRequestCreated) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Leave request submitted successfully'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                      // Reload list
                      context.read<LeaveRequestBloc>().add(
                            LoadLeaveRequestsEvent(
                              staffId: currentStaff.staffId,
                            ),
                          );
                    }
                    if (state is LeaveRequestCancelled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Leave request cancelled'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is LeaveRequestLoading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (state is LeaveRequestError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48.sp,
                              color: AppTheme.errorColor,
                            ),
                            SizedBox(height: AppSpacing.md.h),
                            Text(
                              'Error loading leave requests',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            SizedBox(height: AppSpacing.sm.h),
                            Text(
                              state.message,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: AppSpacing.lg.h),
                            ElevatedButton(
                              onPressed: () {
                                context.read<LeaveRequestBloc>().add(
                                      LoadLeaveRequestsEvent(
                                        staffId: currentStaff.staffId,
                                      ),
                                    );
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (state is LeaveRequestLoaded ||
                        state is LeaveRequestLoadingMore) {
                      final requests = state is LeaveRequestLoaded
                          ? state.requests
                          : (state as LeaveRequestLoadingMore).currentRequests;

                      if (requests.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64.sp,
                                color: AppTheme.textSecondaryColor,
                              ),
                              SizedBox(height: AppSpacing.md.h),
                              Text(
                                'No leave requests found',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              SizedBox(height: AppSpacing.sm.h),
                              Text(
                                'Submit your first leave request',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          context.read<LeaveRequestBloc>().add(
                                RefreshLeaveRequestsEvent(
                                  staffId: currentStaff.staffId,
                                  statusFilter: state is LeaveRequestLoaded
                                      ? state.currentFilter
                                      : null,
                                ),
                              );
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (scrollInfo) {
                            // Load more when reaching bottom
                            if (state is LeaveRequestLoaded &&
                                state.hasMore &&
                                scrollInfo.metrics.pixels >=
                                    scrollInfo.metrics.maxScrollExtent - 200) {
                              context.read<LeaveRequestBloc>().add(
                                    LoadMoreLeaveRequestsEvent(
                                      staffId: currentStaff.staffId,
                                      statusFilter: state.currentFilter,
                                      offset: requests.length,
                                    ),
                                  );
                            }
                            return false;
                          },
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md.w,
                              vertical: AppSpacing.sm.h,
                            ),
                            itemCount: requests.length +
                                (state is LeaveRequestLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == requests.length) {
                                // Loading indicator for pagination
                                return Padding(
                                  padding: EdgeInsets.all(AppSpacing.md.w),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              final request = requests[index];
                              return LeaveRequestCard(
                                request: request,
                                onTap: () {
                                  // TODO: Navigate to details page
                                },
                                onCancel: request.approvalStatus == 'P'
                                    ? () {
                                        _showCancelDialog(
                                          context,
                                          request.leaId!,
                                          currentStaff.staffId,
                                          state is LeaveRequestLoaded
                                              ? state.currentFilter
                                              : null,
                                        );
                                      }
                                    : null,
                              );
                            },
                          ),
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateLeaveRequestPage(
                  currentStaff: currentStaff,
                ),
              ),
            );

            // Reload list if request was created
            if (result == true && context.mounted) {
              context.read<LeaveRequestBloc>().add(
                    LoadLeaveRequestsEvent(
                      staffId: currentStaff.staffId,
                    ),
                  );
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('New Request'),
          backgroundColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    int leaId,
    int staffId,
    String? currentFilter,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Leave Request'),
        content: const Text(
          'Are you sure you want to cancel this leave request? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<LeaveRequestBloc>().add(
                    CancelLeaveRequestEvent(
                      leaId: leaId,
                      staffId: staffId,
                      currentFilter: currentFilter,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
