import 'package:flutter/material.dart';

import 'soft_page.dart';

/// Error Widget
/// Shows error state with retry option
class CustomErrorWidget extends StatelessWidget {
  final String message;
  final String? description;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const CustomErrorWidget({
    super.key,
    required this.message,
    this.description,
    this.onRetry,
    this.retryLabel,
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
            // Error icon
            SoftIconBadge(
              icon: Icons.error_outline_rounded,
              color: p.danger,
              size: 64,
            ),

            const SizedBox(height: 18),

            // Error message
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

            // Retry button
            if (onRetry != null) ...[
              const SizedBox(height: 22),
              SoftPillButton(
                label: retryLabel ?? 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
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
