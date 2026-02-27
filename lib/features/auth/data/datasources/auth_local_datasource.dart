import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff_model.dart';

/// Authentication Local Data Source
///
/// Handles local storage of authentication data using SharedPreferences
abstract class AuthLocalDataSource {
  /// Get cached staff data
  Future<StaffModel?> getCachedStaff();

  /// Cache staff data
  Future<void> cacheStaff(StaffModel staff);

  /// Clear cached staff data
  Future<void> clearCachedStaff();

  /// Check if staff is cached
  Future<bool> isStaffCached();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  static const String _cachedStaffKey = 'CACHED_STAFF';

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<StaffModel?> getCachedStaff() async {
    try {
      final jsonString = sharedPreferences.getString(_cachedStaffKey);
      if (jsonString == null) {
        return null;
      }

      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return StaffModel.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> cacheStaff(StaffModel staff) async {
    final jsonMap = staff.toJson();
    final jsonString = json.encode(jsonMap);
    await sharedPreferences.setString(_cachedStaffKey, jsonString);
  }

  @override
  Future<void> clearCachedStaff() async {
    await sharedPreferences.remove(_cachedStaffKey);
  }

  @override
  Future<bool> isStaffCached() async {
    return sharedPreferences.containsKey(_cachedStaffKey);
  }
}
