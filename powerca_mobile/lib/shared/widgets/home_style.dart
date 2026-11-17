import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'soft_page.dart';

/// Home page styles.

/// Two-tone headline: a strong first line and a softer second line, e.g.
/// "Good morning, Priya" / "Here's your week."
class HomeHeadline extends StatelessWidget {
  final String strong;
  final String soft;
  final double size;

  const HomeHeadline({
    super.key,
    required this.strong,
    required this.soft,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: size,
      height: 1.15,
      letterSpacing: -0.9,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: strong, style: base.copyWith(color: p.ink)),
          const TextSpan(text: '\n'),
          TextSpan(
            text: soft,
            style: base.copyWith(color: p.muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// One-line two-tone status sentence, e.g.
/// "Today's work is **not logged** yet." Pass the parts in order; parts
/// with `strong: true` are drawn in the ink color, the rest muted.
class HomeInlineHeadline extends StatelessWidget {
  final List<({String text, bool strong})> parts;
  final double size;

  const HomeInlineHeadline({super.key, required this.parts, this.size = 25});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: size,
      height: 1.2,
      letterSpacing: -0.7,
      fontWeight: FontWeight.w500,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final part in parts)
            TextSpan(
              text: part.text,
              style: base.copyWith(color: part.strong ? p.ink : p.muted.withValues(alpha: 0.85)),
            ),
        ],
      ),
    );
  }
}

/// Outlined white stadium button with a leading icon ("View entries").
class HomeOutlinePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const HomeOutlinePill({super.key, required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Material(
      color: p.surface,
      shape: StadiumBorder(side: BorderSide(color: p.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: p.accent),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home page background: a soft blue glow in the top-right corner fading
/// into the page background.
class HomeBackground extends StatelessWidget {
  final Widget child;
  const HomeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        gradient: RadialGradient(
          center: const Alignment(0.9, -1.05),
          radius: 1.25,
          colors: [
            p.isDark ? const Color(0xFF1B2A4D) : const Color(0xFFD5E2FB),
            p.background,
          ],
          stops: const [0.0, 0.75],
        ),
      ),
      child: child,
    );
  }
}

/// Sub page layout used across the app (Profile, Settings, Apply leave,
/// Help ...): soft blue background, round back button, a small [eyebrow],
/// a two-tone [headline] (parts with `strong: true` in ink) and the page
/// [children] (usually [HomeSectionCard]s) in a scroll view. [bottom] is
/// pinned under the scroll view (e.g. a blue submit button).
class HomeSubPage extends StatelessWidget {
  final String eyebrow;
  final List<({String text, bool strong})> headline;
  final List<Widget> children;
  final Widget? bottom;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;
  final double headlineSize;

  const HomeSubPage({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.children,
    this.bottom,
    this.actions = const [],
    this.onRefresh,
    this.headlineSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeEyebrow(eyebrow),
              HomeInlineHeadline(parts: headline, size: headlineSize),
            ],
          ),
        ),
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          children[i],
        ],
      ],
    );
    if (onRefresh != null) list = RefreshIndicator(onRefresh: onRefresh!, child: list);

    return Scaffold(
      backgroundColor: p.background,
      body: HomeBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Row(
                  children: [
                    SoftIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      size: 44,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    for (final a in actions) ...[const SizedBox(width: 8), a],
                  ],
                ),
              ),
              Expanded(child: list),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small muted label above a tab headline ("My jobs", "My leave · FY ...").
class HomeEyebrow extends StatelessWidget {
  final String text;
  const HomeEyebrow(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: SoftText.caption(p, size: 12.5)),
    );
  }
}

/// White rounded card with a title, a caption and an optional trailing
/// action, followed by [child]. Used for the sections of the main tabs.
class HomeSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const HomeSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 14),
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return SoftCard(
      radius: 26,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SoftText.heading(p, size: 17.5)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: SoftText.caption(p, size: 12)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Row in a [HomeSectionCard] list: colored dot, label (+ optional
/// caption), count and chevron, with a divider above unless [first].
class HomeStatusRow extends StatelessWidget {
  final Color color;
  final String label;
  final String? caption;
  final String count;
  final VoidCallback? onTap;
  final bool first;

  const HomeStatusRow({
    super.key,
    required this.color,
    required this.label,
    required this.count,
    this.caption,
    this.onTap,
    this.first = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Column(
      children: [
        if (!first) Divider(height: 1, color: p.border),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: SoftText.body(p, size: 15, color: p.ink)),
                      if (caption != null)
                        Text(caption!, style: SoftText.caption(p, size: 11.5)),
                    ],
                  ),
                ),
                Text(count, style: SoftText.heading(p, size: 15)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Small stat: optional colored dot + muted label above a bold value.
class HomeStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? dot;

  const HomeStat({super.key, required this.label, required this.value, this.dot});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(label, style: SoftText.caption(p, size: 12)),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: SoftText.heading(p, size: 15.5)),
      ],
    );
  }
}

/// Round outlined icon button (e.g. the arrow on "Job overview").
class HomeRoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const HomeRoundAction({super.key, required this.icon, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return SoftIconButton(icon: icon, onTap: onTap, tooltip: tooltip, size: 44);
  }
}

/// Horizontal bar split into rounded colored segments by value.
class HomeSegmentBar extends StatelessWidget {
  final List<({double value, Color color})> segments;
  final double height;

  const HomeSegmentBar({super.key, required this.segments, this.height = 22});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final parts = segments.where((s) => s.value > 0).toList();
    if (parts.isEmpty) {
      // Nothing to show yet: light diagonal stripes.
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _StripePainter(
              background: p.isDark ? p.surfaceAlt : const Color(0xFFE9EEF6),
              stripe: p.isDark ? p.border : const Color(0xFFD3DBE8),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              flex: (parts[i].value * 1000).round().clamp(1, 1 << 30),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(parts[i].color, Colors.white, 0.18)!,
                      parts[i].color,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final Color background;
  final Color stripe;
  _StripePainter({required this.background, required this.stripe});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = 4;
    for (double x = -size.height; x < size.width + size.height; x += 10) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) =>
      old.background != background || old.stripe != stripe;
}

/// Deep-blue stadium action ("+ Apply leave", "+ Book").
class HomeBluePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const HomeBluePill({super.key, required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final bg = p.isDark ? p.accent : const Color(0xFF1E3A8A);
    final fg = p.isDark ? p.background : Colors.white;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label, style: SoftText.heading(p, size: 14).copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark stadium pill used for compact actions on Home ("Log work", "Add meeting").
class HomeDarkPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool compact;

  const HomeDarkPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Material(
      color: p.pill,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 7 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 15 : 17, color: p.onPill),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: compact ? 12.5 : 13.5,
                  fontWeight: FontWeight.w600,
                  color: p.onPill,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
