import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
import '../../../auth/domain/entities/staff.dart';

/// Profile page displaying staff registration details
class ProfilePage extends StatefulWidget {
  final Staff currentStaff;

  const ProfilePage({
    super.key,
    required this.currentStaff,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _getStaffRole(int? staffType) {
    switch (staffType) {
      case 1:
        return 'Administrator';
      case 2:
        return 'Manager';
      case 3:
        return 'Senior Staff';
      case 4:
        return 'Staff Member';
      case 5:
        return 'Junior Staff';
      default:
        return 'Staff Member';
    }
  }

  /// Letters/digits only, so "TEST USER (DUMMY)" gives "TU", not "T(".
  String _getInitials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  /// "TEST USER (DUMMY)" -> "Test User (dummy)".
  String _titleCase(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _orDash(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? '-' : v;
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final staff = widget.currentStaff;
    final role = _getStaffRole(staff.staffType);
    final displayName = _titleCase(staff.name);

    final infoRows = <({String label, String value})>[
      (label: 'Full name', value: _orDash(staff.name)),
      (label: 'Username', value: _orDash(staff.username)),
      (label: 'Email', value: _orDash(staff.email)),
      (label: 'Phone', value: _orDash(staff.phoneNumber)),
      if (staff.dateOfBirth != null)
        (
          label: 'Date of birth',
          value: DateFormat('MMMM d, yyyy').format(staff.dateOfBirth!),
        ),
    ];

    return HomeSubPage(
      eyebrow: 'Profile',
      headline: [
        (text: displayName, strong: true),
        (text: ' · $role', strong: false),
      ],
      children: [
        _buildSummaryCard(p, displayName, role),
        HomeSectionCard(
          title: 'Personal information',
          subtitle: 'From your staff record',
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < infoRows.length; i++)
                _InfoRow(
                  label: infoRows[i].label,
                  value: infoRows[i].value,
                  last: i == infoRows.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(SoftPalette p, String displayName, String role) {
    final staff = widget.currentStaff;
    final isActive = staff.isActive;

    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(staff.name),
                  style: SoftText.heading(p, size: 18).copyWith(
                    color: p.isDark ? p.background : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: SoftText.heading(p, size: 16.5)
                          .copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(role, style: SoftText.caption(p, size: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HomeStat(
                  label: 'Staff ID',
                  value: '${staff.staffId}',
                  dot: p.accent,
                ),
              ),
              Expanded(
                child: HomeStat(
                  label: 'Org',
                  value: '${staff.orgId}',
                  dot: p.leave,
                ),
              ),
              Expanded(
                child: HomeStat(
                  label: 'Status',
                  value: isActive ? 'Active' : 'Inactive',
                  dot: isActive ? p.success : p.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Value (ink) over label (muted caption), with a divider below unless
/// [last].
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _InfoRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: SoftText.body(p, size: 15, color: p.ink)
                    .copyWith(height: 1.25),
              ),
              const SizedBox(height: 3),
              Text(label, style: SoftText.caption(p, size: 11.5)),
            ],
          ),
        ),
        if (!last) Divider(height: 1, thickness: 1, color: p.border),
      ],
    );
  }
}
