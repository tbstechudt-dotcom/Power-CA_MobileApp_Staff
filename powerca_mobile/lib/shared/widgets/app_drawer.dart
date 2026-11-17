import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/config/injection.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/tab_data_cache.dart';
import '../../features/auth/domain/entities/staff.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/app_update_page.dart';
import '../../features/settings/presentation/pages/help_support_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import 'soft_page.dart';

/// Navy side menu. It opens from the left (Scaffold.drawer), so the
/// right corners are rounded.
class AppDrawer extends StatefulWidget {
  final Staff currentStaff;

  const AppDrawer({
    super.key,
    required this.currentStaff,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _getInitials(String name) {
    // Use letters/digits only, so names like "TEST USER (DUMMY)" give "TU"
    // rather than "T(".
    final parts = name
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  String _getStaffRole(int? staffType) {
    switch (staffType) {
      case 1:
        return 'Administrator';
      case 2:
        return 'Manager';
      case 3:
        return 'Senior Staff';
      case 4:
        return 'Staff Member';
      case 5:
        return 'Junior Staff';
      default:
        return 'Staff Member';
    }
  }

  /// "TEST USER (DUMMY)" -> "Test User (dummy)".
  String _titleCase(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final colors = _DrawerColors.of(p);

    return Drawer(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(p, colors),
            Divider(height: 1, thickness: 1, color: colors.divider),

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(8.w, 16.h, 8.w, 8.h),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 6.h),
                    child: Text(
                      'Menu',
                      style: SoftText.caption(p, size: 12.5)
                          .copyWith(color: colors.muted),
                    ),
                  ),
                  _buildMenuItem(
                    p,
                    colors,
                    icon: Icons.person_outline_rounded,
                    title: 'My profile',
                    onTap: () => _handleMenuTap(context, 'Profile'),
                  ),
                  _buildMenuItem(
                    p,
                    colors,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => _handleMenuTap(context, 'Settings'),
                  ),
                  _buildMenuItem(
                    p,
                    colors,
                    icon: Icons.system_update_outlined,
                    title: 'App update',
                    trailing: 'v${AppUpdateService.currentVersionName}',
                    onTap: () => _handleMenuTap(context, 'AppUpdate'),
                  ),
                  _buildMenuItem(
                    p,
                    colors,
                    icon: Icons.help_outline_rounded,
                    title: 'Help & support',
                    onTap: () => _handleMenuTap(context, 'HelpSupport'),
                  ),
                ],
              ),
            ),

            // Sign out
            Divider(height: 1, thickness: 1, color: colors.divider),
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 12.h),
              child: _buildMenuItem(
                p,
                colors,
                icon: Icons.logout_rounded,
                title: 'Sign out',
                color: colors.danger,
                onTap: () => _handleLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(SoftPalette p, _DrawerColors colors) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 8.w, 16.h),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.avatar,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _getInitials(widget.currentStaff.name),
              style: SoftText.heading(p, size: 16)
                  .copyWith(color: colors.onAvatar),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleCase(widget.currentStaff.name),
                  style: SoftText.heading(p, size: 15.5)
                      .copyWith(color: colors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${_getStaffRole(widget.currentStaff.staffType)} · '
                  'ID ${widget.currentStaff.staffId}',
                  style: SoftText.caption(p, size: 11.5)
                      .copyWith(color: colors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: Icon(Icons.close_rounded, size: 22, color: colors.muted),
            onPressed: () => _closeDrawer(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    SoftPalette p,
    _DrawerColors colors, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? trailing,
    Color? color,
  }) {
    final fg = color ?? colors.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: 21, color: fg),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: SoftText.heading(p, size: 15)
                    .copyWith(color: fg, fontWeight: FontWeight.w500),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: SoftText.caption(p, size: 12)
                    .copyWith(color: colors.muted),
              ),
          ],
        ),
      ),
    );
  }

  /// Closes the drawer through its Scaffold. A bare Navigator.pop can be
  /// swallowed by a page-level PopScope (e.g. the dashboard's), which left
  /// the drawer open behind the pushed page.
  void _closeDrawer(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else if (scaffold != null && scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _handleMenuTap(BuildContext context, String title) {
    final navigator = Navigator.of(context);

    Widget? page;
    if (title == 'Profile') {
      page = ProfilePage(currentStaff: widget.currentStaff);
    } else if (title == 'Settings') {
      page = const SettingsPage();
    } else if (title == 'AppUpdate') {
      page = const AppUpdatePage();
    } else if (title == 'HelpSupport') {
      page = const HelpSupportPage();
    }
    if (page == null) return;

    // The drawer is intentionally left open underneath the new page, so
    // pressing back on that page returns to the open drawer (pick another
    // item, or press back again to close it).
    navigator.push(MaterialPageRoute(builder: (_) => page!));
  }

  void _handleLogout(BuildContext context) {
    // Get navigator before any async operations
    final navigator = Navigator.of(context);

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) {
        final p = SoftPalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: p.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              SoftIconBadge(
                icon: Icons.logout_rounded,
                color: p.danger,
                size: 40,
              ),
              SizedBox(width: 12.w),
              Text('Sign Out', style: SoftText.heading(p, size: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out of your account?',
            style: SoftText.body(p),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: SoftPillButton(
                    label: 'Cancel',
                    variant: SoftPillVariant.outline,
                    height: 46,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SoftPillButton(
                    label: 'Sign Out',
                    variant: SoftPillVariant.danger,
                    height: 46,
                    onPressed: () async {
                      // Close dialog first
                      Navigator.pop(dialogContext);

                      // Drop cached page data so the next user starts clean.
                      TabDataCache.clear();

                      // Clear the saved session
                      try {
                        final authRepository = getIt<AuthRepository>();
                        await authRepository.signOut();
                        debugPrint('Session cleared successfully');
                      } catch (e) {
                        debugPrint('Error clearing session: $e');
                      }

                      // Navigate to splash page and clear ALL navigation stack
                      navigator.pushNamedAndRemoveUntil(
                        '/splash',
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Colors of the drawer panel: deep navy in light mode, the palette's
/// surface in dark mode.
class _DrawerColors {
  final Color background;
  final Color ink;
  final Color muted;
  final Color divider;
  final Color avatar;
  final Color onAvatar;
  final Color danger;

  const _DrawerColors({
    required this.background,
    required this.ink,
    required this.muted,
    required this.divider,
    required this.avatar,
    required this.onAvatar,
    required this.danger,
  });

  factory _DrawerColors.of(SoftPalette p) {
    if (p.isDark) {
      return _DrawerColors(
        background: p.surface,
        ink: p.ink,
        muted: p.muted,
        divider: p.border,
        avatar: p.accent,
        onAvatar: p.background,
        danger: p.danger,
      );
    }
    return _DrawerColors(
      background: p.pill, // deep navy #0B1A30
      ink: p.onPill,
      muted: p.onPill.withValues(alpha: 0.55),
      divider: p.onPill.withValues(alpha: 0.10),
      avatar: p.accent,
      onAvatar: Colors.white,
      // The lighter red reads better on the navy panel.
      danger: SoftPalette.dark.danger,
    );
  }
}
