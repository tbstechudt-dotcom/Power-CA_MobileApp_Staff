import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/theme_provider.dart';
import '../../features/auth/domain/entities/staff.dart';
import '../../features/pinboard/presentation/pages/pinboard_page.dart';

/// Key for storing last pinboard visit timestamp
const String _kLastPinboardVisitKey = 'last_pinboard_visit_timestamp';

/// Shared app header widget that displays company name and location
/// Fetches data from orgmaster and locmaster tables
class AppHeader extends StatefulWidget {
  final Staff currentStaff;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onMenuTap;

  const AppHeader({
    super.key,
    required this.currentStaff,
    this.onNotificationTap,
    this.onMenuTap,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String _companyName = 'Loading...';
  String _locationName = '';
  bool _isLoading = true;
  bool _hasNewNotifications = false;

  @override
  void initState() {
    super.initState();
    _fetchCompanyAndLocation();
    _checkForNewPinboardItems();
  }

  /// Check for new pinboard items since last visit
  Future<void> _checkForNewPinboardItems() async {
    try {
      final supabase = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();

      // Get last visit timestamp
      final lastVisitString = prefs.getString(_kLastPinboardVisitKey);

      // Query for pinboard items
      final List<dynamic> items;
      if (lastVisitString != null) {
        // Check for items created after last visit
        items = await supabase
            .from('pinboard_items')
            .select('id')
            .gt('created_at', lastVisitString);
      } else {
        // First time user - check if there are any items
        items = await supabase
            .from('pinboard_items')
            .select('id')
            .limit(1);
      }

      if (mounted) {
        setState(() {
          _hasNewNotifications = items.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking for new pinboard items: $e');
    }
  }

  /// Save current timestamp as last pinboard visit
  Future<void> _markPinboardAsVisited() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kLastPinboardVisitKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving pinboard visit timestamp: $e');
    }
  }

  void _navigateToPinboard() async {
    if (mounted) {
      // Mark pinboard as visited BEFORE navigating (clears notification immediately)
      await _markPinboardAsVisited();

      // Clear the notification indicator immediately
      if (mounted) {
        setState(() {
          _hasNewNotifications = false;
        });
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PinboardPage(currentStaff: widget.currentStaff),
          ),
        ).then((_) {
          // Re-check for new pinboard items when returning
          _checkForNewPinboardItems();
        });
      }
    }
  }

  Future<void> _fetchCompanyAndLocation() async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch company name from orgmaster
      final orgResponse = await supabase
          .from('orgmaster')
          .select('orgname')
          .eq('org_id', widget.currentStaff.orgId)
          .maybeSingle();

      // Fetch location from locmaster
      final locResponse = await supabase
          .from('locmaster')
          .select('locname')
          .eq('loc_id', widget.currentStaff.locId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          // Set company name
          if (orgResponse != null) {
            _companyName = orgResponse['orgname'] ?? 'Company';
          } else {
            _companyName = 'Company';
          }

          // Set location from locmaster
          if (locResponse != null) {
            _locationName = locResponse['locname'] ?? '';
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching company/location: $e');
      if (mounted) {
        setState(() {
          _companyName = 'Company';
          _locationName = '';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final iconBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFF3F4F6);
    final iconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF4B5563);
    final titleColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: MediaQuery.of(context).padding.top + 8.h,
        bottom: 12.h,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Hamburger Menu (Left)
          GestureDetector(
            onTap: widget.onMenuTap,
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/powerca icons/hamburger menu.svg',
                  width: 20.sp,
                  height: 20.sp,
                  colorFilter: ColorFilter.mode(
                    iconColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          // Company Name and Location (Center)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLoading ? 'Loading...' : _companyName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (_locationName.isNotEmpty || _isLoading)
                  SizedBox(height: 2.h),
                if (_locationName.isNotEmpty || _isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 12.sp,
                        color: subtitleColor,
                      ),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          _isLoading ? 'Loading...' : _locationName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Notifications (Right)
          GestureDetector(
            onTap: _navigateToPinboard,
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Center(
                    child: SvgPicture.asset(
                      'assets/icons/powerca icons/notification.svg',
                      width: 20.sp,
                      height: 20.sp,
                      colorFilter: ColorFilter.mode(
                        iconColor,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  if (_hasNewNotifications)
                    Positioned(
                      right: 8.w,
                      top: 8.h,
                      child: Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
