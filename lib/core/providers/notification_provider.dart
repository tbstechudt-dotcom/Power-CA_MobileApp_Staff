import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Provider for managing notification preferences
/// Follows the same pattern as ThemeProvider
class NotificationProvider extends ChangeNotifier {
  bool _isInitialized = false;

  // Global toggle
  bool _notificationsEnabled = true;

  // Feature-specific toggles
  bool _leaveNotificationsEnabled = true;
  bool _pinboardNotificationsEnabled = true;

  // Last known leave statuses for detecting changes
  Map<int, String> _lastKnownLeaveStatuses = {};

  // Timestamp for checking new pinboard items
  DateTime? _lastPinboardCheckTimestamp;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;

  /// Leave notifications are enabled only if both global and feature toggles are on
  bool get leaveNotificationsEnabled =>
      _leaveNotificationsEnabled && _notificationsEnabled;

  /// Pinboard notifications are enabled only if both global and feature toggles are on
  bool get pinboardNotificationsEnabled =>
      _pinboardNotificationsEnabled && _notificationsEnabled;

  /// Raw leave toggle value (for settings UI)
  bool get leaveNotificationsToggle => _leaveNotificationsEnabled;

  /// Raw pinboard toggle value (for settings UI)
  bool get pinboardNotificationsToggle => _pinboardNotificationsEnabled;

  Map<int, String> get lastKnownLeaveStatuses => _lastKnownLeaveStatuses;
  DateTime? get lastPinboardCheckTimestamp => _lastPinboardCheckTimestamp;

  /// Initialize from stored preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      _notificationsEnabled =
          prefs.getBool(StorageConstants.keyNotificationsEnabled) ?? true;
      _leaveNotificationsEnabled =
          prefs.getBool(StorageConstants.keyLeaveNotificationsEnabled) ?? true;
      _pinboardNotificationsEnabled =
          prefs.getBool(StorageConstants.keyPinboardNotificationsEnabled) ??
              true;

      // Load last known leave statuses
      final statusesJson =
          prefs.getString(StorageConstants.keyLastKnownLeaveStatuses);
      if (statusesJson != null) {
        try {
          final decoded = jsonDecode(statusesJson) as Map<String, dynamic>;
          _lastKnownLeaveStatuses =
              decoded.map((k, v) => MapEntry(int.parse(k), v as String));
        } catch (e) {
          debugPrint('NotificationProvider: Error parsing leave statuses: $e');
          _lastKnownLeaveStatuses = {};
        }
      }

      // Load pinboard check timestamp
      final pinboardTimestamp =
          prefs.getString(StorageConstants.keyLastPinboardCheckTimestamp);
      if (pinboardTimestamp != null) {
        try {
          _lastPinboardCheckTimestamp = DateTime.parse(pinboardTimestamp);
        } catch (e) {
          debugPrint(
              'NotificationProvider: Error parsing pinboard timestamp: $e');
        }
      }

      _isInitialized = true;
      notifyListeners();
      debugPrint('NotificationProvider: Initialized');
    } catch (e) {
      debugPrint('NotificationProvider: Error loading preferences: $e');
      _isInitialized = true;
    }
  }

  /// Toggle global notifications
  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
    await _savePreference(StorageConstants.keyNotificationsEnabled, value);
  }

  /// Toggle leave notifications
  Future<void> setLeaveNotificationsEnabled(bool value) async {
    if (_leaveNotificationsEnabled == value) return;
    _leaveNotificationsEnabled = value;
    notifyListeners();
    await _savePreference(StorageConstants.keyLeaveNotificationsEnabled, value);
  }

  /// Toggle pinboard notifications
  Future<void> setPinboardNotificationsEnabled(bool value) async {
    if (_pinboardNotificationsEnabled == value) return;
    _pinboardNotificationsEnabled = value;
    notifyListeners();
    await _savePreference(
        StorageConstants.keyPinboardNotificationsEnabled, value);
  }

  /// Update known leave statuses (call after checking for changes)
  Future<void> updateLeaveStatuses(Map<int, String> statuses) async {
    _lastKnownLeaveStatuses = Map.from(statuses);

    try {
      final prefs = await SharedPreferences.getInstance();
      final statusesJson =
          jsonEncode(statuses.map((k, v) => MapEntry(k.toString(), v)));
      await prefs.setString(
          StorageConstants.keyLastKnownLeaveStatuses, statusesJson);
    } catch (e) {
      debugPrint('NotificationProvider: Error saving leave statuses: $e');
    }
  }

  /// Update last pinboard check timestamp
  Future<void> updatePinboardCheckTimestamp() async {
    _lastPinboardCheckTimestamp = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        StorageConstants.keyLastPinboardCheckTimestamp,
        _lastPinboardCheckTimestamp!.toIso8601String(),
      );
    } catch (e) {
      debugPrint('NotificationProvider: Error saving pinboard timestamp: $e');
    }
  }

  /// Save a boolean preference
  Future<void> _savePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('NotificationProvider: Error saving $key: $e');
    }
  }
}
