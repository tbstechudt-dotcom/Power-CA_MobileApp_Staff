import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../domain/entities/pinboard_item.dart';
import '../bloc/pinboard_bloc.dart';
import '../bloc/pinboard_event.dart';

class EventDetailsTab extends StatelessWidget {
  final PinboardItem item;

  const EventDetailsTab({
    super.key,
    required this.item,
  });

  Color _getCategoryColor(SoftPalette p) {
    switch (item.category) {
      case PinboardCategory.dueDate:
        return p.warning;
      case PinboardCategory.meetings:
        return p.accent;
      case PinboardCategory.greetings:
        return p.success;
    }
  }

  String _getCategoryName() {
    switch (item.category) {
      case PinboardCategory.dueDate:
        return 'Due Date';
      case PinboardCategory.meetings:
        return 'Meeting';
      case PinboardCategory.greetings:
        return 'Greeting';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final categoryColor = _getCategoryColor(p);
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final createdFormat = DateFormat('MMM dd, yyyy - hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Badge
          SoftStatusPill(label: _getCategoryName(), color: categoryColor),

          const SizedBox(height: 14),

          // Title
          Text(item.title, style: SoftText.title(p, size: 24)),

          const SizedBox(height: 16),

          // Author and Like Button
          SoftCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: p.tint(categoryColor),
                  child: Icon(Icons.person_rounded, size: 18, color: categoryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.authorName, style: SoftText.heading(p, size: 15)),
                      const SizedBox(height: 2),
                      Text(
                        'Posted on ${createdFormat.format(item.createdAt)}',
                        style: SoftText.caption(p),
                      ),
                    ],
                  ),
                ),
                // Like Button
                Material(
                  color: item.isLikedByCurrentUser ? p.tint(p.danger) : p.surfaceAlt,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () {
                      context.read<PinboardBloc>().add(
                            ToggleLikeEvent(item.id),
                          );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isLikedByCurrentUser
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: item.isLikedByCurrentUser ? p.danger : p.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.likesCount}',
                            style: SoftText.caption(p, size: 13).copyWith(
                              color: p.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Event Date and Time / Location
          SoftCard(
            child: Column(
              children: [
                _detailRow(
                  p,
                  icon: Icons.access_time_rounded,
                  color: categoryColor,
                  label: 'DATE & TIME',
                  value: dateFormat.format(item.eventDate),
                  secondary: timeFormat.format(item.eventDate),
                ),
                if (item.location != null) ...[
                  Divider(height: 28, color: p.border),
                  _detailRow(
                    p,
                    icon: Icons.location_on_outlined,
                    color: categoryColor,
                    label: 'LOCATION',
                    value: item.location!,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Description
          const SoftSectionTitle(title: 'Description'),
          Text(
            item.description,
            style: SoftText.body(p, size: 15).copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    SoftPalette p, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    String? secondary,
  }) {
    return Row(
      children: [
        SoftIconBadge(icon: icon, color: color, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SoftText.overline(p)),
              const SizedBox(height: 4),
              Text(value, style: SoftText.heading(p, size: 15)),
              if (secondary != null) ...[
                const SizedBox(height: 2),
                Text(secondary, style: SoftText.body(p, size: 13)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
