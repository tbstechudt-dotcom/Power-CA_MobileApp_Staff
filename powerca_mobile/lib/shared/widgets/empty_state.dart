import 'package:flutter/material.dart';

import 'soft_page.dart';

/// Empty State Widget
/// Shows when there's no data to display
class EmptyState extends StatelessWidget {
  final String message;
  final String? description;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? customIcon;

  const EmptyState({
    super.key,
    required this.message,
    this.description,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon or custom widget
            if (customIcon != null)
              customIcon!
            else
              SoftIconBadge(
                icon: icon ?? Icons.inbox_outlined,
                color: p.muted,
                size: 64,
              ),

            const SizedBox(height: 18),

            // Main message
            Text(
              message,
              textAlign: TextAlign.center,
              style: SoftText.heading(p, size: 17),
            ),

            // Description
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: SoftText.body(p),
              ),
            ],

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              SoftPillButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
