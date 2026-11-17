import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/services/app_update_service.dart';
import 'soft_page.dart';

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

  Widget _notice(SoftPalette p, IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: p.tint(p.danger),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.danger),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: SoftText.body(p, size: 12.5, color: p.danger)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);

    return PopScope(
      canPop: !widget.versionInfo.isForceUpdate,
      child: Dialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Update icon
              SoftIconBadge(
                icon: Icons.system_update_rounded,
                color: p.accent,
                size: 64,
              ),

              SizedBox(height: 18.h),

              // Title
              Text('Update Available', style: SoftText.title(p, size: 21)),

              SizedBox(height: 10.h),

              // Version info
              SoftStatusPill(
                label:
                    'v${AppUpdateService.currentVersionName} → v${widget.versionInfo.versionName}',
                color: p.accent,
                showDot: false,
              ),

              SizedBox(height: 18.h),

              // Release notes
              if (widget.versionInfo.releaseNotes != null &&
                  widget.versionInfo.releaseNotes!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("WHAT'S NEW", style: SoftText.overline(p)),
                      SizedBox(height: 6.h),
                      Text(
                        widget.versionInfo.releaseNotes!,
                        style: SoftText.body(p, size: 13, color: p.ink),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
              ],

              // Force update warning
              if (widget.versionInfo.isForceUpdate) ...[
                _notice(
                  p,
                  Icons.warning_rounded,
                  'This update is required to continue using the app.',
                ),
                SizedBox(height: 14.h),
              ],

              // Download progress
              if (_isDownloading) ...[
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: p.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(p.ink),
                        minHeight: 8.h,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(_downloadStatus, style: SoftText.caption(p)),
                  ],
                ),
              ],

              // Error message
              if (_errorMessage != null) ...[
                _notice(p, Icons.error_outline_rounded, _errorMessage!),
                SizedBox(height: 14.h),
              ],

              // Buttons
              if (!_isDownloading) ...[
                SizedBox(height: 6.h),
                SoftPillButton(
                  label: 'Update Now',
                  icon: Icons.download_rounded,
                  onPressed: _startDownload,
                  height: 50,
                ),

                // Skip button (only for non-force updates)
                if (!widget.versionInfo.isForceUpdate && widget.onSkip != null) ...[
                  SizedBox(height: 10.h),
                  SoftPillButton(
                    label: 'Maybe Later',
                    variant: SoftPillVariant.outline,
                    onPressed: widget.onSkip,
                    height: 46,
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
