import 'package:flutter/material.dart';

import '../../../../core/services/app_update_service.dart';
import '../../../../shared/widgets/home_style.dart';
import '../../../../shared/widgets/soft_page.dart';
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

  bool get _hasUpdate =>
      !_isChecking && _errorMessage == null && !_isUpToDate && _latestVersion != null;

  List<({String text, bool strong})> _headline() {
    const current = 'v${AppUpdateService.currentVersionName}';
    if (_isChecking) {
      return const [
        (text: 'Checking for ', strong: false),
        (text: 'updates', strong: true),
        (text: '...', strong: false),
      ];
    }
    if (_errorMessage != null) {
      return const [
        (text: 'You\'re on ', strong: false),
        (text: current, strong: true),
        (text: ' — ', strong: false),
        (text: 'check failed.', strong: true),
      ];
    }
    if (_hasUpdate) {
      return [
        const (text: 'Version ', strong: false),
        (text: 'v${_latestVersion!.versionName}', strong: true),
        const (text: ' is ', strong: false),
        const (text: 'available.', strong: true),
      ];
    }
    return const [
      (text: 'You\'re on ', strong: false),
      (text: current, strong: true),
      (text: ' — ', strong: false),
      (text: 'up to date.', strong: true),
    ];
  }

  String _cardSubtitle() {
    if (_isChecking) return 'Checking for updates...';
    if (_errorMessage != null) return 'Could not reach the update server';
    if (_hasUpdate) return 'A new version is available';
    return 'This is the latest version';
  }

  String _latestLabel() {
    if (_hasUpdate) return 'v${_latestVersion!.versionName}';
    if (_isUpToDate) return 'v${AppUpdateService.currentVersionName}';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final p = SoftPalette.of(context);
    final releaseNotes = _latestVersion?.releaseNotes;

    return HomeSubPage(
      eyebrow: 'App update',
      headline: _headline(),
      children: [
        HomeSectionCard(
          title: 'PowerCA Staff',
          subtitle: _cardSubtitle(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          trailing: HomeRoundAction(
            icon: Icons.north_east_rounded,
            tooltip: _hasUpdate ? 'Download update' : 'Check for updates',
            onTap: _isChecking
                ? null
                : (_hasUpdate ? _showUpdateDialog : _checkForUpdates),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: HomeStat(
                      label: 'Current',
                      value: 'v${AppUpdateService.currentVersionName}',
                      dot: p.accent,
                    ),
                  ),
                  Expanded(
                    child: HomeStat(
                      label: 'Latest',
                      value: _latestLabel(),
                      dot: p.muted,
                    ),
                  ),
                  const Expanded(
                    child: HomeStat(
                      label: 'Build',
                      value: '${AppUpdateService.currentVersionCode}',
                    ),
                  ),
                ],
              ),

              // Error message
              if (!_isChecking && _errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.tint(p.danger),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, size: 18, color: p.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: SoftText.body(p, size: 13, color: p.danger)
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Release notes for an available update
              if (_hasUpdate && releaseNotes != null && releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("What's new", style: SoftText.caption(p, size: 12)),
                      const SizedBox(height: 6),
                      Text(
                        releaseNotes,
                        style: SoftText.body(p, size: 13, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _buildActionButton(),
            ],
          ),
        ),
        HomeSectionCard(
          title: 'About updates',
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Text(
            'Updates are downloaded from our secure servers and include the latest features and security improvements.',
            style: SoftText.caption(p, size: 12.5).copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isChecking) {
      return SoftPillButton(
        label: 'Check again',
        icon: Icons.refresh_rounded,
        variant: SoftPillVariant.blue,
        loading: true,
        height: 50,
        onPressed: _checkForUpdates,
      );
    }
    if (_errorMessage != null) return _buildRetryButton();
    if (_hasUpdate) return _buildUpdateButton();
    return _buildCheckAgainButton();
  }

  Widget _buildCheckAgainButton() {
    return SoftPillButton(
      label: 'Check again',
      icon: Icons.refresh_rounded,
      variant: SoftPillVariant.blue,
      height: 50,
      onPressed: _checkForUpdates,
    );
  }

  Widget _buildRetryButton() {
    return SoftPillButton(
      label: 'Try again',
      icon: Icons.refresh_rounded,
      variant: SoftPillVariant.danger,
      height: 50,
      onPressed: _checkForUpdates,
    );
  }

  Widget _buildUpdateButton() {
    return SoftPillButton(
      label: 'Download update',
      icon: Icons.download_rounded,
      variant: SoftPillVariant.blue,
      height: 50,
      onPressed: _showUpdateDialog,
    );
  }
}
