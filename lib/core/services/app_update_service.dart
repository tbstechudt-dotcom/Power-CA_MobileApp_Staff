import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model for app version info
class AppVersionInfo {
  final int id;
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String? releaseNotes;
  final bool isForceUpdate;
  final DateTime createdAt;

  AppVersionInfo({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    this.releaseNotes,
    required this.isForceUpdate,
    required this.createdAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      id: json['id'] as int,
      versionName: json['version_name'] as String,
      versionCode: json['version_code'] as int,
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
      isForceUpdate: json['is_force_update'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Service to check and download app updates
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final _supabase = Supabase.instance.client;
  final _dio = Dio();

  // Current app version - UPDATE THIS when releasing new versions
  static const String currentVersionName = '1.0.9';
  static const int currentVersionCode = 9;

  /// Check if a new version is available
  Future<AppVersionInfo?> checkForUpdate() async {
    try {
      debugPrint('=== APP UPDATE CHECK ===');
      debugPrint('Current version: $currentVersionName (code: $currentVersionCode)');

      final response = await _supabase
          .from('app_versions')
          .select()
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('Supabase response: $response');

      if (response == null) {
        debugPrint('No version found in app_versions table');
        return null;
      }

      final latestVersion = AppVersionInfo.fromJson(response);
      debugPrint('Latest version: ${latestVersion.versionName} (code: ${latestVersion.versionCode})');

      // Compare version codes
      if (latestVersion.versionCode > currentVersionCode) {
        debugPrint('UPDATE AVAILABLE! Showing dialog...');
        return latestVersion;
      }

      debugPrint('App is up to date');
      return null;
    } catch (e, stack) {
      debugPrint('Error checking for update: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  /// Download APK file with progress callback
  Future<String?> downloadApk(
    String downloadUrl,
    Function(int received, int total) onProgress,
  ) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          // Try request install packages permission for Android 8+
          await Permission.requestInstallPackages.request();
        }
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        debugPrint('Could not get storage directory');
        return null;
      }

      final filePath = '${directory.path}/powerca_update.apk';

      // Download file
      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: onProgress,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return filePath;
    } catch (e) {
      debugPrint('Error downloading APK: $e');
      return null;
    }
  }

  /// Install the downloaded APK
  Future<bool> installApk(String filePath) async {
    try {
      debugPrint('Opening APK for installation: $filePath');

      // Use specific MIME type for APK files
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('OpenFilex result: ${result.type} - ${result.message}');

      // ResultType.done means the file was opened successfully
      // The actual installation is handled by Android's package installer
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('Error installing APK: $e');
      return false;
    }
  }

  /// Get formatted file size
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
