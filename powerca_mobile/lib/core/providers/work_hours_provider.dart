import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Work Hours input mode options
enum WorkHoursMode {
  fromToTime,   // From/To Time picker mode (default)
  hoursMinutes, // Hours/Minutes direct input mode
}

/// Provider for managing Work Hours preferences
/// Allows staff to set their preferred default input mode
class WorkHoursProvider extends ChangeNotifier {
  bool _isInitialized = false;

  // Default mode preference
  WorkHoursMode _defaultMode = WorkHoursMode.fromToTime;

  // Getters
  bool get isInitialized => _isInitialized;
  WorkHoursMode get defaultMode => _defaultMode;

  /// Check if the default mode is From/To Time
  bool get isFromToTimeDefault => _defaultMode == WorkHoursMode.fromToTime;

  /// Check if the default mode is Hours/Minutes
  bool get isHoursMinutesDefault => _defaultMode == WorkHoursMode.hoursMinutes;

  /// Initialize from stored preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final modeString = prefs.getString(StorageConstants.keyDefaultWorkHoursMode);
      if (modeString != null) {
        _defaultMode = modeString == 'hoursMinutes'
            ? WorkHoursMode.hoursMinutes
            : WorkHoursMode.fromToTime;
      }

      _isInitialized = true;
      notifyListeners();
      debugPrint('WorkHoursProvider: Initialized with mode: $_defaultMode');
    } catch (e) {
      debugPrint('WorkHoursProvider: Error loading preferences: $e');
      _isInitialized = true;
    }
  }

  /// Set the default Work Hours mode
  Future<void> setDefaultMode(WorkHoursMode mode) async {
    if (_defaultMode == mode) return;
    _defaultMode = mode;
    notifyListeners();
    await _savePreference(mode);
  }

  /// Toggle between the two modes
  Future<void> toggleMode() async {
    final newMode = _defaultMode == WorkHoursMode.fromToTime
        ? WorkHoursMode.hoursMinutes
        : WorkHoursMode.fromToTime;
    await setDefaultMode(newMode);
  }

  /// Save the mode preference
  Future<void> _savePreference(WorkHoursMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = mode == WorkHoursMode.hoursMinutes
          ? 'hoursMinutes'
          : 'fromToTime';
      await prefs.setString(StorageConstants.keyDefaultWorkHoursMode, modeString);
      debugPrint('WorkHoursProvider: Saved mode: $modeString');
    } catch (e) {
      debugPrint('WorkHoursProvider: Error saving preference: $e');
    }
  }
}
