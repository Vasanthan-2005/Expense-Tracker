import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_version.dart';
import '../../services/app_update_service.dart';

enum UpdateScreenStatus {
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  error,
}

class UpdateAppScreen extends StatefulWidget {
  const UpdateAppScreen({super.key});

  @override
  State<UpdateAppScreen> createState() => _UpdateAppScreenState();
}

class _UpdateAppScreenState extends State<UpdateAppScreen> {
  UpdateScreenStatus _status = UpdateScreenStatus.checking;
  AppVersion? _currentVersion;
  AppReleaseInfo? _latestRelease;
  String _errorMessage = '';

  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  File? _downloadedApkFile;
  bool _canInstallPackages = true;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _status = UpdateScreenStatus.checking;
      _errorMessage = '';
      _downloadProgress = 0.0;
      _downloadedApkFile = null;
    });

    try {
      final currentVer = await AppUpdateService.getCurrentVersion();
      final release = await AppUpdateService.checkForUpdate(customCurrentVersion: currentVer);
      final canInstall = await AppUpdateService.canRequestPackageInstalls();

      if (!mounted) return;

      setState(() {
        _currentVersion = currentVer;
        _canInstallPackages = canInstall;
        if (release != null) {
          _latestRelease = release;
          _status = UpdateScreenStatus.updateAvailable;
        } else {
          _status = UpdateScreenStatus.upToDate;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is UpdateException ? e.message : e.toString();
        _status = UpdateScreenStatus.error;
      });
    }
  }

  Future<void> _startDownload() async {
    final asset = _latestRelease?.apkAsset;
    if (asset == null || asset.downloadUrl.isEmpty) {
      setState(() {
        _errorMessage = 'No valid APK download found for this release.';
        _status = UpdateScreenStatus.error;
      });
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _status = UpdateScreenStatus.downloading;
      _downloadProgress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = asset.sizeBytes;
    });

    try {
      final apk = await AppUpdateService.downloadApk(
        asset.downloadUrl,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _downloadedBytes = received;
              if (total > 0) _totalBytes = total;
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _downloadedApkFile = apk;
        _status = UpdateScreenStatus.readyToInstall;
      });

      // Prompt installation automatically once downloaded
      await _triggerInstall();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is UpdateException ? e.message : e.toString();
        _status = UpdateScreenStatus.error;
      });
    }
  }

  Future<void> _triggerInstall() async {
    if (_downloadedApkFile == null || !_downloadedApkFile!.existsSync()) {
      setState(() {
        _errorMessage = 'Downloaded update file was not found.';
        _status = UpdateScreenStatus.error;
      });
      return;
    }

    final canInstall = await AppUpdateService.canRequestPackageInstalls();
    if (!canInstall) {
      setState(() {
        _canInstallPackages = false;
      });
      _showPermissionDialog();
      return;
    }

    try {
      HapticFeedback.mediumImpact();
      await AppUpdateService.installApk(_downloadedApkFile!.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is UpdateException ? e.message : e.toString();
        _status = UpdateScreenStatus.error;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Permission Needed'),
          ],
        ),
        content: const Text(
          'Android requires your permission to install applications from this source. '
          'Please toggle "Allow from this source" in Android Settings, then return to complete installation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AppUpdateService.openInstallPermissionSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update App'),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkForUpdates,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // App Logo / Update Graphic
                    _buildHeaderGraphic(theme),
                    const SizedBox(height: 24),

                    // Main Content Card based on status
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: _buildStateContent(theme),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderGraphic(ThemeData theme) {
    final Color badgeColor;
    final IconData badgeIcon;

    switch (_status) {
      case UpdateScreenStatus.checking:
      case UpdateScreenStatus.downloading:
        badgeColor = theme.colorScheme.primary;
        badgeIcon = Icons.cloud_sync_rounded;
        break;
      case UpdateScreenStatus.upToDate:
        badgeColor = const Color(0xFF10B981);
        badgeIcon = Icons.check_circle_rounded;
        break;
      case UpdateScreenStatus.updateAvailable:
      case UpdateScreenStatus.readyToInstall:
        badgeColor = const Color(0xFF6366F1);
        badgeIcon = Icons.system_update_rounded;
        break;
      case UpdateScreenStatus.error:
        badgeColor = theme.colorScheme.error;
        badgeIcon = Icons.cloud_off_rounded;
        break;
    }

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(
        child: Icon(badgeIcon, size: 44, color: badgeColor),
      ),
    );
  }

  Widget _buildStateContent(ThemeData theme) {
    switch (_status) {
      case UpdateScreenStatus.checking:
        return _buildCheckingView(theme);
      case UpdateScreenStatus.upToDate:
        return _buildUpToDateView(theme);
      case UpdateScreenStatus.updateAvailable:
        return _buildUpdateAvailableView(theme);
      case UpdateScreenStatus.downloading:
        return _buildDownloadingView(theme);
      case UpdateScreenStatus.readyToInstall:
        return _buildReadyToInstallView(theme);
      case UpdateScreenStatus.error:
        return _buildErrorView(theme);
    }
  }

  Widget _buildCheckingView(ThemeData theme) {
    return Container(
      key: const ValueKey('checking'),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Checking for updates...',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Connecting to GitHub Releases API',
            style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
          ),
          if (_currentVersion != null) ...[
            const SizedBox(height: 14),
            _buildVersionChip('Current: ${_currentVersion!.semVerOnly}', theme),
          ],
        ],
      ),
    );
  }

  Widget _buildUpToDateView(ThemeData theme) {
    final currentStr = _currentVersion?.semVerOnly ?? '1.0.0';

    return Container(
      key: const ValueKey('upToDate'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text(
            'You\'re using the latest version.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Version $currentStr',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Expense Tracker is up to date with the latest features, security patches, and optimizations.',
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _checkForUpdates,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check Again', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateAvailableView(ThemeData theme) {
    final currentStr = _currentVersion?.semVerOnly ?? '1.0.0';
    final latestStr = _latestRelease?.version.semVerOnly ?? 'Latest';
    final asset = _latestRelease?.apkAsset;

    return Container(
      key: const ValueKey('updateAvailable'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text(
                  'New version available!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildVersionChip('Current: $currentStr', theme),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                    ),
                    _buildVersionChip('Latest: $latestStr', theme, isNew: true),
                  ],
                ),
                if (asset != null && asset.formattedSize.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Download size: ${asset.formattedSize}',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Release Notes Section
          if (_latestRelease?.releaseNotes.isNotEmpty == true) ...[
            Text(
              'What\'s New',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                _latestRelease!.releaseNotes,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Update Now Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _startDownload,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('Update Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingView(ThemeData theme) {
    final pct = (_downloadProgress * 100).toInt();

    return Container(
      key: const ValueKey('downloading'),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Downloading update...',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              minHeight: 8,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatBytes(_downloadedBytes)} / ${_formatBytes(_totalBytes)}',
                style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
              ),
              const Text(
                'Please keep the app open',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadyToInstallView(ThemeData theme) {
    return Container(
      key: const ValueKey('readyToInstall'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Download Complete!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'The APK has been verified. Tap below to launch the Android package installer.',
            style: TextStyle(fontSize: 12.5, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          if (!_canInstallPackages) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unknown apps permission is needed to install.',
                      style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodyMedium?.color),
                    ),
                  ),
                  TextButton(
                    onPressed: AppUpdateService.openInstallPermissionSettings,
                    child: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _triggerInstall,
              icon: const Icon(Icons.install_mobile_rounded, size: 20),
              label: const Text('Install Update', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Container(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Unable to complete update check',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage.isNotEmpty
                ? _errorMessage
                : 'Unable to check for updates. Please check your internet connection and try again.',
            style: TextStyle(fontSize: 12.5, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8), height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _checkForUpdates,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionChip(String label, ThemeData theme, {bool isNew = false}) {
    final color = isNew ? const Color(0xFF10B981) : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
