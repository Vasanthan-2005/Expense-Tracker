import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_version.dart';

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);

  @override
  String toString() => message;
}

class AppUpdateService {
  static const String repoOwner = 'Vasanthan-2005';
  static const String repoName = 'Expense-Tracker';
  static const String defaultAppVersion = '1.0.0';

  static const MethodChannel _channel = MethodChannel('com.example.expense_tracker/app_update');

  /// The GitHub Releases API URL for this repository
  static String get releasesApiUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases';

  /// Retrieves the installed app version.
  /// On Android, queries the active PackageManager package info.
  /// On other platforms or during unit tests, falls back to [defaultAppVersion].
  static Future<AppVersion> getCurrentVersion() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<Map>('getAppVersion');
        if (res != null && res['versionName'] != null) {
          final verStr = res['versionName'].toString();
          final code = res['versionCode'] != null ? int.tryParse(res['versionCode'].toString()) : null;
          return AppVersion(
            major: AppVersion.parse(verStr).major,
            minor: AppVersion.parse(verStr).minor,
            patch: AppVersion.parse(verStr).patch,
            buildNumber: code,
            raw: verStr,
          );
        }
      } catch (e) {
        debugPrint('Could not retrieve native app version: $e');
      }
    }
    return AppVersion.parse(defaultAppVersion);
  }

  /// Queries the GitHub Releases API for the latest stable release.
  /// Ignores draft releases and pre-releases.
  /// Returns [AppReleaseInfo] if a newer stable release with an attached .apk is found;
  /// otherwise returns null.
  static Future<AppReleaseInfo?> checkForUpdate({
    AppVersion? customCurrentVersion,
    HttpClient? customHttpClient,
  }) async {
    final current = customCurrentVersion ?? await getCurrentVersion();

    final client = customHttpClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);

    try {
      final request = await client.getUrl(Uri.parse(releasesApiUrl));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'Expense-Tracker-App');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw UpdateException(
          'GitHub API returned HTTP ${response.statusCode}. Please try again later.',
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final dynamic decoded = jsonDecode(responseBody);

      if (decoded is! List) {
        throw const UpdateException('Invalid response format from GitHub Releases API.');
      }

      final List<AppReleaseInfo> stableReleases = [];

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final isDraft = item['draft'] as bool? ?? false;
          final isPrerelease = item['prerelease'] as bool? ?? false;

          // Ignore draft and pre-releases
          if (isDraft || isPrerelease) continue;

          final release = AppReleaseInfo.fromJson(item);
          // Must have an attached .apk asset
          if (release.hasApk) {
            stableReleases.add(release);
          }
        }
      }

      if (stableReleases.isEmpty) {
        return null;
      }

      // Sort descending by semantic version
      stableReleases.sort((a, b) => b.version.compareTo(a.version));
      final latest = stableReleases.first;

      // Only return if latest is strictly greater than current installed version
      if (latest.version > current) {
        return latest;
      }

      return null;
    } on SocketException {
      throw const UpdateException(
        'Unable to connect to GitHub. Please check your internet connection and try again.',
      );
    } on HandshakeException {
      throw const UpdateException(
        'Secure connection failed. Please check your device network/date settings.',
      );
    } catch (e) {
      if (e is UpdateException) rethrow;
      throw UpdateException('Error checking for updates: $e');
    } finally {
      if (customHttpClient == null) {
        client.close();
      }
    }
  }

  /// Downloads the APK file to the device's temporary cache directory,
  /// reporting download progress between 0.0 and 1.0.
  static Future<File> downloadApk(
    String downloadUrl, {
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
    HttpClient? customHttpClient,
  }) async {
    final client = customHttpClient ?? HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    final tempDir = await getTemporaryDirectory();
    final updatesDir = Directory('${tempDir.path}/updates');
    if (!updatesDir.existsSync()) {
      await updatesDir.create(recursive: true);
    }

    final targetFile = File('${updatesDir.path}/app-update.apk');
    if (targetFile.existsSync()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.headers.set('User-Agent', 'Expense-Tracker-App');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw UpdateException(
          'Download server returned HTTP ${response.statusCode}. Download failed.',
        );
      }

      final contentLength = response.contentLength;
      int receivedBytes = 0;

      sink = targetFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = contentLength > 0 ? (receivedBytes / contentLength).clamp(0.0, 1.0) : 0.0;
        onProgress(progress, receivedBytes, contentLength);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (!targetFile.existsSync() || targetFile.lengthSync() == 0) {
        throw const UpdateException('Downloaded APK file is empty or corrupted.');
      }

      return targetFile;
    } on SocketException {
      throw const UpdateException(
        'Network error during APK download. Please verify your internet connection and try again.',
      );
    } catch (e) {
      if (targetFile.existsSync()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      if (e is UpdateException) rethrow;
      throw UpdateException('Unable to download the update: $e');
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (customHttpClient == null) {
        client.close();
      }
    }
  }

  /// Checks whether the app has permission to request package installations (Android 8.0+).
  static Future<bool> canRequestPackageInstalls() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
        return res ?? true;
      } catch (e) {
        debugPrint('Error checking package install permission: $e');
        return true;
      }
    }
    return true;
  }

  /// Opens the Android system settings screen allowing the user to grant
  /// "Install unknown apps" permission for this application.
  static Future<void> openInstallPermissionSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openInstallPermissionSettings');
      } catch (e) {
        debugPrint('Error opening install permission settings: $e');
      }
    }
  }

  /// Invokes the native Android Package Installer to install the APK at [filePath].
  /// Uses Android FileProvider with content:// URI and FLAG_GRANT_READ_URI_PERMISSION.
  static Future<bool> installApk(String filePath) async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
        return res ?? false;
      } on PlatformException catch (e) {
        throw UpdateException(e.message ?? 'Installation failed: ${e.code}');
      } catch (e) {
        throw UpdateException('Failed to launch package installer: $e');
      }
    } else {
      throw const UpdateException('APK installation is only supported on Android devices.');
    }
  }

  /// Deletes any obsolete downloaded APK files from the cache directory.
  static Future<void> cleanUpDownloadedApks() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final updatesDir = Directory('${tempDir.path}/updates');
      if (updatesDir.existsSync()) {
        final files = updatesDir.listSync();
        for (final f in files) {
          if (f is File && f.path.endsWith('.apk')) {
            try {
              await f.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
