const fs = require('fs');
let content = fs.readFileSync('lib/shared/widgets/app_drawer.dart', 'utf8');

// Remove problematic imports
content = content.replace(/import 'package:flutter\/foundation.dart' show kIsWeb;\n/, '');
content = content.replace(/import 'package:shared_preferences\/shared_preferences.dart';\n/, '');
content = content.replace(/import 'dart:io';\n/, '');

// Remove state variable and initState/loadProfileImage methods
content = content.replace(/  String\? _profileImagePath;\n\n/, '');
content = content.replace(/  @override\n  void initState\(\) \{\n    super.initState\(\);\n    _loadProfileImage\(\);\n  \}\n\n  Future<void> _loadProfileImage\(\) async \{[\s\S]*?\n  \}\n\n/, '');

// Replace the complex _buildProfileHeader with a simple version
const oldProfileHeader = /Widget _buildProfileHeader\(\) \{[\s\S]*?  \}(?=\n\n  Widget _buildMenuItem)/;
const newProfileHeader = `Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(widget.currentStaff.name),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.currentStaff.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  'Staff ID: \${widget.currentStaff.staffId}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }`;
content = content.replace(oldProfileHeader, newProfileHeader);

// Remove the .then callback for profile image refresh
content = content.replace(/\).then\(\(result\) \{[\s\S]*?\}\);/, ');');

fs.writeFileSync('lib/shared/widgets/app_drawer.dart', content);
console.log('File fixed successfully');
