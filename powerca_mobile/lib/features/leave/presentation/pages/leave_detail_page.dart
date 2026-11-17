import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/widgets/soft_page.dart';

class LeaveDetailPage extends StatelessWidget {
  final Map<String, dynamic> leave;
  final VoidCallback onDeleted;

  const LeaveDetailPage({
    super.key,
    required this.leave,
    required this.onDeleted,
  });

  static Color _statusColor(SoftPalette p, String? status) {
    switch (status) {
      case 'Approved':
        return p.success;
      case 'Rejected':
        return p.danger;
      default:
        return p.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    final fromDate = leave['fromDate'] as DateTime;
    final toDate = leave['toDate'] as DateTime;
    final days = leave['days'] as double;
    final daysDisplay = days == days.toInt() ? days.toInt().toString() : days.toStringAsFixed(1);
    final reason = leave['reason'] as String;
    final status = leave['status'] as String?;
    final statusColor = _statusColor(p, status);

    // Parse half-day information from the original reason stored in database
    String fromDayType = 'Full Day';
    String toDayType = 'Full Day';
    String cleanReason = reason;

    // Check for half-day tags in reason
    if (reason.contains('[First Half]')) {
      fromDayType = 'First Half';
      toDayType = 'First Half';
      cleanReason = reason.replaceAll(RegExp(r'\s*\[First Half\]'), '').trim();
    } else if (reason.contains('[Second Half]')) {
      fromDayType = 'Second Half';
      toDayType = 'Second Half';
      cleanReason = reason.replaceAll(RegExp(r'\s*\[Second Half\]'), '').trim();
    } else if (reason.contains('[Start:') || reason.contains('[End:')) {
      if (reason.contains('[Start: First Half]')) {
        fromDayType = 'First Half';
      } else if (reason.contains('[Start: Second Half]')) {
        fromDayType = 'Second Half';
      }
      if (reason.contains('[End: First Half]')) {
        toDayType = 'First Half';
      } else if (reason.contains('[End: Second Half]')) {
        toDayType = 'Second Half';
      }
      cleanReason = reason
          .replaceAll(RegExp(r'\s*\[Start: (First Half|Second Half)\]'), '')
          .replaceAll(RegExp(r'\s*\[End: (First Half|Second Half)\]'), '')
          .trim();
    }

    final isSingleDay = fromDate.year == toDate.year &&
        fromDate.month == toDate.month &&
        fromDate.day == toDate.day;

    return SoftScaffold(
      title: 'Leave Request',
      subtitle: leave['type'] as String?,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          // Quick Stats Row (Status & Duration)
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: status == 'Approved'
                      ? Icons.check_circle_rounded
                      : status == 'Rejected'
                          ? Icons.cancel_rounded
                          : Icons.schedule_rounded,
                  color: statusColor,
                  label: 'STATUS',
                  value: status ?? '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_outlined,
                  color: p.accent,
                  label: 'DURATION',
                  value: '$daysDisplay ${days == 1 ? 'Day' : 'Days'}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Date Details Card
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(icon: Icons.calendar_today_rounded, title: 'Date Details'),
                const SizedBox(height: 6),
                if (isSingleDay)
                  _DateItem(
                    label: 'Date',
                    date: fromDate,
                    dayType: fromDayType,
                    color: p.accent,
                    showDivider: false,
                  )
                else ...[
                  _DateItem(
                    label: 'From',
                    date: fromDate,
                    dayType: fromDayType,
                    color: p.success,
                    showDivider: true,
                  ),
                  _DateItem(
                    label: 'To',
                    date: toDate,
                    dayType: toDayType,
                    color: p.danger,
                    showDivider: false,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Reason Card
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardHeader(icon: Icons.description_rounded, title: 'Reason'),
                const SizedBox(height: 12),
                Text(
                  cleanReason.isEmpty ? 'No reason provided' : cleanReason,
                  style: SoftText.body(
                    p,
                    color: cleanReason.isEmpty ? p.muted : p.inkSoft,
                  ).copyWith(height: 1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Applied On Card
          SoftCard(
            child: Row(
              children: [
                SoftIconBadge(icon: Icons.access_time_rounded, color: p.muted, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('APPLIED ON', style: SoftText.overline(p)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(leave['appliedDate']),
                        style: SoftText.heading(p, size: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('hh:mm a').format(leave['appliedDate']),
                        style: SoftText.caption(p),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Delete Button (only for pending)
          if (leave['status'] == 'Pending') ...[
            const SizedBox(height: 24),
            SoftPillButton(
              label: 'Delete Request',
              icon: Icons.delete_outline_rounded,
              variant: SoftPillVariant.danger,
              onPressed: () => _showDeleteConfirmation(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showSoftConfirmDialog(
      context,
      title: 'Delete Request?',
      message:
          'Are you sure you want to delete this leave request? This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _deleteLeaveRequest(context);
  }

  Future<void> _deleteLeaveRequest(BuildContext context) async {
    final p = SoftPalette.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: p.accent),
      ),
    );

    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('learequest')
          .delete()
          .eq('learequest_id', leave['id']);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Leave request deleted successfully'),
            ],
          ),
          backgroundColor: p.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      onDeleted();
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting leave request: ${e.toString()}'),
          backgroundColor: p.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// Small stat tile (Status / Duration).
class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SoftIconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SoftText.overline(p)),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SoftText.heading(p, size: 14.5).copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card header: icon badge + title.
class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CardHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Row(
      children: [
        SoftIconBadge(icon: icon, color: p.accent, size: 36),
        const SizedBox(width: 12),
        Text(title, style: SoftText.heading(p)),
      ],
    );
  }
}

/// One date line in the Date Details card.
class _DateItem extends StatelessWidget {
  final String label;
  final DateTime date;
  final String dayType;
  final Color color;
  final bool showDivider;

  const _DateItem({
    required this.label,
    required this.date,
    required this.dayType,
    required this.color,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final isFullDay = dayType == 'Full Day';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.tint(color),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: SoftText.caption(p, size: 11.5)
                      .copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(date),
                      style: SoftText.heading(p, size: 14.5),
                    ),
                    const SizedBox(height: 6),
                    SoftStatusPill(
                      label: dayType,
                      color: isFullDay ? p.muted : color,
                      showDot: !isFullDay,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, thickness: 1, color: p.border, indent: 56),
      ],
    );
  }
}
