import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app/theme.dart';
import '../../features/auth/domain/entities/staff.dart';

/// Modern Bottom Navigation Bar - Fully Responsive
/// Works on all devices including Xiaomi, Samsung, etc.
/// Uses ClipRect to absolutely prevent any overflow
class ModernBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Staff currentStaff;
  final VoidCallback? onAddPressed;

  const ModernBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.currentStaff,
    this.onAddPressed,
  });

  @override
  State<ModernBottomNavigation> createState() => _ModernBottomNavigationState();
}

class _ModernBottomNavigationState extends State<ModernBottomNavigation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      4,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _animations = _controllers
        .map((controller) => Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: controller, curve: Curves.easeInOut),
            ),)
        .toList();

    if (widget.currentIndex < _controllers.length) {
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void didUpdateWidget(ModernBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      if (oldWidget.currentIndex < _controllers.length) {
        _controllers[oldWidget.currentIndex].reverse();
      }
      if (widget.currentIndex < _controllers.length) {
        _controllers[widget.currentIndex].forward();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Use very small fixed height to prevent any overflow
    const double navContentHeight = 48.0;
    final totalHeight = navContentHeight + bottomPadding;

    return ClipRect(
      child: Container(
        height: totalHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nav content area - fixed height with clip
            ClipRect(
              child: SizedBox(
                height: navContentHeight,
                child: Row(
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Home',
                      index: 0,
                      animation: _animations[0],
                      onTap: () => _navigateTo(context, '/dashboard', 0),
                    ),
                    _buildNavItem(
                      icon: Icons.work_outline_rounded,
                      selectedIcon: Icons.work_rounded,
                      label: 'Jobs',
                      index: 1,
                      animation: _animations[1],
                      onTap: () => _navigateTo(context, '/jobs', 1),
                    ),
                    _buildNavItem(
                      icon: Icons.calendar_month_outlined,
                      selectedIcon: Icons.calendar_month_rounded,
                      label: 'Leave',
                      index: 2,
                      animation: _animations[2],
                      onTap: () => _navigateTo(context, '/leave', 2),
                    ),
                    _buildNavItem(
                      icon: Icons.push_pin_outlined,
                      selectedIcon: Icons.push_pin,
                      label: 'Pinboard',
                      index: 3,
                      animation: _animations[3],
                      onTap: () => _navigateTo(context, '/pinboard', 3),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom safe area padding
            if (bottomPadding > 0)
              SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required Animation<double> animation,
    required VoidCallback onTap,
  }) {
    final isSelected = widget.currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          highlightColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon - minimal size
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: 18,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFF9E9E9E),
                ),
                const SizedBox(height: 2),
                // Label - minimal size
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : const Color(0xFF9E9E9E),
                    height: 1.0,
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
                // Active indicator - only show when selected
                if (isSelected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 12,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String route, int index) {
    if (widget.currentIndex != index) {
      if (index == 0) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          route,
          (route) => false,
          arguments: widget.currentStaff,
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          route,
          arguments: widget.currentStaff,
        );
      }
    }
  }
}