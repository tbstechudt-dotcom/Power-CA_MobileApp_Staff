import 'package:flutter/material.dart';

import '../../../../shared/widgets/soft_page.dart';
import '../../domain/entities/work_diary_entry.dart';

class WorkDiaryEntryCard extends StatelessWidget {
  final WorkDiaryEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const WorkDiaryEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date and menu
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: p.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(entry.formattedDate, style: SoftText.caption(p)),
                ),
                // Hours badge
                SoftStatusPill(
                  label: 'Act. Hrs: ${entry.formattedHours}',
                  color: p.accent,
                  icon: Icons.schedule_rounded,
                ),
                const SizedBox(width: 2),
                // Menu button
                IconButton(
                  onPressed: () {
                    _showMenu(context);
                  },
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: p.muted),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Notes/Description
            if (entry.notes != null && entry.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  entry.notes!,
                  style: SoftText.body(p, color: p.ink).copyWith(height: 1.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Task name if available
            if (entry.taskName != null && entry.taskName!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.task_alt_rounded, size: 14, color: p.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.taskName!,
                      style: SoftText.caption(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final p = SoftPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              _menuTile(
                p,
                icon: Icons.edit_outlined,
                label: 'Edit Entry',
                color: p.ink,
                onTap: () {
                  Navigator.pop(context);
                  if (onTap != null) onTap!();
                },
              ),
              _menuTile(
                p,
                icon: Icons.delete_outline_rounded,
                label: 'Delete Entry',
                color: p.danger,
                onTap: () {
                  Navigator.pop(context);
                  if (onDelete != null) onDelete!();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(
    SoftPalette p, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: SoftIconBadge(icon: icon, color: color, size: 38),
      title: Text(label, style: SoftText.heading(p, size: 15).copyWith(color: color)),
      onTap: onTap,
    );
  }
}
