import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2563EB)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2563EB),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Profile Header Section (without photo)
            _buildProfileHeaderSection(),
            SizedBox(height: 24.h),

            // Personal Information Section
            _buildSectionCard(
              title: 'Personal Information',
              icon: Icons.person_outline,
              children: [
                _buildDetailRow('Full Name', widget.currentStaff.name),
                _buildDetailRow('Username', widget.currentStaff.username),
                _buildDetailRow('Email', widget.currentStaff.email ?? 'Not provided'),
                _buildDetailRow('Phone', widget.currentStaff.phoneNumber ?? 'Not provided'),
                if (widget.currentStaff.dateOfBirth != null)
                  _buildDetailRow(
                    'Date of Birth',
                    DateFormat('MMMM d, yyyy').format(widget.currentStaff.dateOfBirth!),
                  ),
              ],
            ),
            SizedBox(height: 16.h),

            // Work Information Section
            _buildSectionCard(
              title: 'Work Information',
              icon: Icons.work_outline,
              children: [
                _buildDetailRow('Staff ID', '#${widget.currentStaff.staffId}'),
                _buildDetailRow('Role', _getStaffRole(widget.currentStaff.staffType)),
                _buildDetailRow('Organization ID', '${widget.currentStaff.orgId}'),
                _buildDetailRow('Location ID', '${widget.currentStaff.locId}'),
                _buildDetailRow('Contact ID', '${widget.currentStaff.conId}'),
                _buildDetailRow(
                  'Status',
                  widget.currentStaff.isActive ? 'Active' : 'Inactive',
                  valueColor: widget.currentStaff.isActive
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFDC2626),
                ),
              ],
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Name
          Text(
            widget.currentStaff.name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          // Role
          Text(
            _getStaffRole(widget.currentStaff.staffType),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 8.h),
          // Staff ID badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'Staff ID: ${widget.currentStaff.staffId}',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  icon,
                  size: 18.sp,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Details
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: valueColor ?? const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
