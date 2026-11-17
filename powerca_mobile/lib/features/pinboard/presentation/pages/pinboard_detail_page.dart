import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../auth/domain/entities/staff.dart';

class PinboardDetailPage extends StatelessWidget {
  final Staff currentStaff;
  final Map<String, dynamic> reminder;

  const PinboardDetailPage({
    super.key,
    required this.currentStaff,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    final dateFormat = DateFormat('dd MMM yyyy');
    final remdate = reminder['remdate'] as DateTime?;
    final remduedate = reminder['remduedate'] as DateTime?;
    final remtime = reminder['remtime'] as String;
    final notes = reminder['remnotes'] as String;

    return SoftScaffold(
      title: 'Reminder Details',
      onBack: () => Navigator.pop(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Details Card
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SoftIconBadge(icon: Icons.push_pin_outlined, color: p.accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TITLE', style: SoftText.overline(p)),
                            const SizedBox(height: 4),
                            Text(
                              reminder['remtitle'] as String,
                              style: SoftText.title(p, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 24, color: p.border),
                  SoftInfoRow(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: reminder['remtype'] as String,
                  ),
                  SoftInfoRow(
                    icon: Icons.business_outlined,
                    label: 'Client',
                    value: reminder['clientName'] as String,
                  ),
                  if (remdate != null)
                    SoftInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created Date',
                      value: dateFormat.format(remdate),
                    ),
                  if (remduedate != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.event_outlined, size: 18, color: p.muted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Due Date', style: SoftText.caption(p, size: 13)),
                          ),
                          SoftStatusPill(
                            label: dateFormat.format(remduedate),
                            color: p.danger,
                          ),
                        ],
                      ),
                    ),
                  if (remtime.isNotEmpty)
                    SoftInfoRow(
                      icon: Icons.access_time_outlined,
                      label: 'Time',
                      value: remtime,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes Card
            SizedBox(
              width: double.infinity,
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes_outlined, size: 18, color: p.muted),
                        const SizedBox(width: 8),
                        Text('NOTES', style: SoftText.overline(p)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      notes,
                      style: SoftText.body(p, color: p.ink).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
