import 'package:flutter/material.dart';

import '../../../../shared/widgets/soft_page.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback onEditPressed;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.role,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: p.background,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          // Name and Role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: SoftText.title(p, size: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(role, style: SoftText.caption(p, size: 13.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Edit Button
          SoftPillButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            variant: SoftPillVariant.outline,
            expand: false,
            height: 40,
            onPressed: onEditPressed,
          ),
        ],
      ),
    );
  }
}
