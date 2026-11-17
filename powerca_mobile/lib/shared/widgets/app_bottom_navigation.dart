import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app/theme.dart';
import '../../features/auth/domain/entities/staff.dart';
import 'soft_page.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Staff currentStaff;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.currentStaff,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
        boxShadow: p.shadow,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context: context,
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              label: 'Dashboard',
              index: 0,
              onTap: () {
                if (currentIndex != 0) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard',
                    (route) => false,
                    arguments: currentStaff,
                  );
                }
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.list_alt_outlined,
              selectedIcon: Icons.list_alt,
              label: 'Job List',
              index: 1,
              onTap: () {
                if (currentIndex != 1) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/jobs',
                    arguments: currentStaff,
                  );
                }
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.event_note_outlined,
              selectedIcon: Icons.event_note,
              label: 'Leave Req',
              index: 2,
              onTap: () {
                if (currentIndex != 2) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/leave-requests',
                    arguments: currentStaff,
                  );
                }
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.push_pin_outlined,
              selectedIcon: Icons.push_pin,
              label: 'Pinboard',
              index: 3,
              onTap: () {
                if (currentIndex != 3) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/pinboard',
                    arguments: currentStaff,
                  );
                }
              },
            ),
          ],
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
    required VoidCallback onTap,
  }) {
    final p = SoftPalette.of(context);
    final isSelected = currentIndex == index;
    final color = isSelected ? p.ink : p.muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isSelected ? p.pill : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                isSelected ? selectedIcon : icon,
                size: 22.sp,
                color: isSelected ? p.onPill : color,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
