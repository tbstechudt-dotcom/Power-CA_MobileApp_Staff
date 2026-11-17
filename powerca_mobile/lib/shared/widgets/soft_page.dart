import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Soft UI page kit.
///
/// Every restyled screen builds on these pieces so the app reads as one
/// system: [SoftPalette] for colors (light + dark), [SoftScaffold] /
/// [SoftPageHeader] for page chrome, [SoftCard] for surfaces, and
/// [SoftPillButton] / [SoftStatusPill] for actions and status.
@immutable
class SoftPalette {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color pill;
  final Color onPill;
  final Color success;
  final Color warning;
  final Color danger;
  final Color leave;

  const SoftPalette._({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.pill,
    required this.onPill,
    required this.success,
    required this.warning,
    required this.danger,
    required this.leave,
  });

  static const light = SoftPalette._(
    isDark: false,
    background: AppTheme.backgroundColor,
    surface: Colors.white,
    surfaceAlt: Color(0xFFEEF0F3),
    border: AppTheme.borderColor,
    ink: AppTheme.textPrimaryColor,
    inkSoft: AppTheme.textSecondaryColor,
    muted: AppTheme.textMutedColor,
    accent: AppTheme.primaryColor,
    accentSoft: AppTheme.primaryVeryLight,
    pill: Color(0xFF0B1A30), // deep navy primary action
    onPill: Colors.white,
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    leave: Color(0xFF8B5CF6),
  );

  static const dark = SoftPalette._(
    isDark: true,
    background: AppTheme.darkBackground,
    surface: AppTheme.darkSurface,
    surfaceAlt: AppTheme.darkSurfaceAlt,
    border: AppTheme.darkBorder,
    ink: AppTheme.darkText,
    inkSoft: Color(0xFFCBD5E1),
    muted: AppTheme.darkTextMuted,
    accent: Color(0xFF60A5FA),
    accentSoft: Color(0xFF1E2A4A),
    pill: AppTheme.darkText,
    onPill: AppTheme.darkBackground,
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    leave: Color(0xFFA78BFA),
  );

  static SoftPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Very light shadow used under cards in light mode only.
  List<BoxShadow> get shadow => isDark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

  /// Tinted background for a status / accent color.
  Color tint(Color c) => c.withValues(alpha: isDark ? 0.18 : 0.10);
}

/// Shared text styles (Geist).
class SoftText {
  static TextStyle title(SoftPalette p, {double size = 22}) => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.15,
        color: p.ink,
      );

  static TextStyle heading(SoftPalette p, {double size = 16}) => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: p.ink,
      );

  static TextStyle body(SoftPalette p, {double size = 14, Color? color}) =>
      TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color ?? p.inkSoft,
      );

  static TextStyle caption(SoftPalette p, {double size = 12}) => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: p.muted,
      );

  /// Small uppercase label ("HOURS", "STATUS").
  static TextStyle overline(SoftPalette p) => TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: p.muted,
      );
}

/// Scaffold with the soft background, a [SoftPageHeader] and a body.
class SoftScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? bottomBar;
  final Widget? drawer;

  const SoftScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.bottomBar,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar ??
          (bottomBar == null
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: p.background,
                      border: Border(top: BorderSide(color: p.border)),
                    ),
                    child: bottomBar,
                  ),
                )),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SoftPageHeader(
              title: title,
              subtitle: subtitle,
              actions: actions,
              showBack: showBack,
              onBack: onBack,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Page header: round back button, large title, optional subtitle and
/// trailing round action buttons.
class SoftPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  const SoftPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack) ...[
            SoftIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: SoftText.title(p, size: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: SoftText.caption(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// Round icon button on a surface chip (header actions, back button).
class SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool showDot;
  final double size;

  const SoftIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.showDot = false,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final button = Material(
      color: p.surface,
      shape: CircleBorder(side: BorderSide(color: p.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: size * 0.48, color: p.ink),
              if (showDot)
                Positioned(
                  top: size * 0.22,
                  right: size * 0.24,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: p.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Rounded surface card with hairline border and soft shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: p.border),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: p.shadow,
      ),
      child: Material(
        color: color ?? p.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section title with optional trailing action ("See all").
class SoftSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SoftSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: SoftText.heading(p, size: 17))),
          if (trailing != null) trailing!,
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: SoftText.caption(p, size: 13).copyWith(
                  color: p.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// [blue] is the deep-blue primary used on forms ("Save work log").
enum SoftPillVariant { dark, outline, tonal, danger, blue }

/// Stadium-shaped button. [SoftPillVariant.dark] is the primary action.
class SoftPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Icon shown after the label (e.g. an arrow on "Get Started").
  final IconData? trailingIcon;
  final SoftPillVariant variant;
  final bool loading;
  final bool expand;
  final double height;

  const SoftPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = SoftPillVariant.dark,
    this.loading = false,
    this.expand = true,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final enabled = onPressed != null && !loading;
    late final Color bg;
    late final Color fg;
    BorderSide side = BorderSide.none;
    // A disabled primary button is solid grey (not a faded navy).
    final greyedOut = !enabled && !loading && variant == SoftPillVariant.dark;
    switch (variant) {
      case SoftPillVariant.dark:
        bg = greyedOut
            ? (p.isDark ? p.surfaceAlt : const Color(0xFF8C9199))
            : p.pill;
        fg = greyedOut && p.isDark ? p.muted : p.onPill;
      case SoftPillVariant.outline:
        bg = p.surface;
        fg = p.ink;
        side = BorderSide(color: p.border);
      case SoftPillVariant.tonal:
        bg = p.accentSoft;
        fg = p.accent;
      case SoftPillVariant.danger:
        bg = p.tint(p.danger);
        fg = p.danger;
      case SoftPillVariant.blue:
        bg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
        fg = p.isDark ? p.background : Colors.white;
    }

    final content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 18, color: fg),
              ],
            ],
          );

    final button = Opacity(
      opacity: enabled || loading || greyedOut ? 1 : 0.45,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: side),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Small rounded status pill with a leading dot.
class SoftStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;
  final IconData? icon;

  const SoftStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.showDot = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: p.tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: color)
          else if (showDot)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icon != null || showDot) const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded square icon on a tinted background.
class SoftIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const SoftIconBadge({super.key, required this.icon, this.color, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final c = color ?? p.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.tint(c),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, size: size * 0.48, color: c),
    );
  }
}

/// Label / value row used in detail pages.
class SoftInfoRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;

  const SoftInfoRow({super.key, this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: p.muted),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(label, style: SoftText.caption(p, size: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: SoftText.body(p, color: p.ink).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling filter chips ("All", "Pending", ...).
class SoftSegmentedChips extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<int?>? counts;

  const SoftSegmentedChips({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          final count = counts != null && i < counts!.length ? counts![i] : null;
          return Material(
            color: selected ? p.pill : p.surface,
            shape: StadiumBorder(
              side: BorderSide(color: selected ? p.pill : p.border),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onSelected(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    count == null ? labels[i] : '${labels[i]}  $count',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? p.onPill : p.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Centered empty / error message with optional action.
class SoftMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const SoftMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.color,
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
            SoftIconBadge(icon: icon, color: color ?? p.muted, size: 60),
            const SizedBox(height: 16),
            Text(title, style: SoftText.heading(p), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: SoftText.body(p), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SoftPillButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
                height: 44,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Styled confirm dialog. Returns true when confirmed.
Future<bool> showSoftConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final p = SoftPalette.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: SoftText.heading(p, size: 18)),
      content: Text(message, style: SoftText.body(p)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: SoftPillButton(
                label: cancelLabel,
                variant: SoftPillVariant.outline,
                height: 46,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SoftPillButton(
                label: confirmLabel,
                variant: destructive ? SoftPillVariant.danger : SoftPillVariant.dark,
                height: 46,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}
