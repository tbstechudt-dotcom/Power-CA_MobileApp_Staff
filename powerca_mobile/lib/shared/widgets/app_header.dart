import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/entities/staff.dart';
import '../../features/pinboard/presentation/pages/pinboard_page.dart';

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
    _checkForNewReminders();
  }

  Future<void> _checkForNewReminders() async {
    try {
      final supabase = Supabase.instance.client;

      // Check for pending reminders (status = 0) for current staff
      final response = await supabase
          .from('reminder')
          .select('rem_id')
          .eq('staff_id', widget.currentStaff.staffId)
          .eq('remstatus', 0)
          .limit(1);

      if (mounted) {
        // Show notification dot if there are ANY pending reminders
        setState(() {
          _hasNewNotifications = response.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error checking for new reminders: $e');
    }
  }

  void _navigateToPinboard() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PinboardPage(currentStaff: widget.currentStaff),
        ),
      ).then((_) {
        // Re-check for pending reminders when returning from Pinboard
        _checkForNewReminders();
      });
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Company Name and Location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoading ? 'Loading...' : _companyName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
                if (_locationName.isNotEmpty || _isLoading)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14.sp,
                        color: const Color(0xFF6B7280),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _isLoading ? 'Loading...' : _locationName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Notifications
          GestureDetector(
            onTap: _navigateToPinboard,
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 20.sp,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (_hasNewNotifications)
                    Positioned(
                      right: 10.w,
                      top: 10.h,
                      child: Container(
                        width: 8.w,
                        height: 8.h,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Menu
          GestureDetector(
            onTap: widget.onMenuTap,
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.menu,
                  size: 20.sp,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
