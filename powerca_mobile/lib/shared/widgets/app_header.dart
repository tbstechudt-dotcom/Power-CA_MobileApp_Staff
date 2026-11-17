import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'soft_page.dart';
import '../../core/services/company_name_cache.dart';
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

  /// Home layout: avatar + greeting + name on the left, notification and
  /// menu buttons on the right, "Concern · Location" underneath. The
  /// background is transparent so the Home gradient shows through.
  final bool homeStyle;

  /// In [homeStyle], show the "Concern · Location" line under the name.
  final bool showPlace;

  const AppHeader({
    super.key,
    required this.currentStaff,
    this.onNotificationTap,
    this.onMenuTap,
    this.homeStyle = false,
    this.showPlace = true,
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
            // Remember it for the sign-in screens (shown before login).
            if (orgResponse['orgname'] != null) {
              CompanyNameCache.save(orgResponse['orgname'].toString());
            }
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
    final p = SoftPalette.of(context);

    Widget circle({required Widget child, required VoidCallback? onTap, bool dot = false, String? label}) {
      return Semantics(
        button: true,
        label: label,
        child: Material(
          color: p.surface,
          shape: CircleBorder(side: BorderSide(color: p.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  child,
                  if (dot)
                    Positioned(
                      right: 11,
                      top: 11,
                      child: Container(
                        width: 9,
                        height: 9,
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
        ),
      );
    }

    if (widget.homeStyle) return _buildHomeHeader(p, circle);

    return Container(
      color: p.background,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 6,
      ),
      child: Row(
        children: [
          // Menu (left)
          circle(
            label: 'Menu',
            onTap: widget.onMenuTap,
            child: SvgPicture.asset(
              'assets/icons/powerca icons/hamburger menu.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(p.ink, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 12),
          // Company name and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLoading ? 'Loading...' : _companyName,
                  style: SoftText.heading(p, size: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_locationName.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: p.muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _locationName,
                          style: SoftText.caption(p, size: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Notifications (right)
          circle(
            label: 'Pinboard',
            onTap: _navigateToPinboard,
            dot: _hasNewNotifications,
            child: SvgPicture.asset(
              'assets/icons/powerca icons/notification.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(p.ink, BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }

  /// "TEST USER (DUMMY)" -> "Test User (dummy)"; keeps short all-caps
  /// words like "LLP" or "CA" as they are.
  static String _titleCase(String s) {
    return s.trim().split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      final letters = w.replaceAll(RegExp(r'[^A-Za-z]'), '');
      if (letters.length <= 3 && letters == letters.toUpperCase() && w != '&') {
        return w;
      }
      final i = w.indexOf(RegExp(r'[A-Za-z]'));
      if (i == -1) return w;
      return w.substring(0, i) + w[i].toUpperCase() + w.substring(i + 1).toLowerCase();
    }).join(' ');
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHomeHeader(
    SoftPalette p,
    Widget Function({required Widget child, required VoidCallback? onTap, bool dot, String? label}) circle,
  ) {
    final name = _titleCase(widget.currentStaff.name);
    final initial = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final place = [
      if (!_isLoading && _companyName.isNotEmpty) _titleCase(_companyName),
      if (_locationName.isNotEmpty) _titleCase(_locationName),
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                child: Text(
                  initial.isEmpty ? 'U' : initial[0].toUpperCase(),
                  style: SoftText.heading(p, size: 18).copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_greeting(), style: SoftText.caption(p, size: 12.5)),
                    const SizedBox(height: 1),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SoftText.heading(p, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              circle(
                label: 'Pinboard',
                onTap: _navigateToPinboard,
                dot: _hasNewNotifications,
                child: SvgPicture.asset(
                  'assets/icons/powerca icons/notification.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(p.ink, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 10),
              circle(
                label: 'Menu',
                onTap: widget.onMenuTap,
                child: SvgPicture.asset(
                  'assets/icons/powerca icons/hamburger menu.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(p.ink, BlendMode.srcIn),
                ),
              ),
            ],
          ),
          if (widget.showPlace) ...[
            const SizedBox(height: 14),
            Text(
              _isLoading ? ' ' : place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SoftText.caption(p, size: 12.5),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}
