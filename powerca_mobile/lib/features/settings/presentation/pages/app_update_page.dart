import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../shared/widgets/update_dialog.dart';

/// App Update Page - Shows current version and check for updates
class AppUpdatePage extends StatefulWidget {
  const AppUpdatePage({super.key});

  @override
  State<AppUpdatePage> createState() => _AppUpdatePageState();
}

class _AppUpdatePageState extends State<AppUpdatePage> {
  final AppUpdateService _updateService = AppUpdateService();
  bool _isChecking = false;
  AppVersionInfo? _latestVersion;
  String? _errorMessage;
  bool _isUpToDate = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _isUpToDate = false;
    });

    try {
      final latestVersion = await _updateService.checkForUpdate();

      if (mounted) {
        setState(() {
          _latestVersion = latestVersion;
          _isChecking = false;
          _isUpToDate = latestVersion == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to check for updates';
          _isChecking = false;
        });
      }
    }
  }

  void _showUpdateDialog() {
    if (_latestVersion != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateDialog(
          versionInfo: _latestVersion!,
          onSkip: () => Navigator.pop(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final backBtnBgColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE8EDF3);
    final backBtnBorderColor = isDarkMode ? const Color(0xFF475569) : const Color(0xFFD1D9E6);
    final backBtnIconColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42.w,
                height: 42.h,
                decoration: BoxDecoration(
                  color: backBtnBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: backBtnBorderColor,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18.sp,
                    color: backBtnIconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'App Update',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // App Info Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  // App Icon
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.work_outline_rounded,
                        size: 40.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // App Name
                  Text(
                    'PowerCA Staff',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Current Version
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'Version ${AppUpdateService.currentVersionName}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Build ${AppUpdateService.currentVersionCode}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Update Status Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (_isChecking) ...[
                    // Checking state
                    SizedBox(
                      width: 40.w,
                      height: 40.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Checking for updates...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ] else if (_errorMessage != null) ...[
                    // Error state
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 28.sp,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildRetryButton(),
                  ] else if (_isUpToDate) ...[
                    // Up to date state
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 32.sp,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'You\'re up to date!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'PowerCA Staff ${AppUpdateService.currentVersionName} is the latest version.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    _buildCheckAgainButton(),
                  ] else if (_latestVersion != null) ...[
                    // Update available state
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.system_update_rounded,
                          size: 28.sp,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Update Available!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'Version ${_latestVersion!.versionName}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (_latestVersion!.releaseNotes != null &&
                        _latestVersion!.releaseNotes!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF334155)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What\'s New:',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              _latestVersion!.releaseNotes!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                    _buildUpdateButton(),
                  ],
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Info Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                      : const Color(0xFF93C5FD),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20.sp,
                    color: const Color(0xFF3B82F6),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Updates are downloaded from our secure servers and include the latest features and security improvements.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: isDarkMode
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckAgainButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _checkForUpdates,
        icon: Icon(
          Icons.refresh_rounded,
          size: 18.sp,
        ),
        label: Text(
          'Check Again',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF3B82F6),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          side: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _checkForUpdates,
        icon: Icon(
          Icons.refresh_rounded,
          size: 18.sp,
        ),
        label: Text(
          'Try Again',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          side: const BorderSide(color: Color(0xFFDC2626)),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showUpdateDialog,
        icon: Icon(
          Icons.download_rounded,
          size: 18.sp,
          color: Colors.white,
        ),
        label: Text(
          'Download Update',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
