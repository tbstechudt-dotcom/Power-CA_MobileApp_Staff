import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app/theme.dart';
import '../../features/auth/domain/entities/staff.dart';

/// Modern Bottom Navigation Bar with Floating Action Button
///
/// Features:
/// - Elevated floating center button for primary actions
/// - Smooth animations and transitions
/// - Modern glassmorphism design
/// - Active indicator with smooth transitions
/// - Haptic feedback on tap
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

    // Animate the selected item
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
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                animation: _animations[0],
                onTap: () => _navigateTo(context, '/dashboard', 0),
              ),
              _buildNavItem(
                context: context,
                icon: Icons.work_outline_rounded,
                selectedIcon: Icons.work_rounded,
                label: 'Jobs',
                index: 1,
                animation: _animations[1],
                onTap: () => _navigateTo(context, '/jobs', 1),
              ),
              _buildNavItem(
                context: context,
                icon: Icons.calendar_month_outlined,
                selectedIcon: Icons.calendar_month_rounded,
                label: 'Leave',
                index: 2,
                animation: _animations[2],
                onTap: () => _navigateTo(context, '/leave', 2),
              ),
              _buildNavItem(
                context: context,
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
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required Animation<double> animation,
    required VoidCallback onTap,
  }) {
    final isSelected = widget.currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        highlightColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with scale animation
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (animation.value * 0.08),
                    child: Container(
                      width: 24.w,
                      height: 24.h,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Icon(
                        isSelected ? selectedIcon : icon,
                        size: 16.sp,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : const Color(0xFF9E9E9E),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 2.h),
              // Label with fade animation
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.6 + (animation.value * 0.4),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8.sp,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : const Color(0xFF9E9E9E),
                        letterSpacing: 0.2,
                      ),
                    ),
                  );
                },
              ),
              // Active indicator
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Container(
                    width: 16.w * animation.value,
                    height: 2.h,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(1.r),
                    ),
                  );
                },
              ),
            ],
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
