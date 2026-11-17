import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/auth/domain/entities/staff.dart';
import '../../features/home/presentation/pages/work_log_entry_form_page.dart';
import 'soft_page.dart';

/// Bottom navigation - floating navy pill with the four tabs plus a round
/// "+" button beside it.
///
/// The active tab is a white circle with a blue icon; the others are light
/// icons on the navy pill. "+" calls [onAddPressed], or by default opens
/// the work log form for today.
class ModernBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Staff currentStaff;
  final VoidCallback? onAddPressed;

  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.currentStaff,
    this.onAddPressed,
  });

  static const _items = [
    _NavItem('Home', '/dashboard', 'home stroke.svg', 'home fill.svg'),
    _NavItem('Jobs', '/jobs', 'jobs stroke.svg', 'jobs fill.svg'),
    _NavItem('Leave', '/leave', 'leave stroke.svg', 'leave fill.svg'),
    _NavItem('Pinboard', '/pinboard', 'pinboard stroke.svg', 'Pinboard fill.svg'),
  ];

  static const double _barHeight = 62;

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBg = p.isDark ? p.surfaceAlt : p.pill;
    final shadow = p.isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: const Color(0xFF0B1A30).withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, bottomPadding > 0 ? bottomPadding + 4 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tab pill
          Container(
            height: _barHeight,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _items.length; i++) _buildItem(context, p, i),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Add button
          Semantics(
            button: true,
            label: 'Add work log',
            child: Material(
              color: navBg,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAddPressed ?? () => _openTodayLog(context),
                child: Container(
                  width: _barHeight,
                  height: _barHeight,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadow),
                  child: Icon(Icons.add_rounded, size: 28, color: p.isDark ? p.ink : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, SoftPalette p, int index) {
    final item = _items[index];
    final selected = index == currentIndex;
    final iconColor = selected
        ? p.accent
        : (p.isDark ? p.muted : Colors.white.withValues(alpha: 0.62));

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkResponse(
          onTap: () => _navigateTo(context, item.route, index),
          radius: 28,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 50,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: selected ? (p.isDark ? p.ink : Colors.white) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/icons/powerca icons/${selected ? item.selectedIcon : item.icon}',
              width: 21,
              height: 21,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  void _openTodayLog(BuildContext context) {
    final now = DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkLogEntryFormPage(
          selectedDate: DateTime(now.year, now.month, now.day),
          staffId: currentStaff.staffId,
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String route, int index) {
    if (currentIndex == index) return;
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        route,
        (route) => false,
        arguments: currentStaff,
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        route,
        arguments: currentStaff,
      );
    }
  }
}

class _NavItem {
  final String label;
  final String route;
  final String icon;
  final String selectedIcon;
  const _NavItem(this.label, this.route, this.icon, this.selectedIcon);
}
