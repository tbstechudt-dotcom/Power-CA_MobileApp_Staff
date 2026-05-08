import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/app_update_service.dart';

/// Dialog to show app update available
class UpdateDialog extends StatefulWidget {
  final AppVersionInfo versionInfo;
  final VoidCallback? onSkip;

  const UpdateDialog({
    super.key,
    required this.versionInfo,
    this.onSkip,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();

  /// Show the update dialog
  static Future<void> show(
    BuildContext context,
    AppVersionInfo versionInfo,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: !versionInfo.isForceUpdate,
      builder: (context) => UpdateDialog(
        versionInfo: versionInfo,
        onSkip: versionInfo.isForceUpdate ? null : () => Navigator.pop(context),
      ),
    );
  }
}

class _UpdateDialogState extends State<UpdateDialog> {
  final _updateService = AppUpdateService();
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String _downloadStatus = '';
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadStatus = 'Starting download...';
      _errorMessage = null;
    });

    final filePath = await _updateService.downloadApk(
      widget.versionInfo.downloadUrl,
      (received, total) {
        if (total > 0) {
          setState(() {
            _downloadProgress = received / total;
            _downloadStatus =
                '${_updateService.formatFileSize(received)} / ${_updateService.formatFileSize(total)}';
          });
        }
      },
    );

    if (filePath != null) {
      setState(() {
        _downloadStatus = 'Installing...';
      });

      final installed = await _updateService.installApk(filePath);

      if (!installed && mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Could not install the update. Please try again.';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed. Please check your internet connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1F2937);
    final subtitleColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
    final borderColor = isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

    return PopScope(
      canPop: !widget.versionInfo.isForceUpdate,
      child: Dialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Update icon
              Container(
                width: 72.w,
                height: 72.h,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  size: 36.sp,
                  color: AppTheme.primaryColor,
                ),
              ),

              SizedBox(height: 20.h),

              // Title
              Text(
                'Update Available',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),

              SizedBox(height: 8.h),

              // Version info
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'v${AppUpdateService.currentVersionName} → v${widget.versionInfo.versionName}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Release notes
              if (widget.versionInfo.releaseNotes != null &&
                  widget.versionInfo.releaseNotes!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        widget.versionInfo.releaseNotes!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Force update warning
              if (widget.versionInfo.isForceUpdate) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        size: 20.sp,
                        color: AppTheme.errorColor,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'This update is required to continue using the app.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Download progress
              if (_isDownloading) ...[
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        minHeight: 8.h,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _downloadStatus,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ],

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Buttons
              if (!_isDownloading) ...[
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 20.sp,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Update Now',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Skip button (only for non-force updates)
                if (!widget.versionInfo.isForceUpdate && widget.onSkip != null) ...[
                  SizedBox(height: 12.h),
                  TextButton(
                    onPressed: widget.onSkip,
                    child: Text(
                      'Maybe Later',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
