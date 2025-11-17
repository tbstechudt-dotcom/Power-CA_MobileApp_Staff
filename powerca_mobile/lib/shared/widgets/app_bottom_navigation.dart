import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../app/theme.dart';
import '../../features/auth/domain/entities/staff.dart';

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
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
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
    final isSelected = currentIndex == index;
    final color = isSelected ? AppTheme.primaryColor : const Color(0xFF9E9E9E);

    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      highlightColor: AppTheme.primaryColor.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: 26.sp,
              color: color,
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
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
